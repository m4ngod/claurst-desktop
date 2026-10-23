import Foundation
import PDFKit
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskLatexTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/latex_server.py").path]
        let output = Pipe(); fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("sections"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let main = #"""
        \documentclass[UTF8,fontset=claurst]{ctexart}
        \usepackage[a4paper,margin=25mm]{geometry}
        \begin{document}
        \section{中文编译验收}
        \input{sections/intro.tex}
        \end{document}
        """#
        try main.write(to: workspace.appendingPathComponent("main.tex"), atomically: true, encoding: .utf8)
        try "合成测试：项目代号为银杏，预算为 80 元。".write(to: workspace.appendingPathComponent("sections/intro.tex"), atomically: true, encoding: .utf8)
        let executable = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let service = TaskService(executable: executable, storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let id = service.createTask(workspace: workspace)
        await service.send(taskID: id, text: #"latex-fixture:{"file_path":"main.tex"}"#, configuration: configuration)
        let task = service.tasks.first { $0.id == id }!
        try check(task.status == .completed && task.tools.count == 1 && task.tools[0].status == "完成",
            "Chinese project must compile through the actual tool: \(task.tools.map(\.output))")
        let data = Data((task.messages.last?.text ?? "").utf8)
        let receipt = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let artifact = receipt?["latex_artifact"] as? [String: Any],
              let pdfPath = artifact["pdf_path"] as? String,
              let pdf = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
            throw failure("Compilation must return a real PDF artifact that PDFKit can open")
        }
        try check(pdf.pageCount == 1 && pdf.string?.contains("银杏") == true && pdf.string?.contains("80") == true,
            "The actual PDF must contain the Chinese input and known amount")
        try check(artifact["page_count"] as? Int == pdf.pageCount,
            "The compilation receipt must confirm that the PDF parser opened the actual page count")
        try check(task.latexArtifacts.count == 1 && task.latexArtifacts[0].pdfFile.path == pdfPath,
            "A successful compilation must appear as a durable desktop artifact")
        try check(try String(contentsOf: workspace.appendingPathComponent("main.tex"), encoding: .utf8) == main,
            "Compiling must preserve the editable source project")
        let firstArtifact = task.latexArtifacts[0]
        let firstBytes = try firstArtifact.checkedPDFData(in: workspace)
        try "合成测试：项目代号为银杏，预算为 81 元。".write(to: workspace.appendingPathComponent("sections/intro.tex"), atomically: true, encoding: .utf8)
        await service.send(taskID: id, text: #"latex-fixture:{"file_path":"main.tex"}"#, configuration: configuration)
        let recompiled = service.tasks.first { $0.id == id }!
        try check(recompiled.status == .completed && recompiled.latexArtifacts.count == 2,
            "The same source project can be compiled again into a distinct artifact")
        let secondArtifact = recompiled.latexArtifacts[1]
        try check(secondArtifact.pdfPath != firstArtifact.pdfPath
            && PDFDocument(data: try secondArtifact.checkedPDFData(in: workspace))?.string?.contains("81") == true
            && (try firstArtifact.checkedPDFData(in: workspace)) == firstBytes,
            "Recompiling reflects edited support files and preserves the previous PDF")
        service.shutdown()
        let reopened = TaskService(executable: executable, storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        try check(reopened.tasks.first { $0.id == id }?.latexArtifacts.count == 2,
            "PDF, source and log artifact references survive history recovery")
        let warningMain = main.replacingOccurrences(of: #"\end{document}"#,
            with: #"\ref{missing-reference}\cite{missing-citation}\par\hbox to 1pt{This is an intentionally overflowing test box}\end{document}"#)
        try warningMain.write(to: workspace.appendingPathComponent("warnings.tex"), atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"warnings.tex"}"#, configuration: configuration)
        let warningTask = reopened.tasks.first { $0.id == id }!
        try check(warningTask.status == .completed && warningTask.latexArtifacts.count == 3,
            "A PDF with warnings is retained for review")
        let warnings = warningTask.latexArtifacts[2].reviewNotes.joined(separator: "\n")
        try check(warnings.contains("undefined") && warnings.contains("Overfull"),
            "Unresolved references and layout overflow must be visible in the artifact, not hidden by compile success")
        let broken = main.replacingOccurrences(of: #"\end{document}"#, with: #"\undefinedFixtureCommand\end{document}"#)
        try broken.write(to: workspace.appendingPathComponent("broken.tex"), atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"broken.tex"}"#, configuration: configuration)
        let failed = reopened.tasks.first { $0.id == id }!
        try check(failed.status == .failed && failed.tools.last?.status == "失败" && failed.latexArtifacts.count == 3,
            "A compiler error must not create a successful artifact or remove earlier ones")
        try check(failed.tools.last?.output.contains("undefinedFixtureCommand") == true
            && (try firstArtifact.checkedPDFData(in: workspace)) == firstBytes,
            "Compiler diagnostics remain visible and earlier PDF bytes are unchanged")

        let outside = directory.appendingPathComponent("outside.tex")
        try "OUTSIDE-FIXTURE-731".write(to: outside, atomically: true, encoding: .utf8)
        let outsideRead = main.replacingOccurrences(of: #"\input{sections/intro.tex}"#,
            with: "\\input{" + outside.path + "}")
        try outsideRead.write(to: workspace.appendingPathComponent("outside-read.tex"), atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"outside-read.tex"}"#, configuration: configuration)
        let isolated = reopened.tasks.first { $0.id == id }!
        try check(isolated.status == .failed && isolated.latexArtifacts.count == 3
            && isolated.tools.last?.output.contains("OUTSIDE-FIXTURE-731") != true,
            "The compiler cannot read material outside the selected workspace")

        let shellMarker = workspace.appendingPathComponent("shell-must-not-run.txt")
        let shellInput = main.replacingOccurrences(of: #"\end{document}"#,
            with: "\\immediate\\write18{/usr/bin/touch " + shellMarker.path + "}\\end{document}")
        try shellInput.write(to: workspace.appendingPathComponent("shell.tex"), atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"shell.tex"}"#, configuration: configuration)
        try check(!FileManager.default.fileExists(atPath: shellMarker.path), "LaTeX cannot execute a shell command")

        let busy = main.replacingOccurrences(of: #"\end{document}"#,
            with: #"\newcount\fixturecounter\loop\ifnum\fixturecounter<50000000\advance\fixturecounter by1\repeat\end{document}"#)
        try busy.write(to: workspace.appendingPathComponent("busy.tex"), atomically: true, encoding: .utf8)
        let beforeCancel = reopened.tasks.first { $0.id == id }!.latexArtifacts.count
        let running = Task { await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"busy.tex"}"#, configuration: configuration) }
        let deadline = Date().addingTimeInterval(10)
        var compilerPIDs: [Int32] = []
        while compilerPIDs.isEmpty && Date() < deadline {
            compilerPIDs = try processes(matching: workspace.resolvingSymlinksInPath().path + "/busy.tex")
            if compilerPIDs.isEmpty { try await Task.sleep(nanoseconds: 20_000_000) }
        }
        try check(!compilerPIDs.isEmpty, "A real compiler process must start before testing cancellation")
        let stoppedAt = Date()
        reopened.stop(taskID: id)
        await running.value
        let stopped = reopened.tasks.first { $0.id == id }!
        try check(stopped.status == .stopped && stopped.latexArtifacts.count == beforeCancel
            && Date().timeIntervalSince(stoppedAt) < 5,
            "Stopping a running compiler ends promptly without publishing a late PDF")
        try check(try processes(matching: workspace.resolvingSymlinksInPath().path + "/busy.tex").isEmpty,
            "Stopping reaps the actual compiler process")

        let report = workspace.appendingPathComponent("report")
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/latex-support"), to: report)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"report/main.tex"}"#, configuration: configuration)
        let complete = reopened.tasks.first { $0.id == id }!
        try check(complete.status == .completed && complete.latexArtifacts.count == beforeCancel + 1,
            "The complete project with an image, bibliography, tables and equations must compile offline")
        let completeArtifact = complete.latexArtifacts.last!
        let completeText = PDFDocument(data: try completeArtifact.checkedPDFData(in: workspace))?.string ?? ""
        try check(completeText.contains("银杏") && completeText.contains("80") && completeText.contains("Synthetic")
            && !completeArtifact.reviewNotes.contains(where: { $0.contains("undefined") }),
            "The complete PDF includes the known text and resolved bibliography")

        let abstractMain = main.replacingOccurrences(of: #"\begin{document}"#,
            with: #"\begin{document}\begin{abstract}中文摘要：Abstract budget 73 + 7 = 80.\end{abstract}"#)
        try abstractMain.write(to: workspace.appendingPathComponent("abstract.tex"), atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: #"latex-fixture:{"file_path":"abstract.tex"}"#, configuration: configuration)
        let abstractTask = reopened.tasks.first { $0.id == id }!
        try check(abstractTask.status == .completed && abstractTask.latexArtifacts.count == complete.latexArtifacts.count + 1,
            "A standard Chinese abstract must compile offline and deliver a PDF: \(abstractTask.tools.last?.output ?? "")")

        for size in [11, 10, 12] {
            let count = reopened.tasks.first { $0.id == id }!.latexArtifacts.count
            await reopened.send(taskID: id,
                text: "latex-fixture:{\"file_path\":\"report/fonts\(size).tex\"}", configuration: configuration)
            let fonts = reopened.tasks.first { $0.id == id }!
            try check(fonts.status == .completed && fonts.latexArtifacts.count == count + 1,
                "Standard \(size)pt text sizes and font styles must compile offline: \(fonts.tools.last?.output ?? "")")
            let fontText = PDFDocument(data: try fonts.latexArtifacts.last!.checkedPDFData(in: workspace))?.string ?? ""
            try check(["FONT-MATRIX-\(size)", "银杏", "Italic", "Mono"].allSatisfy(fontText.contains),
                "The font matrix must produce a readable PDF with its actual text")
        }

        let missingRuntime = directory.appendingPathComponent("without-components/runtime")
        try FileManager.default.createDirectory(at: missingRuntime.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.linkItem(at: executable, to: missingRuntime)
        let missing = TaskService(executable: missingRuntime, storageDirectory: directory.appendingPathComponent("missing-settings"))
        defer { missing.shutdown() }
        let missingID = missing.createTask(workspace: workspace)
        await missing.send(taskID: missingID, text: #"latex-fixture:{"file_path":"main.tex"}"#, configuration: configuration)
        let missingTask = missing.tasks.first { $0.id == missingID }!
        try check(missingTask.status == .failed && missingTask.latexArtifacts.isEmpty
            && missingTask.tools.last?.output.contains("排版组件说明") == true,
            "A real runtime without its compiler provides a dependency explanation and no false PDF")

        let closing = TaskService(executable: executable, storageDirectory: directory.appendingPathComponent("closing-settings"))
        defer { closing.shutdown() }
        let closingID = closing.createTask(workspace: workspace)
        let directoriesBeforeClose = Set(try FileManager.default.contentsOfDirectory(atPath: workspace.path))
        let closingRun = Task { await closing.send(taskID: closingID, text: #"latex-fixture:{"file_path":"busy.tex"}"#, configuration: configuration) }
        let startDeadline = Date().addingTimeInterval(10)
        var closingPIDs: [Int32] = []
        while closingPIDs.isEmpty && Date() < startDeadline {
            closingPIDs = try processes(matching: workspace.resolvingSymlinksInPath().path + "/busy.tex")
            if closingPIDs.isEmpty { try await Task.sleep(nanoseconds: 20_000_000) }
        }
        // A failed regression must not leave this test's real compiler running.
        defer { for pid in closingPIDs where kill(pid, 0) == 0 { _ = kill(pid, SIGKILL) } }
        try check(!closingPIDs.isEmpty, "A real compiler must start before testing application shutdown")
        closing.shutdown()
        await closingRun.value
        let cleanupDeadline = Date().addingTimeInterval(5)
        while Date() < cleanupDeadline {
            let processesGone = try processes(matching: workspace.resolvingSymlinksInPath().path + "/busy.tex").isEmpty
            let directories = Set(try FileManager.default.contentsOfDirectory(atPath: workspace.path))
            if processesGone && directories == directoriesBeforeClose { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try check(try processes(matching: workspace.resolvingSymlinksInPath().path + "/busy.tex").isEmpty,
            "Application shutdown must reap the running compiler instead of leaving an orphan")
        try check(Set(try FileManager.default.contentsOfDirectory(atPath: workspace.path)) == directoriesBeforeClose,
            "Application shutdown must remove the uncompleted compilation directory")
        try check(closing.tasks.first { $0.id == closingID }?.latexArtifacts.isEmpty == true,
            "Application shutdown must not deliver a late PDF")

        try Data("modified after compilation".utf8).write(to: secondArtifact.pdfFile)
        do {
            _ = try secondArtifact.checkedPDFData(in: workspace)
            throw failure("Changed PDF bytes must not be previewed or exported as the compiled artifact")
        } catch let error as NSError where error.domain == "TaskLatexTests" { throw error }
        catch { /* Expected: a changed file is not the recorded compilation. */ }
        print("PASS: LaTeX PDF, sources, warnings, recompile, history, failures, isolation, cancellation and missing components through TaskService")
    }

    static func processes(matching pattern: String) throws -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: bytes, as: UTF8.self).split(separator: "\n").compactMap { Int32($0) }
    }

    static func failure(_ message: String) -> NSError {
        NSError(domain: "TaskLatexTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw failure(message) }
    }
}
