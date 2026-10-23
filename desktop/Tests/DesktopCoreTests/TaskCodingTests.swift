import Foundation
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskCodingTests {
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
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/search-project"), to: workspace)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let stateFile = workspace.appendingPathComponent("app/state.py")
        let userNote = "# 用户保留的备注：" + UUID().uuidString + "\n"
        let original = userNote + (try String(contentsOf: stateFile))
        try original.write(to: stateFile, atomically: true, encoding: .utf8)
        let checkFile = workspace.appendingPathComponent("checks/test_state.py")
        let originalChecks = try Data(contentsOf: checkFile)
        let baseline = service.createTask(workspace: workspace)
        await service.send(taskID: baseline,
            text: "command-fixture:{\"command\":\"/Library/Developer/CommandLineTools/usr/bin/python3 -B -m unittest discover -s checks -v\"}", configuration: config)
        let baselineResult = service.tasks.first(where: { $0.id == baseline })!
        try check(baselineResult.status == .failed, "the sample must reproduce the search bug")
        try check(baselineResult.tools.last?.output.contains("search query lost after status change") == true,
            "baseline must fail on the actual bug, not missing dependencies: \(baselineResult.tools.last?.output ?? "")")
        let repair = service.createTask(workspace: workspace)
        await service.send(taskID: repair, text: "coding-fixture:fix-search", configuration: config)
        let result = service.tasks.first(where: { $0.id == repair })!
        try check(result.status == .completed, "real coding flow must finish: \(result.error ?? "") \(result.tools.map(\.output))")
        let changed = try String(contentsOf: stateFile)
        try check(changed.contains("return replace(self, status=status)"), "fix must be present on disk")
        try check(changed.hasPrefix(userNote), "preserve the user's edit read from the actual file")
        try check(try Data(contentsOf: checkFile) == originalChecks, "do not rewrite checks to claim a pass")
        try check(result.changes.count == 1 && result.changes[0].before == original && result.changes[0].after == changed, "visible diff must match actual before/after files")
        try check(result.tools.last?.output.contains("Ran 3 tests") == true && result.tools.last?.output.contains("退出码：0") == true, "show the actual successful project checks")
        try check(result.changes[0].reason == "切换状态时沿用当前搜索词和排序，只替换状态字段。", "show the model's change explanation beside the actual diff")
        try check(result.tools.last?.check?.name == "搜索条件回归" && result.tools.last?.check?.state == .passed, "only a real successful command produces a passed check record")
        let skip = service.createTask(workspace: workspace)
        await service.send(taskID: skip, text: "command-fixture:{\"command\":\"printf forbidden > skipped.txt\",\"check_name\":\"在线集成检查\",\"skip_reason\":\"该检查需要网络，当前工作区禁止联网。\"}", configuration: config)
        let skipped = service.tasks.first(where: { $0.id == skip })!
        try check(skipped.tools.last?.check?.state == .skipped, "a deliberately skipped check is distinct from a failed or unrun check")
        try check(skipped.tools.last?.output.contains("需要网络") == true && !FileManager.default.fileExists(atPath: workspace.appendingPathComponent("skipped.txt").path), "skipping preserves its reason and never executes the command")
        let unrun = service.createTask(workspace: workspace)
        await service.send(taskID: unrun, text: "command-fixture:{\"command\":\"printf forbidden > unrun.txt\",\"check_name\":\"需要额外依赖的检查\",\"read_paths\":[\"relative-not-authorized\"]}", configuration: config)
        let refused = service.tasks.first(where: { $0.id == unrun })!
        try check(refused.status == .failed && refused.tools.last?.check?.state == .notRun, "preflight refusal is unrun, not an executed failing check")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("unrun.txt").path), "unrun check never reaches its command")
        let invalid = service.createTask(workspace: workspace)
        await service.send(taskID: invalid, text: "command-fixture:{\"command\":\"printf forbidden > invalid.txt\",\"check_name\":\"参数错误的检查\",\"timeout\":\"1000\"}", configuration: config)
        let rejected = service.tasks.first(where: { $0.id == invalid })!
        try check(rejected.status == .failed && rejected.tools.last?.check?.state == .notRun, "invalid check arguments are explicitly unrun")
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("invalid.txt").path), "invalid arguments do not execute a command")
        let noCheck = service.createTask(workspace: workspace)
        await service.send(taskID: noCheck, text: "没有执行检查，却声称已验证完成", configuration: config)
        try check(service.tasks.first(where: { $0.id == noCheck })!.tools.allSatisfy { $0.check == nil }, "model prose cannot manufacture a check receipt")
        let brokenWorkspace = directory.appendingPathComponent("broken-workspace")
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/search-project"), to: brokenWorkspace)
        let brokenFile = brokenWorkspace.appendingPathComponent("app/state.py")
        try original.write(to: brokenFile, atomically: true, encoding: .utf8)
        let broken = service.createTask(workspace: brokenWorkspace)
        await service.send(taskID: broken, text: "coding-fixture:broken-search", configuration: config)
        let failed = service.tasks.first(where: { $0.id == broken })!
        try check(failed.messages.last?.text.contains("已验证完成") == true, "fixture must actually make the unsupported success claim")
        try check(failed.status == .failed && failed.tools.last?.check?.state == .failed, "an unresolved bug stays failed regardless of model prose")
        try check(failed.changes.count == 1 && (try String(contentsOf: brokenFile)).contains("保留的未完成尝试"), "failed checks preserve actual work and its diff")
        await service.send(taskID: broken, text: "coding-fixture:fix-search", configuration: config)
        let continued = service.tasks.first(where: { $0.id == broken })!
        try check(continued.status == .completed && continued.tools.last?.check?.state == .passed, "continue from failed checks and verify the corrected source")
        try check(continued.tools.contains { $0.check?.state == .failed } && (try String(contentsOf: brokenFile)).hasPrefix(userNote), "history retains the previous failure and user's edits")
        // Launch the real runtime through a PID-recording script, then kill only
        // that owned process to exercise a genuine lost ACP connection.
        let runtime = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let pidFile = directory.appendingPathComponent("owned-runtime.pid")
        let launcher = directory.appendingPathComponent("launch-runtime.sh")
        func shellQuote(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
        let launchText = "#!/bin/sh\nprintf '%s' \"$$\" > " + shellQuote(pidFile.path) + "\nexec " + shellQuote(runtime.path) + "\n"
        try launchText.write(to: launcher, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
        let disconnected = TaskService(executable: launcher, storageDirectory: directory.appendingPathComponent("disconnected-settings"))
        defer { disconnected.shutdown() }
        let disconnectedID = disconnected.createTask(workspace: workspace)
        let running = Task { await disconnected.send(taskID: disconnectedID, text: "command-fixture:{\"command\":\"printf started > interrupted-start.txt; /bin/sleep 1\",\"check_name\":\"中断检查\"}", configuration: config) }
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: workspace.appendingPathComponent("interrupted-start.txt").path) && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try check(disconnected.tasks[0].tools.last?.check?.state == .running, "real check must have started before disconnect")
        let pid = Int32(try String(contentsOf: pidFile).trimmingCharacters(in: .whitespacesAndNewlines))!
        try check(pid > 1 && pid != getpid() && kill(pid, SIGKILL) == 0, "terminate only the owned runtime")
        await running.value
        try check(disconnected.tasks[0].tools.last?.check?.state == .unconfirmed, "lost check receipt must become persistently unconfirmed")
        await disconnected.send(taskID: disconnectedID, text: "断线后继续", configuration: config)
        try check(disconnected.tasks[0].tools.first?.check?.state == .unconfirmed, "continuing must not relabel an old check as running")
        service.shutdown()
        let reopened = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        let restored = reopened.tasks.first(where: { $0.id == broken })!
        try check(restored.tools.last?.check?.state == .passed && restored.changes.last?.reason == result.changes[0].reason, "reopening preserves check receipts and change explanations")
        print("PASS: coding through TaskService → ACP → actual source repair and project checks")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskCodingTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
