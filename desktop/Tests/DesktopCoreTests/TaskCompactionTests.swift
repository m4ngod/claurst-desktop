import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskCompactionTests {
    @MainActor static func main() async throws {
        let overflow = CommandLine.arguments.contains("--overflow")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/compaction_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(data: output.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let settings = directory.appendingPathComponent("settings")
        let initial = TaskService(executable: runtime, storageDirectory: settings)
        let id = initial.createTask(workspace: directory)
        initial.shutdown()
        let history = settings.appendingPathComponent("history/" + id.uuidString + ".json")
        var record = try JSONSerialization.jsonObject(with: Data(contentsOf: history)) as! [String: Any]
        var saved = record["task"] as! [String: Any]
        let evidence = "保留原始依据：" + String(repeating: "historical evidence ", count: overflow ? 8_000 : 60_000)
        saved["messages"] = [["id": UUID().uuidString, "role": "user", "text": evidence],
                             ["id": UUID().uuidString, "role": "assistant", "text": "已保存依据"]]
        record["task"] = saved
        try JSONSerialization.data(withJSONObject: record).write(to: history)
        let service = TaskService(executable: runtime, storageDirectory: settings)
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: overflow ? "fixture-compaction-overflow" : "fixture-compaction", apiKey: "test-only", isTest: true)
        let running = Task { await service.send(taskID: id, text: "继续核对，但尚未授权任何修改", configuration: config) }
        let stateURL = URL(string: "http://127.0.0.1:\(port)/state")!
        let deadline = Date().addingTimeInterval(8)
        var started = false
        while !started && Date() < deadline {
            let (data, _) = try await URLSession.shared.data(from: stateURL)
            started = (try JSONSerialization.jsonObject(with: data) as! [String: Any])["summary_started"] as? Bool == true
            if !started { try await Task.sleep(nanoseconds: 10_000_000) }
        }
        try check(started, "restored history must reach the actual HTTP summariser before cancellation")
        service.stop(taskID: id)
        let stopDeadline = Date().addingTimeInterval(2)
        while service.tasks.first?.status != .stopped && Date() < stopDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try check(service.tasks.first?.status == .stopped, "cancelling compaction must finish promptly, not remain stopping")
        await running.value
        _ = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/release")!)
        let responseDeadline = Date().addingTimeInterval(2)
        var finished = false
        while !finished && Date() < responseDeadline {
            let (data, _) = try await URLSession.shared.data(from: stateURL)
            finished = (try JSONSerialization.jsonObject(with: data) as! [String: Any])["summary_finished"] as? Bool == true
            if !finished { try await Task.sleep(nanoseconds: 10_000_000) }
        }
        try check(finished, "fixture must attempt its late summary response after cancellation")
        let (state, _) = try await URLSession.shared.data(from: stateURL)
        let requests = (try JSONSerialization.jsonObject(with: state) as! [String: Any])["requests"] as! [String]
        try check(requests == (overflow ? ["agent", "summary"] : ["summary"]), "cancelled summary must not retry or start another agent request")
        try check(service.tasks.first?.messages.first?.text == evidence, "cancellation preserves original visible history")
        let shortID = service.createTask(workspace: directory)
        var shortConfig = config
        shortConfig.model = "fixture-compaction"
        await service.send(taskID: shortID, text: "短请求", configuration: shortConfig)
        try check(service.tasks.first(where: { $0.id == shortID })?.status == .completed, "a new task remains usable after cancelling compaction")
        print("PASS: cancel real restored-history compaction promptly, preserve history, no late agent request")
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskCompactionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
