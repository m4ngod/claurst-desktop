import SwiftUI
import Security
#if SWIFT_PACKAGE
import DesktopCore
#endif

/// Launch each bundle independently through Launch Services. CLI child processes
/// can inherit a responsible application's identity and mask this regression.
@main struct TaskSigningTests: App {
    init() {
        // LAContext alone does not suppress legacy login-Keychain ACL prompts.
        // Disable interaction for this test process, never for the real app.
        precondition(SecKeychainSetUserInteractionAllowed(false) == errSecSuccess)
    }
    var body: some Scene { WindowGroup { SigningProbeView() } }
}

struct SigningProbeView: View {
    @State private var status = "准备验证测试凭据"
    @State private var running = false
    var body: some View {
        VStack(spacing: 20) {
            #if FIRST_BUILD
            Text("签名验证：首次构建")
            #else
            Text("签名验证：代码已改变的构建")
            #endif
            Text(status).textSelection(.enabled)
            Button("运行验证") { Task { await run() } }.disabled(running)
            Button("退出") { NSApplication.shared.terminate(nil) }
        }.padding(30).frame(width: 580, height: 200)
    }
    @MainActor private func run() async {
        running = true
        guard let root = Bundle.main.object(forInfoDictionaryKey: "ProbeDirectory") as? String,
              let name = Bundle.main.object(forInfoDictionaryKey: "ProbeName") as? String,
              let keychainService = Bundle.main.object(forInfoDictionaryKey: "ProbeService") as? String else {
            status = "FAIL: invalid fixture"; return
        }
        let directory = URL(fileURLWithPath: root)
        let service = TaskService(executable: directory.appendingPathComponent("unused-runtime"),
            storageDirectory: directory.appendingPathComponent("settings"), keychainService: keychainService, allowKeychainUI: false)
        defer { service.shutdown(); running = false }
        var report: String
        do {
            if name == "first" {
                _ = try await service.saveModelProfile(name: "Signing fixture", configuration: ModelConfiguration(endpoint: "http://127.0.0.1:1/v1", model: "signing-fixture", apiKey: "valueless-signing-test-only", isTest: true))
                report = "PASS: created disposable credential without UI"
            } else {
                guard let profile = service.modelProfiles.first else { throw SettingsFailure("Missing fixture") }
                let configuration = try await service.modelConfiguration(profileID: profile.id)
                guard configuration.apiKey == "valueless-signing-test-only" else { throw SettingsFailure("Unexpected fixture") }
                report = name == "changed-identity" ? "FAIL: changed identity unexpectedly read credential" : "PASS: changed code read existing credential without UI"
            }
        } catch {
            let denied = error.localizedDescription.contains("钥匙串已锁定或访问未获允许")
            report = name == "changed-identity" && denied ? "PASS: changed identity refused without UI" : "FAIL: \(error.localizedDescription)"
        }
        do { try report.write(to: directory.appendingPathComponent(name + ".result"), atomically: true, encoding: .utf8) }
        catch { report = "FAIL: could not save test verdict" }
        status = report
    }
}
