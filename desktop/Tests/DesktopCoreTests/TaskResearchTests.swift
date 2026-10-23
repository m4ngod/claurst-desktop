import Foundation
import PDFKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskResearchTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/research_server.py").path]
        let output = Pipe(); fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("paper/sections"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputs = ["documents/report.pdf", "documents/report.docx", "tables/sales.xlsx",
                      "tables/sales.csv", "scans/scanned.pdf", "scans/printed.png"]
        for path in inputs {
            try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/" + path),
                to: workspace.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent))
        }
        try "# 合成研究\n项目：银杏\n实际总体和样本量未知，不得推断。\n".write(
            to: workspace.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        let executable: URL
        if CommandLine.arguments.count == 1 {
            executable = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        } else {
            guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--runtime",
                  CommandLine.arguments[2].hasPrefix("/") else {
                throw failure("Usage: task-research-test [--runtime /absolute/path/to/claurst-desktop-runtime]")
            }
            executable = URL(fileURLWithPath: CommandLine.arguments[2])
        }
        let settings = directory.appendingPathComponent("settings")
        let service = TaskService(executable: executable, storageDirectory: settings)
        defer { service.shutdown() }
        let configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model",
            apiKey: "test-only", isTest: true, imageInputEnabled: true, webSearchEnabled: true)
        let id = service.createTask(workspace: workspace)
        let running = Task { await service.send(taskID: id, text: "根据混合素材完成研究报告，并交付完整 LaTeX 和真实 PDF；资料不足时先问关键问题。", configuration: configuration) }
        // This chain runs two real OCR operations, each with a 90-second tool
        // timeout, plus document/table reads. Do not cancel a valid operation
        // just because their cumulative duration exceeds one minute.
        let deadline = Date().addingTimeInterval(300)
        var loopbackApprovals = 0
        while service.tasks.first?.questions.first?.isPending != true && Date() < deadline {
            if service.tasks.first?.tools.isEmpty == false && service.tasks.first?.status.isActive == false { break }
            for permission in service.tasks.first?.permissions ?? [] {
                try check(permission.description.contains("http://127.0.0.1:\(port)/method"),
                    "Only the synthetic loopback webpage may require extra access")
                loopbackApprovals += 1
                service.answerPermission(taskID: id, requestID: permission.id, allow: true)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard let question = service.tasks.first?.questions.first, question.isPending else {
            throw failure("The mixed-material task must reach its actual missing-information question: \(service.tasks.first?.messages.last?.text ?? "") / \(service.tasks.first?.tools.suffix(2).map(\.output) ?? [])")
        }
        try check(loopbackApprovals == 1, "The fixture's private-network page needs exactly one specific approval")
        try check(service.tasks[0].permissions.isEmpty && service.tasks[0].latexArtifacts.isEmpty,
            "Authorized materials are read without repeated approvals and no PDF is invented before writing")
        service.answerQuestion(taskID: id, requestID: question.id, text: "研究人员")
        await running.value
        let task = service.tasks.first { $0.id == id }!
        try check(task.status == .completed && task.latexArtifacts.count == 1,
            "One continuous task must produce a real PDF after the answer: \(task.messages.last?.text ?? "") / \(task.tools.map(\.output))")
        try check(task.questions.count == 1 && task.questions[0].answer == "研究人员" && task.permissions.isEmpty,
            "The task continues after the critical answer without asking for an outline or each file")
        for name in ["notes.md", "report.pdf", "report.docx", "sales.xlsx", "sales.csv", "scanned.pdf", "printed.png"] {
            try check(task.sources.contains { $0.file.lastPathComponent == name }, "\(name) must have a real located source")
        }
        let table = task.sources.filter { $0.file.lastPathComponent == "sales.xlsx" }.map(\.excerpt).joined(separator: "\n")
        try check(table.contains("合计=13") && table.contains("合计=7") && table.contains("缺失数=1")
            && table.contains("B2:B5") && table.contains("十进制"),
            "The report must retain real table calculation, range and missing-cell evidence")
        try check(task.sources.contains { $0.file.lastPathComponent == "scanned.pdf" && $0.documentLocation?.recognition == true && $0.documentLocation?.last == 2 },
            "The scan source must preserve its actual pages and recognition method")
        guard let webpage = task.webSources.first else { throw failure("A search candidate must be fetched into a real webpage source") }
        try check(task.webSources.count == 1 && webpage.title == "合成研究方法"
            && webpage.excerpt.contains("缺失金额不得当作零填充") && webpage.firstLine > 0,
            "The actual fetched webpage and line locations must remain accessible")
        let artifact = task.latexArtifacts[0]
        let pdfData = try artifact.checkedPDFData(in: workspace)
        guard let pdf = PDFDocument(data: pdfData) else { throw failure("The delivered PDF must open") }
        let pdfText = pdf.string ?? ""
        for text in ["银杏", "73", "80", "13", "7", "SECOND-418", "SCAN-731", "总体", "缺失", "版本关系未确认", webpage.id] {
            try check(pdfText.contains(text), "The actual PDF must contain \(text)")
        }
        try check(!artifact.reviewNotes.contains { $0.contains("undefined") },
            "The actual bibliography must resolve")
        let evidence = try String(contentsOf: workspace.appendingPathComponent("paper/sources.md"), encoding: .utf8)
        try check(evidence.contains(webpage.id) && evidence.contains(webpage.url.absoluteString)
            && evidence.contains("B2:B5") && evidence.contains("研究人员"),
            "Editable source materials must retain actual source identifiers, calculation ranges and the user's answer")
        try check(task.sources.contains { $0.file.path == artifact.pdfPath && $0.documentLocation?.visual == true },
            "The actual compiled PDF page must pass through ReadImage")
        try check(task.messages.last?.text.contains("页面布局未核对") == true,
            "A fixture without visual judgment must explicitly leave layout unverified")
        for path in inputs {
            let original = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/" + path))
            try check(original == Data(contentsOf: workspace.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)),
                "Research must preserve input \(path)")
        }
        service.shutdown()
        let reopened = TaskService(executable: executable, storageDirectory: settings)
        defer { reopened.shutdown() }
        let restored = reopened.tasks.first { $0.id == id }!
        try check(restored.sources.count == task.sources.count && restored.webSources.first?.id == webpage.id
            && restored.latexArtifacts.count == 1 && restored.questions.first?.answer == "研究人员",
            "Local sources, website, PDF and clarification survive together across app history")
        print("PASS: mixed research through TaskService → actual extraction/OCR/calculation/web parsing/LaTeX/PDF pixels and history")
    }

    static func failure(_ text: String) -> NSError {
        NSError(domain: "TaskResearchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
    static func check(_ condition: Bool, _ text: String) throws {
        if !condition { throw failure(text) }
    }
}
