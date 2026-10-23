import Foundation
import Combine
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskControlTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output
        fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(data: output.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        if CommandLine.arguments.contains("--shutdown-only") {
            try await checkShutdown(root: root, directory: directory, workspace: workspace, config: config)
            return
        }

        let task = service.createTask(workspace: workspace)
        await service.send(taskID: task, text: "write-fixture:{\"file_path\":\"keep.txt\",\"content\":\"已经完成的文件\\n\"}", configuration: config)
        try check(service.tasks.first?.changes.count == 1, "initial write was recorded")
        let running = Task { await service.send(taskID: task, text: "slow-write-fixture:must-not-exist.txt", configuration: config) }
        try await wait { service.tasks.first?.messages.last?.text == "等待停止" }
        service.stop(taskID: task)
        try check(service.tasks.first?.status.rawValue == "正在停止", "stop immediately shows that operations are ending")
        try await wait { service.tasks.first?.status.isActive == false }
        await running.value
        try check(service.tasks.first?.status == .stopped, "streaming turn stopped")
        try check(try String(contentsOf: workspace.appendingPathComponent("keep.txt")) == "已经完成的文件\n", "stop preserves completed writes")
        try check(service.tasks.first?.changes.count == 1, "stop preserves change receipts")
        await service.send(taskID: task, text: "continue-with-new-request", configuration: config)
        try await Task.sleep(nanoseconds: 1_200_000_000)
        try check(service.tasks.first?.status == .completed, "same task can continue")
        try check(service.tasks.first?.messages.last?.text == "测试回复：continue-with-new-request", "late output does not affect the continued run")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("must-not-exist.txt").path), "stop prevents later tool scheduling")
        try check(service.tasks.first?.changes.count == 1, "continue does not replay completed writes")
        let asking = service.createTask(workspace: workspace)
        let askRun = Task { await service.send(taskID: asking, text: "ask-fixture", configuration: config) }
        try await wait { service.tasks.first?.status.rawValue == "等待回答" }
        service.stop(taskID: asking)
        try await wait { service.tasks.first?.status == .stopped }
        await askRun.value
        try check(service.tasks.first?.questions.first?.isPending == false, "stopped questions close without an invented answer")
        let answering = service.createTask(workspace: workspace)
        let answerRun = Task { await service.send(taskID: answering, text: "ask-fixture", configuration: config) }
        try await wait { service.tasks.first?.questions.first?.isPending == true }
        let question = service.tasks.first!.questions.first!
        try check(question.question == "报告面向哪类读者？" && question.options == ["研究人员", "普通读者"], "question and options come from the actual tool")
        service.answerQuestion(taskID: answering, requestID: question.id, text: "面向初学者，保持简洁")
        try await wait { service.tasks.first?.status.isActive == false }
        await answerRun.value
        try check(service.tasks.first?.status == .completed, "answer resumes the waiting tool")
        try check(service.tasks.first?.messages.last?.text.contains("The user answered: 面向初学者，保持简洁") == true, "model receives the exact answer")
        try check(service.tasks.first?.questions.first?.answer == "面向初学者，保持简洁", "answer remains visible")
        let outside = directory.appendingPathComponent("outside.txt")
        try "越界内容".write(to: outside, atomically: true, encoding: .utf8)
        let permissionTask = service.createTask(workspace: workspace)
        let permissionRun = Task { await service.send(taskID: permissionTask, text: "read-fixture:" + outside.path, configuration: config) }
        try await wait { service.tasks.first?.permissions.isEmpty == false }
        let permission = service.tasks.first!.permissions.first!
        service.stop(taskID: permissionTask)
        service.answerPermission(taskID: permissionTask, requestID: permission.id, allow: true)
        try await wait { service.tasks.first?.status.isActive == false }
        await permissionRun.value
        try check(service.tasks.first?.status == .stopped, "permission wait can stop")
        try check(service.tasks.first?.sources.isEmpty == true, "late permission reply cannot resume stopped work")
        let steering = service.createTask(workspace: workspace)
        let steerRun = Task { await service.send(taskID: steering, text: "slow-write-fixture:steered-away.txt", configuration: config) }
        try await wait { service.tasks.first?.messages.last?.text == "等待停止" }
        var accepted = 0
        await service.send(taskID: steering, text: "先核对预算", configuration: config) { accepted += 1 }
        await service.send(taskID: steering, text: "再说明依据", configuration: config) { accepted += 1 }
        try check(accepted == 2, "requirements are accepted during a running turn")
        try await wait { service.tasks.first?.status == .completed }
        await steerRun.value
        let steered = service.tasks.first!
        let reply = steered.messages.last?.text ?? ""
        try check(reply.contains("先核对预算\n\n再说明依据"), "requirements are applied in arrival order")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("steered-away.txt").path), "steering stops superseded tool scheduling")
        try check(steered.requirements.map(\.state) == [.applied, .applied], "runtime confirms requirements were applied")
        try "不得在停止后读取".write(to: workspace.appendingPathComponent("after-stop.txt"), atomically: true, encoding: .utf8)
        // Repeat the actual task boundary: a nil question reply can overtake
        // the queued cancellation notification in the runtime's event loop.
        for attempt in 0..<100 {
            let batch = service.createTask(workspace: workspace)
            let path = "batch-written-\(attempt).txt"
            let batchRun = Task { await service.send(taskID: batch, text: "write-then-ask-fixture:" + path, configuration: config) }
            try await wait { service.tasks.first?.status == .answering }
            try check(try String(contentsOf: workspace.appendingPathComponent(path)) == "先完成的写入\n", "first tool really wrote before the question")
            service.stop(taskID: batch)
            try await wait { service.tasks.first?.status == .stopped }
            await batchRun.value
            try check(service.tasks.first?.changes.count == 1, "cancelling a batch retains the receipt of its completed write")
            try check(service.tasks.first?.sources.isEmpty == true, "a later read in the same batch does not run after stop (attempt \(attempt))")
        }
        let large = workspace.appendingPathComponent("large.txt")
        let originalSize = 8 * 1024 * 1024
        try Data(repeating: 120, count: originalSize).write(to: large)
        let fileTask = service.createTask(workspace: workspace)
        await service.send(taskID: fileTask, text: "read-fixture:large.txt", configuration: config)
        try check(service.tasks.first?.sources.count == 1, "large original file was really read")
        let fileRun = Task { await service.send(taskID: fileTask, text: "write-fixture:{\"file_path\":\"large.txt\",\"content\":\"不应发布的替换\\n\"}", configuration: config) }
        try await wait { service.tasks.first?.tools.last?.title.contains("Write") == true && service.tasks.first?.tools.last?.status == "执行中" }
        service.stop(taskID: fileTask)
        try await wait { service.tasks.first?.status == .stopped }
        await fileRun.value
        try check(try Data(contentsOf: large).count == originalSize, "stop during file preparation prevents publication")
        try check(service.tasks.first?.changes.isEmpty == true, "cancelled write has no success receipt")
        let failedTask = service.createTask(workspace: workspace)
        await service.send(taskID: failedTask, text: "write-fixture:{\"file_path\":\"before-error.txt\",\"content\":\"keep\"}", configuration: config)
        await service.send(taskID: failedTask, text: "simulate-auth-error", configuration: config)
        try check(service.tasks.first?.status == .failed, "model request failure is visible")
        await service.send(taskID: failedTask, text: "history-fixture", configuration: config)
        try check(service.tasks.first?.status == .completed, "can continue after a failed model request")
        try check(service.tasks.first?.messages.last?.text == "历史写入次数：1", "continue after failure preserves actual model history")
        try check(service.tasks.first?.changes.count == 1, "failure recovery does not replay completed writes")
        let manual = service.createTask(workspace: workspace)
        let manualRun = Task { await service.send(taskID: manual, text: "slow-write-fixture:manual-stop.txt", configuration: config) }
        try await wait { service.tasks.first?.messages.last?.text == "等待停止" }
        await service.send(taskID: manual, text: "保留这个补充要求", configuration: config) {
            service.stop(taskID: manual)
        }
        await manualRun.value
        try check(service.tasks.first?.status == .stopped, "explicit stop suppresses automatic continuation")
        try check(service.tasks.first?.requirements.first?.state == .received, "unapplied requirement remains pending after explicit stop")
        await service.send(taskID: manual, text: "现在继续", configuration: config)
        try check(service.tasks.first?.messages.last?.text == "测试回复：保留这个补充要求\n\n现在继续", "manual continuation applies the pending requirement once")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("manual-stop.txt").path), "manual continuation does not replay cancelled write")
        let startup = service.createTask(workspace: workspace)
        await service.send(taskID: startup, text: "write-fixture:{\"file_path\":\"startup.txt\",\"content\":\"unexpected\"}", configuration: config) {
            service.stop(taskID: startup)
        }
        try check(service.tasks.first?.status == .stopped, "stop during startup does not leave task active")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("startup.txt").path), "stopped startup cannot schedule a write")
        service.shutdown()
        var retainedDraft = "has-history-file:before-error.txt"
        await service.send(taskID: failedTask, text: retainedDraft, configuration: config) { retainedDraft = "" }
        let disconnected = service.tasks.first { $0.id == failedTask }!
        try check(disconnected.status == .completed, "disconnected runtime continues from restored visible history")
        try check(disconnected.messages.last?.text == "历史保留：before-error.txt", "restored runtime receives completed work context")
        try check(retainedDraft.isEmpty, "restored continuation accepts the draft")
        try check(disconnected.changes.count == 1, "disconnected runtime retains visible completed writes")
        try await checkShutdown(root: root, directory: directory, workspace: workspace, config: config)
        print("PASS: task controls through TaskService → ACP → real tools")
    }

    @MainActor static func checkShutdown(root: URL, directory: URL, workspace: URL, config: ModelConfiguration) async throws {
        let runtime = directory.appendingPathComponent("shutdown-runtime")
        try FileManager.default.linkItem(at: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), to: runtime)
        let outside = directory.appendingPathComponent("shutdown-outside.txt")
        try "Only an approved read may see this fixture".write(to: outside, atomically: true, encoding: .utf8)
        let closing = TaskService(executable: runtime, storageDirectory: directory.appendingPathComponent("shutdown-settings"))
        defer { closing.shutdown() }
        let task = closing.createTask(workspace: workspace)
        let running = Task { await closing.send(taskID: task, text: "read-fixture:" + outside.path, configuration: config) }
        try await wait { closing.tasks.first?.permissions.isEmpty == false }
        let pids = try processIDs(matching: runtime.path)
        defer { for pid in pids where kill(pid, 0) == 0 { _ = kill(pid, SIGKILL) } }
        try check(pids.count == 1, "one actual runtime is waiting for permission")
        closing.shutdown()
        await running.value
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && pids.contains(where: { kill($0, 0) == 0 }) { try await Task.sleep(nanoseconds: 20_000_000) }
        try check(!pids.contains(where: { kill($0, 0) == 0 }), "shutdown must terminate a runtime waiting for permission")
        try check(closing.tasks.first?.sources.isEmpty == true, "shutdown must not approve the pending read")
        print("PASS: shutdown releases the actual permission-waiting runtime")
    }

    static func processIDs(matching pattern: String) throws -> [Int32] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: bytes, as: UTF8.self).split(separator: "\n").compactMap { Int32($0) }
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskControlTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    @MainActor static func wait(line: Int = #line, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        try check(condition(), "condition did not become true before deadline at line \(line)")
    }
}
