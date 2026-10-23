import Foundation
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskHistoryTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if CommandLine.arguments.count == 5 {
            // Isolate the fixture process and its actual ACP child for abrupt termination.
            guard setpgid(0, 0) == 0 else { throw POSIXError(.EPERM) }
            let child = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: URL(fileURLWithPath: CommandLine.arguments[1]))
            let id = child.createTask(workspace: URL(fileURLWithPath: CommandLine.arguments[2]))
            let configuration = ModelConfiguration(endpoint: CommandLine.arguments[3], model: "fixture-model", apiKey: "test-only", isTest: true)
            let running = Task { await child.send(taskID: id, text: "write-then-ask-fixture:crash.txt", configuration: configuration) }
            try await wait { child.tasks.first?.status == .answering }
            try await Task.sleep(nanoseconds: 300_000_000)
            print(id.uuidString); fflush(stdout)
            await running.value
            return
        }
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
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let settings = directory.appendingPathComponent("settings")
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let first = TaskService(executable: runtime, storageDirectory: settings)
        defer { first.shutdown() }
        try "项目：银杏\n预算：73 元\n".write(to: workspace.appendingPathComponent("budget.md"), atomically: true, encoding: .utf8)
        let id = first.createTask(workspace: workspace)
        await first.send(taskID: id, text: "read-fixture:budget.md", configuration: config)
        await first.send(taskID: id, text: "write-fixture:{\"file_path\":\"result.txt\",\"content\":\"银杏：73 元\\n\"}", configuration: config)
        first.shutdown()
        let reopened = TaskService(executable: runtime, storageDirectory: settings)
        defer { reopened.shutdown() }
        try check(reopened.tasks.count == 1, "reopening retains the task")
        let task = reopened.tasks[0]
        try check(task.id == id && task.status == .completed, "completed task keeps its identity and status")
        try check(task.messages.count == 4 && task.messages[1].text.contains("银杏"), "visible conversation survives reopening")
        try check(task.sources.first?.firstLine == 1 && task.sources.first?.excerpt.contains("预算：73 元") == true, "source contents and positions survive reopening")
        try check(task.changes.first?.after == "银杏：73 元\n", "change preview survives reopening")
        try check(task.tools.count == 2 && task.tools.allSatisfy { $0.status == "完成" }, "execution records survive reopening")
        let resultFile = workspace.appendingPathComponent("result.txt")
        try "用户之后的编辑\n".write(to: resultFile, atomically: true, encoding: .utf8)
        await reopened.send(taskID: id, text: "recovered-history-fixture", configuration: config)
        try check(reopened.tasks.first?.status == .completed, "reopened task can continue from saved history")
        try check(reopened.tasks.first?.messages.last?.text == "历史包含银杏预算与已完成成果", "the model receives saved source and completed change history")
        try check(try String(contentsOf: resultFile) == "用户之后的编辑\n", "continuing never replays a previous write")
        try check(reopened.tasks.first?.changes.count == 1, "continuing does not duplicate completed change receipts")
        await reopened.send(taskID: id, text: "write-fixture:{\"file_path\":\"budget.md\",\"content\":\"不得沿用旧读取授权\"}", configuration: config)
        try check(reopened.tasks.first?.status == .failed, "recovery requires a fresh read before overwriting")
        try check(try String(contentsOf: workspace.appendingPathComponent("budget.md")) == "项目：银杏\n预算：73 元\n", "old read history cannot authorize a new overwrite")

        let crashSettings = directory.appendingPathComponent("crash-settings")
        let crash = Process()
        crash.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        crash.arguments = [crashSettings.path, workspace.path, config.endpoint, "crash-fixture"]
        let readiness = Pipe(); crash.standardOutput = readiness; crash.standardError = FileHandle.nullDevice
        try crash.run()
        defer { if crash.isRunning { kill(-crash.processIdentifier, SIGKILL) } }
        let taskID = String(data: readiness.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        try check(UUID(uuidString: taskID) != nil, "crash fixture reached its real question after writing")
        kill(-crash.processIdentifier, SIGKILL)
        crash.waitUntilExit()
        let afterCrash = TaskService(executable: runtime, storageDirectory: crashSettings)
        defer { afterCrash.shutdown() }
        try check(afterCrash.tasks.first?.status == .stopped, "abrupt exit never restores a running task as completed")
        try check(afterCrash.tasks.first?.changes.count == 1, "abrupt exit preserves already completed write receipts")
        try check(afterCrash.tasks.first?.questions.first?.isPending == false, "dead question requests do not survive a process restart")
        try check(afterCrash.tasks.first?.tools.contains { $0.status.contains("中断") } == true, "in-flight tool is explicitly marked interrupted")
        try check(try String(contentsOf: workspace.appendingPathComponent("crash.txt")) == "先完成的写入\n", "completed file remains after abrupt exit")
        try FileManager.default.removeItem(at: resultFile)
        let missing = TaskService(executable: runtime, storageDirectory: settings)
        defer { missing.shutdown() }
        try check(missing.tasks.first?.recoveryWarnings.contains { $0.contains("result.txt") } == true, "missing artifacts have a visible recovery warning")
        try check(missing.tasks.first?.changes.first?.after == "银杏：73 元\n", "missing artifacts do not erase the saved change preview")

        let broken = settings.appendingPathComponent("history/" + UUID().uuidString + ".json")
        try Data("broken-history".utf8).write(to: broken)
        let partial = TaskService(executable: runtime, storageDirectory: settings)
        defer { partial.shutdown() }
        try check(partial.tasks.count == 1 && partial.historyError?.contains("损坏") == true, "one damaged history is reported without hiding healthy tasks")
        _ = partial.createTask(workspace: workspace)
        try check(try String(contentsOf: broken) == "broken-history", "damaged history is never silently overwritten")

        let privateSettings = directory.appendingPathComponent("private-settings")
        let privacy = TaskService(executable: runtime, storageDirectory: privateSettings)
        let privateConfig = ModelConfiguration(endpoint: config.endpoint, model: config.model, apiKey: "private-fixture-secret", isTest: true)
        let privateID = privacy.createTask(workspace: workspace)
        await privacy.send(taskID: privateID, text: "private-history-fixture:private-fixture-secret", configuration: privateConfig)
        privacy.shutdown()
        let privateFiles = try FileManager.default.contentsOfDirectory(at: privateSettings.appendingPathComponent("history"), includingPropertiesForKeys: nil)
        for file in privateFiles where file.pathExtension == "json" {
            let saved = try String(contentsOf: file)
            try check(!saved.contains("private-fixture-secret") && !saved.contains("HIDDEN_REASONING_MUST_NOT_PERSIST"), "history excludes model credentials and hidden reasoning")
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            try check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "history is readable only by its owner")
        }
        let permissionSettings = directory.appendingPathComponent("permission-settings")
        let permissions = TaskService(executable: runtime, storageDirectory: permissionSettings)
        let outside = directory.appendingPathComponent("outside.txt")
        try "范围外的样本".write(to: outside, atomically: true, encoding: .utf8)
        let permissionID = permissions.createTask(workspace: workspace)
        let allowed = Task { await permissions.send(taskID: permissionID, text: "read-fixture:" + outside.path, configuration: config) }
        try await wait { permissions.tasks.first?.permissions.isEmpty == false }
        let oldQuestion = permissions.tasks.first!.permissions.first!.id
        permissions.answerPermission(taskID: permissionID, requestID: oldQuestion, allow: true)
        await allowed.value
        permissions.shutdown()
        let restoredPermissions = TaskService(executable: runtime, storageDirectory: permissionSettings)
        defer { restoredPermissions.shutdown() }
        let denied = Task { await restoredPermissions.send(taskID: permissionID, text: "read-fixture:" + outside.path, configuration: config) }
        try await wait { restoredPermissions.tasks.first?.permissions.isEmpty == false }
        restoredPermissions.answerPermission(taskID: permissionID, requestID: oldQuestion, allow: true)
        try check(restoredPermissions.tasks.first?.status == .waiting, "old permission answers cannot authorize a restored task")
        restoredPermissions.answerPermission(taskID: permissionID, requestID: restoredPermissions.tasks.first!.permissions.first!.id, allow: false)
        await denied.value
        try check(restoredPermissions.tasks.first?.sources.count == 1, "restored outside access is checked again and refusal preserves only the original source")

        let concurrentSettings = directory.appendingPathComponent("concurrent-settings")
        let owner = TaskService(executable: runtime, storageDirectory: concurrentSettings)
        let sharedID = owner.createTask(workspace: workspace)
        await owner.send(taskID: sharedID, text: "first-turn", configuration: config)
        owner.shutdown()
        let stale = TaskService(executable: runtime, storageDirectory: concurrentSettings)
        defer { stale.shutdown(); owner.shutdown() }
        await owner.send(taskID: sharedID, text: "newer-turn", configuration: config)
        var unsent = "write-fixture:{\"file_path\":\"stale-must-not-write.txt\",\"content\":\"unexpected\"}"
        await stale.send(taskID: sharedID, text: unsent, configuration: config) { unsent = "" }
        try check(!unsent.isEmpty && stale.historyError != nil, "stale application cannot overwrite a newer task history")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("stale-must-not-write.txt").path), "history conflict is detected before executing tools")
        owner.shutdown()
        stale.reloadHistory()
        try check(stale.historyError == nil && stale.tasks.first?.messages.contains { $0.text == "newer-turn" } == true, "reload retrieves the newer history and resolves the conflict")
        await stale.send(taskID: sharedID, text: "after-reload", configuration: config)
        try check(stale.tasks.first?.status == .completed, "task can continue after a history conflict is resolved")
        try FileManager.default.removeItem(at: broken)
        partial.reloadHistory()
        try check(partial.historyError == nil, "repairing the damaged history and reloading clears its warning")

        let replacedWorkspace = directory.appendingPathComponent("replaced-workspace")
        try FileManager.default.createDirectory(at: replacedWorkspace, withIntermediateDirectories: true)
        let replacedService = TaskService(executable: runtime, storageDirectory: directory.appendingPathComponent("replaced-settings"))
        defer { replacedService.shutdown() }
        let replacedID = replacedService.createTask(workspace: replacedWorkspace)
        try FileManager.default.moveItem(at: replacedWorkspace, to: directory.appendingPathComponent("original-workspace"))
        try FileManager.default.createDirectory(at: replacedWorkspace, withIntermediateDirectories: true)
        var retained = "write-fixture:{\"file_path\":\"wrong-directory.txt\",\"content\":\"unexpected\"}"
        await replacedService.send(taskID: replacedID, text: retained, configuration: config) { retained = "" }
        try check(!retained.isEmpty && replacedService.tasks.first?.error?.contains("工作文件夹") == true, "a replaced workspace requires a fresh user selection")
        try check(!FileManager.default.fileExists(atPath: replacedWorkspace.appendingPathComponent("wrong-directory.txt").path), "directory identity check prevents writes to a replacement")
        let liveSettings = directory.appendingPathComponent("live-settings")
        let live = TaskService(executable: runtime, storageDirectory: liveSettings)
        defer { live.shutdown() }
        let liveID = live.createTask(workspace: workspace)
        let liveRun = Task { await live.send(taskID: liveID, text: "ask-fixture", configuration: config) }
        try await wait { live.tasks.first?.status == .answering }
        try await Task.sleep(nanoseconds: 300_000_000)
        let observer = TaskService(executable: runtime, storageDirectory: liveSettings)
        try check(observer.tasks.first?.status.rawValue == "另一个窗口中", "a live task in another instance is not reported as interrupted")
        await observer.send(taskID: liveID, text: "must-not-take-over", configuration: config)
        try check(observer.tasks.first?.messages.last?.text != "测试回复：must-not-take-over", "another instance cannot execute the same live task")
        observer.shutdown()
        live.answerQuestion(taskID: liveID, requestID: live.tasks.first!.questions.first!.id, text: "研究人员")
        await liveRun.value
        try check(live.historyError == nil, "opening and closing an observer does not overwrite the live task")
        live.shutdown()
        observer.reloadHistory()
        try check(observer.tasks.first?.questions.first?.answer == "研究人员", "after the owner exits another instance can recover its latest answer")
        observer.shutdown()
        print("PASS: task history through TaskService → ACP → real files")
    }

    @MainActor static func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        try check(condition(), "condition did not become true before deadline")
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskHistoryTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
