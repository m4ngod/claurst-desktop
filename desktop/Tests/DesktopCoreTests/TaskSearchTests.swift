import Foundation
import Combine
import Security
import LocalAuthentication
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskSearchTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/search_server.py").path]
        let output = Pipe(); fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let settings = directory.appendingPathComponent("settings")
        let keychainService = "local.claurst.desktop.search-tests.\(UUID().uuidString)"
        defer {
            let context = LAContext(); context.interactionNotAllowed = true
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
                kSecUseAuthenticationContext as String: context]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound { print("Test credential cleanup failed: \(status)") }
        }
        let service = TaskService(executable: executable, storageDirectory: settings, keychainService: keychainService, allowKeychainUI: false)
        defer { service.shutdown() }
        let configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "synthetic-search-key", isTest: true, webSearchEnabled: true)
        let id = service.createTask(workspace: directory)
        await service.send(taskID: id, text: #"search-fixture:{"query":"SearXNG JSON 搜索 API"}"#, configuration: configuration)
        let task = service.tasks.first { $0.id == id }!
        try check(task.status == .completed && task.tools.count == 1 && task.tools.first?.status == "完成",
            "configured search must finish through the real task: \(task.error ?? "") / \(task.tools.map(\.output))")
        let reply = task.messages.last?.text ?? ""
        try check(reply.contains("https://docs.searxng.org/dev/search_api.html") && reply.contains("Search settings")
            && !reply.contains("invented.example") && task.webSources.isEmpty,
            "only tool-reported search candidates may be returned; they are not already-read webpages: \(reply)")
        var disabled = configuration
        disabled.webSearchEnabled = false
        await service.send(taskID: id, text: #"search-fixture:{"query":"must stay disabled"}"#, configuration: disabled)
        let revoked = service.tasks.first { $0.id == id }!
        try check(revoked.status == .failed && revoked.tools.last?.output.contains("尚未启用") == true,
            "disabling search must take effect on the next turn of an existing task")
        let saved = try await service.saveModelProfile(name: "搜索测试", configuration: configuration)
        let persisted = try await service.modelConfiguration(profileID: saved.id)
        try check(persisted.webSearchEnabled, "saving a search choice must enable the selected service")
        let reopened = TaskService(executable: executable, storageDirectory: settings, keychainService: keychainService, allowKeychainUI: false)
        defer { reopened.shutdown() }
        let reloaded = try await reopened.modelConfiguration(profileID: saved.id)
        try check(reloaded.webSearchEnabled, "search configuration must survive reopening")
        _ = try await service.saveModelProfile(id: saved.id, name: "搜索测试", configuration: disabled)
        let savedDisabled = try await service.modelConfiguration(profileID: saved.id)
        try check(!savedDisabled.webSearchEnabled, "disabling a saved service must persist without replacing credentials")
        _ = try await service.saveModelProfile(id: saved.id, name: "搜索测试", configuration: configuration)
        let steeringID = service.createTask(workspace: directory)
        let steering = Task { await service.send(taskID: steeringID, text: #"search-fixture:{"query":"fixture-slow-steer"}"#, profileID: saved.id) }
        var steerStarted = false
        let steerDeadline = Date().addingTimeInterval(10)
        while !steerStarted && Date() < steerDeadline {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/steer-started")!)
            steerStarted = String(decoding: data, as: UTF8.self) == "yes"
            if !steerStarted { try await Task.sleep(nanoseconds: 20_000_000) }
        }
        try check(steerStarted, "active profile regression must reach search HTTP")
        _ = try await service.saveModelProfile(id: saved.id, name: "搜索测试", configuration: disabled)
        await service.send(taskID: steeringID, text: #"search-fixture:{"query":"search-revoked-during-active-task"}"#, profileID: saved.id)
        await steering.value
        let steered = service.tasks.first { $0.id == steeringID }!
        try check(steered.status == .failed && steered.requirements.allSatisfy { $0.state == .applied }
            && steered.tools.last?.output.contains("尚未启用") == true,
            "saved search revocation must take effect when an active task resumes with supplemental requirements")
        // Allow only this synthetic loopback webpage, using the same visible
        // permission question that the real task raises for private networks.
        let chainID = service.createTask(workspace: directory)
        let observation = service.$tasks.sink { tasks in
            for task in tasks where task.id == chainID {
                for permission in task.permissions {
                    Task { @MainActor in service.answerPermission(taskID: task.id, requestID: permission.id, allow: true) }
                }
            }
        }
        defer { observation.cancel() }
        await service.send(taskID: chainID, text: #"search-fixture:{"query":"fixture-chain"}"#, configuration: configuration)
        let chain = service.tasks.first { $0.id == chainID }!
        try check(chain.status == .completed && chain.tools.count == 2 && chain.webSources.count == 1
            && chain.webSources.first?.title == "搜索后的真实正文" && chain.webSources.first?.excerpt == "1\t银杏预算：73 元\n"
            && chain.messages.last?.text.contains(chain.webSources.first?.reference ?? "missing-reference") == true,
            "search candidates must lead to actual webpage reading before a located citation is recorded")
        for (query, expected) in [("fixture-no-search", "没有可核验"), ("fixture-empty", "没有可核验"),
                                 ("fixture-missing-status", "未返回有效"),
                                 ("fixture-invalid-links", "没有可核验"), ("fixture-incomplete", "未完成搜索"),
                                 ("fixture-http-error", "HTTP 401"), ("fixture-oversize", "2 MiB")] {
            let failed = service.createTask(workspace: directory)
            await service.send(taskID: failed, text: "search-fixture:{\"query\":\"\(query)\"}", configuration: configuration)
            let result = service.tasks.first { $0.id == failed }!
            try check(result.status == .failed && result.webSources.isEmpty && result.tools.last?.output.contains(expected) == true
                && result.messages.last?.text.contains("synthetic-search-key") == false,
                "search failure must be visible without fabricated evidence or error-body secrets: \(query): \(result.tools.map(\.output))")
        }
        let cancelID = service.createTask(workspace: directory)
        let pending = Task { await service.send(taskID: cancelID, text: #"search-fixture:{"query":"fixture-slow-cancel"}"#, configuration: configuration) }
        var started = false
        let startDeadline = Date().addingTimeInterval(10)
        while !started && Date() < startDeadline {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/started")!)
            started = String(decoding: data, as: UTF8.self) == "yes"
            if !started { try await Task.sleep(nanoseconds: 20_000_000) }
        }
        try check(started, "cancellation must reach the real search HTTP boundary")
        let stoppedAt = Date()
        service.stop(taskID: cancelID)
        await pending.value
        let cancelled = service.tasks.first { $0.id == cancelID }!
        try check(cancelled.status == .stopped && Date().timeIntervalSince(stoppedAt) < 2
            && cancelled.tools.last?.output.contains("Search settings") != true && cancelled.webSources.isEmpty,
            "Stop must cancel a pending search without late results")
        if !CommandLine.arguments.contains("--quick") {
            let timeoutID = service.createTask(workspace: directory)
            await service.send(taskID: timeoutID, text: #"search-fixture:{"query":"fixture-timeout"}"#, configuration: configuration)
            let result = service.tasks.first { $0.id == timeoutID }!
            try check(result.status == .failed && result.tools.last?.output.contains("超时") == true && result.webSources.isEmpty,
                "search timeout must be reported without fallback")
        }
        print("PASS: configured search candidates through TaskService → ACP → search HTTP")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskSearchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
