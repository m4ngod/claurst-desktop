import Foundation
import Darwin

/// Opt-in smoke only. Reads an existing profile; all conversations/settings use
/// an isolated directory and synthetic content. Never accepts credentials on argv.
@main struct LivePersonalizationChecks {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let models = ModelSettingsStore(directory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ClaurstDesktop"), service: "local.claurst.desktop.models", allowInteraction: false)
        let preferred = CommandLine.arguments.dropFirst().first
        guard let profile = try models.load().first(where: { !$0.isTest && !$0.model.lowercased().contains("claude") && (preferred == nil || $0.name == preferred) }) else {
            fail("BLOCKED: no saved non-Claude profile")
        }
        print("Service: \(profile.name) | \(profile.model) | \(URL(string: profile.endpoint)?.host ?? "unknown")")
        let key: String
        do { key = try await models.readSecret(profile.secretReference) }
        catch { fail("BLOCKED: saved credential unavailable without Keychain interaction") }
        let config = ModelConfiguration(endpoint: profile.endpoint, model: profile.model, apiKey: key)
        let workspace = root.appendingPathComponent(".build/personalization-evidence/live-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: workspace.appendingPathComponent("app"), allowKeychainUI: false)
        defer { service.shutdown() }
        try service.saveCustomInstructions("请用中文简短回答，并以【验收】开头。")
        try service.saveSoul("温和直接，不编造未提供的信息。")
        let task = service.createTask(workspace: workspace)
        await service.send(taskID: task, text: "向我简短问好，不使用工具。", configuration: config)
        guard let first = service.tasks.first, first.status == .completed else {
            fail("BLOCKED: initial real request failed | \(service.tasks.first?.error ?? "unknown")")
        }
        guard first.messages.last?.text.contains("【验收】") == true else {
            fail("FAIL: saved instructions not followed")
        }
        print("PASS: personalization real response")
        try service.setMemoryEnabled(true)
        await service.send(taskID: task, text: "我偏好简洁回答。项目代号为 ORCHID_SMOKE_931。请记住这些信息，只简短确认，不使用工具。", configuration: config)
        let deadline = Date().addingTimeInterval(35)
        while service.tasks.first?.memoryNotice == "正在整理记忆…", Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        guard service.memories.contains(where: { $0.scope == "personal" }), service.memories.contains(where: { $0.content.contains("ORCHID_SMOKE_931") }) else {
            fail("FAIL: real structured extraction did not produce both scopes | \(service.tasks.first?.memoryNotice ?? "no notice")")
        }
        let recall = service.createTask(workspace: workspace)
        await service.send(taskID: recall, text: "按已保存记忆，告诉我项目代号和回答偏好。不要调用工具。", configuration: config)
        guard service.tasks.first?.status == .completed, service.tasks.first?.messages.last?.text.contains("ORCHID_SMOKE_931") == true else {
            fail("FAIL: ordinary new-session memory recall")
        }
        print("PASS: real extraction and ordinary new-session recall")
        // Let the ordinary turn's extraction finish before measuring temporary
        // isolation; its legitimate background save is unrelated to the latter.
        let recallDeadline = Date().addingTimeInterval(35)
        while service.tasks.first?.memoryNotice == "正在整理记忆…", Date() < recallDeadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard service.tasks.first?.memoryNotice != "正在整理记忆…" else { fail("FAIL: ordinary extraction did not settle before temporary check") }
        let memoryBefore = try Data(contentsOf: workspace.appendingPathComponent("app/memories.json"))
        let temporary = service.createTask(workspace: workspace, temporary: true)
        await service.send(taskID: temporary, text: "你知道我的项目代号吗？只依据当前上下文，不调用工具；没有就说不知道。", configuration: config)
        guard service.tasks.first?.status == .completed, let answer = service.tasks.first?.messages.last?.text,
              !answer.contains("ORCHID_SMOKE_931"), answer.contains("【验收】"), service.tasks.first?.memoryNotice == nil,
              try Data(contentsOf: workspace.appendingPathComponent("app/memories.json")) == memoryBefore else {
            fail("FAIL: temporary real response or storage isolation")
        }
        service.shutdown()
        let restarted = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: workspace.appendingPathComponent("app"), allowKeychainUI: false)
        defer { restarted.shutdown() }
        guard !restarted.tasks.contains(where: { $0.id == temporary }) else { fail("FAIL: temporary history restored") }
        print("PASS: temporary personalization, no recalled project fact, unchanged memory, no restart history")
        print("PASS LIVE SMOKE. Request-level exclusion and forced-exit checks are independently covered by deterministic ACP tests.")
    }

    static func fail(_ message: String) -> Never {
        print(message)
        exit(EXIT_FAILURE)
    }
}
