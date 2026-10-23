import Foundation
import Security
import LocalAuthentication
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskVisionTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(data: output.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let keychainService = "local.claurst.desktop.vision-tests.\(UUID().uuidString)"
        defer {
            let context = LAContext(); context.interactionNotAllowed = true
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
                kSecUseAuthenticationContext as String: context]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound { print("Test credential cleanup failed: \(status)") }
            try? FileManager.default.removeItem(at: directory)
        }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory, keychainService: keychainService, allowKeychainUI: false)
        defer { service.shutdown() }
        var configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        if CommandLine.arguments.contains("--timeout-only") {
            configuration.model = "fixture-slow-tool-check"
            let saved = try await service.saveModelProfile(name: "超时测试", configuration: configuration)
            let checked = try await service.checkModelProfile(id: saved.id)
            try check(checked.textCapability == .verified && checked.toolCapability == .unknown, "tool phase must hit the connection check deadline")
            try check(checked.imageCapability == .unknown, "a timed-out connection check must not start a new image request")
            print("PASS: timed-out connection check did not restart for an image request")
            return
        }
        let saved = try await service.saveModelProfile(name: "图像能力测试", configuration: configuration)
        try check(saved.imageCapability == .unknown, "new profiles cannot infer image capability from model names")
        let uncheckedConfiguration = try await service.modelConfiguration(profileID: saved.id)
        try check(!uncheckedConfiguration.imageInputEnabled, "unchecked profiles must not enable image input")
        let conversation = service.createTask(workspace: directory)
        await service.send(taskID: conversation, text: "before-image-check", profileID: saved.id)
        let checked = try await service.checkModelProfile(id: saved.id)
        try check(checked.textCapability == .verified && checked.toolCapability == .verified, "existing text and tool checks must remain verified")
        try check(checked.imageCapability == .verified, "image capability must be verified from an actual pixel challenge, not the model name: \(checked.checkDetails ?? "")")
        let verifiedConfiguration = try await service.modelConfiguration(profileID: saved.id)
        try check(verifiedConfiguration.imageInputEnabled, "verified capability must enable the configured runtime")
        await service.send(taskID: conversation, text: "after-image-check", profileID: saved.id)
        try check(service.tasks.first { $0.id == conversation }?.messages.last?.text == "测试回复：after-image-check", "checking image capability must not prevent continuing an existing conversation")
        await service.send(taskID: conversation, text: "after-image-disabled", configuration: uncheckedConfiguration)
        try check(service.tasks.first { $0.id == conversation }?.messages.last?.text == "测试回复：after-image-disabled", "disabling image input must preserve ordinary conversation continuity")
        let restored = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory, keychainService: keychainService, allowKeychainUI: false)
        defer { restored.shutdown() }
        try check(restored.modelProfiles.first?.imageCapability == .verified, "verified image capability must survive restart")
        let renamed = try await service.saveModelProfile(id: saved.id, name: "重命名图像服务", configuration: configuration)
        try check(renamed.imageCapability == .verified, "renaming the same model must retain its capability check")
        for model in ["fixture-wrong-image", "fixture-reject-image"] {
            configuration.model = model
            let profile = try await service.saveModelProfile(name: model, configuration: configuration)
            let result = try await service.checkModelProfile(id: profile.id)
            try check(result.textCapability == .verified && result.toolCapability == .verified, "image failure must preserve verified text and tool capability")
            try check(result.imageCapability == .unknown, "rejected or inaccurate image input must remain unverified")
            let rejectedConfiguration = try await service.modelConfiguration(profileID: profile.id)
            try check(!rejectedConfiguration.imageInputEnabled && result.checkDetails?.contains("重新检查") == true, "image failure must disable image input and offer recovery guidance")
        }
        let changed = try await service.saveModelProfile(id: saved.id, name: "已更换模型", configuration: configuration)
        try check(changed.imageCapability == .unknown && changed.checkedAt == nil, "changing a verified model must invalidate its previous image check")
        print("PASS: verified image capability through TaskService → ACP → actual image request")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskVisionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
