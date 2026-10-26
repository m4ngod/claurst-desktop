import Foundation
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskTemporaryTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let executable = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        if CommandLine.arguments.count == 4 {
            guard setpgid(0, 0) == 0 else { throw POSIXError(.EPERM) }
            let service = TaskService(executable: executable, storageDirectory: URL(fileURLWithPath: CommandLine.arguments[1]), allowKeychainUI: false)
            let task = service.createTask(workspace: URL(fileURLWithPath: CommandLine.arguments[2]), temporary: true)
            let config = ModelConfiguration(endpoint: CommandLine.arguments[3], model: "fixture", apiKey: "", isTest: true)
            await service.send(taskID: task, text: "write-fixture:{\"file_path\":\"crash.txt\",\"content\":\"TEMP_CRASH_BODY_931\"}", configuration: config)
            try check(service.tasks.first?.changes.count == 1, "crash child actual write and preview")
            let running = Task { await service.send(taskID: task, text: "ask-fixture", configuration: config) }
            try await wait { service.tasks.first?.status == .answering }
            print(task.uuidString); fflush(stdout)
            await running.value
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        let storage = directory.appendingPathComponent("app")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let records = directory.appendingPathComponent("requests.jsonl")
        let fixture = Process(); fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/personalization_server.py").path, records.path]
        let pipe = Pipe(); fixture.standardOutput = pipe; fixture.standardError = FileHandle.nullDevice
        try fixture.run(); defer { fixture.terminate() }
        let port = String(data: pipe.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture", apiKey: "", isTest: true)
        let service = TaskService(executable: executable, storageDirectory: storage, allowKeychainUI: false)
        defer { service.shutdown() }
        try service.saveCustomInstructions("CUSTOM_TEMP_931")
        try service.saveSoul("SOUL_TEMP_931")
        try service.setMemoryEnabled(true)
        let ordinary = service.createTask(workspace: workspace)
        await service.send(taskID: ordinary, text: "我偏好简洁回答。项目代号为 ALPHA_PRIVATE_731", configuration: config)
        try await wait { service.memories.count == 2 }
        let memoryBefore = try Data(contentsOf: storage.appendingPathComponent("memories.json"))
        let beforeRequests = try String(contentsOf: records).split(separator: "\n").count
        let temporary = service.createTask(workspace: workspace, temporary: true)
        try check(service.tasks.first?.isTemporary == true, "mode fixed at creation")
        await service.send(taskID: temporary, text: "TEMP_CHAT_SENTINEL_931", configuration: config)
        await service.send(taskID: temporary, text: "write-fixture:{\"file_path\":\"result.txt\",\"content\":\"TEMP_FILE_BODY_931\"}", configuration: config)
        try check(service.tasks.first?.status == .completed, "temporary tools complete")
        let change = service.tasks.first!.changes.first!
        try check(change.after == "TEMP_FILE_BODY_931", "in-memory preview")
        try check(!FileManager.default.fileExists(atPath: change.record.path), "no recovery snapshot file")
        service.reloadHistory()
        let asking = Task { await service.send(taskID: temporary, text: "ask-fixture", configuration: config) }
        try await wait { service.tasks.first?.status == .answering }
        service.answerQuestion(taskID: temporary, requestID: service.tasks.first!.questions.last!.id, text: "普通读者")
        await asking.value
        let stopping = Task { await service.send(taskID: temporary, text: "ask-fixture", configuration: config) }
        try await wait { service.tasks.first?.status == .answering }
        service.stop(taskID: temporary)
        await stopping.value
        try check(service.tasks.first?.status == .stopped, "temporary stop")
        await service.send(taskID: temporary, text: "TEMP_CONTINUE_931", configuration: config)
        try check(service.tasks.first?.status == .completed, "temporary continue")
        let requests = try String(contentsOf: records).split(separator: "\n").dropFirst(beforeRequests).map(String.init)
        try check(requests.allSatisfy { $0.contains("CUSTOM_TEMP_931") && $0.contains("SOUL_TEMP_931") && !$0.contains("ALPHA_PRIVATE_731") && !$0.contains("我偏好简洁回答") }, "every temporary model request gets preferences but no personal/project memory")
        try check(requests.allSatisfy { (try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])?["stream"] as? Bool == true }, "no extraction requests")
        try check(try Data(contentsOf: storage.appendingPathComponent("memories.json")) == memoryBefore, "no memory writes or cursor")
        try assertNoTemporaryData(storage, ids: [temporary], sentinels: ["TEMP_CHAT_SENTINEL_931", "TEMP_FILE_BODY_931", "TEMP_CONTINUE_931"])
        try check(await service.restoreChange(taskID: temporary, changeID: change.id), "temporary in-memory recovery")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("result.txt").path), "recovery changes actual file")
        await service.send(taskID: temporary, text: "write-fixture:{\"file_path\":\"result.txt\",\"content\":\"TEMP_FILE_BODY_931\"}", configuration: config)
        service.shutdown()
        let restarted = TaskService(executable: executable, storageDirectory: storage, allowKeychainUI: false)
        try check(restarted.tasks.map(\.id) == [ordinary], "only ordinary history restored")
        try check(try String(contentsOf: workspace.appendingPathComponent("result.txt")) == "TEMP_FILE_BODY_931", "actual result survives normal exit")
        restarted.shutdown()
        let child = Process(); child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.arguments = [storage.path, workspace.path, config.endpoint]
        let childPipe = Pipe(); child.standardOutput = childPipe; child.standardError = FileHandle.standardError
        try child.run()
        let idText = String(data: childPipe.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let crashID = UUID(uuidString: idText) else { throw Failure(message: "crash child did not reach checkpoint") }
        kill(-child.processIdentifier, SIGKILL); child.waitUntilExit()
        try assertNoTemporaryData(storage, ids: [temporary, crashID], sentinels: ["TEMP_CHAT_SENTINEL_931", "TEMP_FILE_BODY_931", "TEMP_CONTINUE_931", "TEMP_CRASH_BODY_931"])
        let afterCrash = TaskService(executable: executable, storageDirectory: storage, allowKeychainUI: false)
        try check(afterCrash.tasks.map(\.id) == [ordinary], "SIGKILL restores only ordinary task")
        try check(try String(contentsOf: workspace.appendingPathComponent("crash.txt")) == "TEMP_CRASH_BODY_931", "SIGKILL preserves actual result")
        afterCrash.shutdown()
        print("PASS temporary sessions: real ACP, request isolation, controls, in-memory recovery, normal and SIGKILL disk audit")
    }
    static func assertNoTemporaryData(_ root: URL, ids: [UUID], sentinels: [String]) throws {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        for case let file as URL in files {
            try check(!ids.contains { file.path.contains($0.uuidString) }, "no temporary task history, lease or runtime directory: \(file.path)")
            if (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
                let body = String(decoding: try Data(contentsOf: file), as: UTF8.self)
                try check(!sentinels.contains { body.contains($0) }, "no temporary chat or snapshot body: \(file.path)")
            }
        }
    }
    @MainActor static func wait(_ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(20)
        while !condition(), Date() < end { try await Task.sleep(nanoseconds: 20_000_000) }
        try check(condition(), "condition timed out")
    }
    static func check(_ result: Bool, _ message: String) throws { if !result { throw Failure(message: message) } }
    struct Failure: Error { let message: String }
}
