import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskDocumentTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(data: output.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/documents"), to: workspace)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let task = service.createTask(workspace: workspace)
        await service.send(taskID: task, text: "read-fixture:report.pdf", configuration: config)
        let result = service.tasks[0]
        try check(result.status == .completed && result.sources.count == 1, "a real PDF extraction must produce a verified source: \(result.tools.map(\.output))")
        let source = result.sources[0]
        try check(source.excerpt.contains("银杏") && source.excerpt.contains("73") && source.excerpt.contains("P2-418"), "both pages must be extracted from the actual PDF")
        try check(source.excerpt.contains("第 1 页") && source.excerpt.contains("第 2 页"), "PDF text must retain its actual page locations")
        let wordTask = service.createTask(workspace: workspace)
        await service.send(taskID: wordTask, text: "read-fixture:report.docx", configuration: config)
        let word = service.tasks[0]
        try check(word.status == .completed && word.sources.count == 1, "DOCX must be parsed into a verified source: \(word.tools.map(\.output))")
        let wordSource = word.sources[0]
        try check(wordSource.excerpt.contains("预算：80 元") && wordSource.excerpt.contains("第 4 段\n表格：DOCX-731"), "Word must join runs and preserve blank/body/table paragraph positions")
        try check(wordSource.documentLocation?.unit == .paragraph && wordSource.documentLocation?.total == 4, "Word uses paragraphs, not fabricated page numbers")
        for (file, expected) in [("imported.docx", "嵌入正文"), ("wrong-root.docx", "损坏"), ("legacy.doc", "不支持"), ("broken.pdf", "损坏"), ("encrypted.pdf", "加密"), ("blank.pdf", "没有可提取文字"), ("scanned.pdf", "未进行 OCR"), ("empty.docx", "没有可提取文字"), ("broken.docx", "损坏")] {
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "read-fixture:" + file, configuration: config)
            let failed = service.tasks[0]
            try check(failed.sources.isEmpty && failed.tools.count == 1 && failed.tools[0].status == "失败" && failed.tools[0].output.contains(expected), "\(file) must report \(expected) without claiming a source: \(failed.tools.map(\.output))")
        }

        for file in ["blank-prefix.pdf", "blank-prefix.docx"] {
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "read-fixture:" + file, configuration: config)
            try check(service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains("offset=11") && service.tasks[0].tools[0].output.contains("共 11"), "a blank first range must retain total and continuation: \(service.tasks[0].tools.map(\.output))")
            let arguments = String(data: try JSONSerialization.data(withJSONObject: ["file_path": file, "offset": 11] as [String: Any]), encoding: .utf8)!
            await service.send(taskID: id, text: "read-options-fixture:" + arguments, configuration: config)
            try check(service.tasks[0].sources.last?.documentLocation?.first == 11 && service.tasks[0].sources.last?.excerpt.contains("LATE-731") == true, "blank early pages/paragraphs must not hide later real text")
        }

        let partialID = service.createTask(workspace: workspace)
        await service.send(taskID: partialID, text: #"read-options-fixture:{"file_path":"report.pdf","limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.first?.documentLocation?.last == 1 && service.tasks[0].sources[0].excerpt.contains("offset=2"), "partial PDF reads must expose the actual range and continuation")
        await service.send(taskID: partialID, text: #"read-options-fixture:{"file_path":"report.pdf","offset":2,"limit":1}"#, configuration: config)
        let continued = service.tasks[0].sources.last!
        try check(continued.documentLocation?.first == 2 && continued.excerpt.contains("P2-418") && !continued.excerpt.contains("银杏"), "continuation must read only the requested actual page")
        let paragraphID = service.createTask(workspace: workspace)
        await service.send(taskID: paragraphID, text: #"read-options-fixture:{"file_path":"report.docx","offset":4,"limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.first?.documentLocation?.first == 4 && service.tasks[0].sources[0].excerpt.contains("DOCX-731"), "Word continuation preserves paragraph numbers including earlier blank paragraphs")
        let rangeID = service.createTask(workspace: workspace)
        await service.send(taskID: rangeID, text: #"read-options-fixture:{"file_path":"report.pdf","offset":3}"#, configuration: config)
        try check(service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains("超过 PDF 总页数"), "out-of-range page must not produce a fabricated source")

        let outside = directory.appendingPathComponent("private.pdf")
        try FileManager.default.copyItem(at: workspace.appendingPathComponent("report.pdf"), to: outside)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("link.pdf"), withDestinationURL: outside)
        let restricted = service.createTask(workspace: workspace)
        let pending = Task { await service.send(taskID: restricted, text: "read-fixture:link.pdf", configuration: config) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks[0].permissions.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        guard let permission = service.tasks[0].permissions.first else { throw NSError(domain: "TaskDocumentTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Outside PDF must request permission before extraction"]) }
        service.answerPermission(taskID: restricted, requestID: permission.id, allow: false)
        await pending.value
        try check(service.tasks[0].sources.isEmpty && !service.tasks[0].tools[0].output.contains("银杏"), "refusing external PDF must prevent text extraction")
        service.shutdown()
        let reopened = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        let savedPDF = reopened.tasks.first { $0.id == partialID }?.sources.last
        let savedWord = reopened.tasks.first { $0.id == wordTask }?.sources.first
        try check(savedPDF?.documentLocation?.first == 2 && savedPDF?.documentLocation?.unit == .page && savedWord?.documentLocation?.total == 4 && savedWord?.documentLocation?.unit == .paragraph, "history must preserve real document locators and source excerpts")
        print("PASS: documents through TaskService → ACP → real extraction and sources")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskDocumentTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
