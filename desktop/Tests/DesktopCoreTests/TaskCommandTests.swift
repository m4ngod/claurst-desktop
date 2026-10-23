import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskCommandTests {
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
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        try "[ \"$(cat value.txt)\" = 73 ] || exit 7\nprintf 'budget check passed\\n'\nprintf 'checked one value\\n' >&2\n".write(to: workspace.appendingPathComponent("check.sh"), atomically: true, encoding: .utf8)
        try "73\n".write(to: workspace.appendingPathComponent("value.txt"), atomically: true, encoding: .utf8)
        let id = service.createTask(workspace: workspace)
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"/bin/sh check.sh\"}", configuration: config)
        let result = service.tasks[0].tools.last?.output ?? ""
        try check(service.tasks[0].status == .completed, "existing project check must execute: \(result) \(service.tasks[0].error ?? "")")
        try check(result.contains("budget check passed") && result.contains("checked one value"), "actual stdout and stderr must be visible")
        try check(result.contains("退出码：0"), "successful check must expose its real exit status")
        try "80\n".write(to: workspace.appendingPathComponent("value.txt"), atomically: true, encoding: .utf8)
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"/bin/sh check.sh\"}", configuration: config)
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("退出码：7") == true, "nonzero check must stay failed with its actual exit code")
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"claurst_missing_dependency_08\"}", configuration: config)
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("退出码：127") == true, "missing dependency is not a passed check")
        let outside = directory.appendingPathComponent("outside.txt").resolvingSymlinksInPath()
        try "outside marker\n".write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("outside-link"), withDestinationURL: outside)
        for command in ["/bin/cat '\(outside.path)'", "/bin/cat outside-link", "/bin/sh -c 'cat outside-link'", "printf changed > outside-link"] {
            let input = String(data: try JSONSerialization.data(withJSONObject: ["command": command]), encoding: .utf8)!
            await service.send(taskID: id, text: "command-fixture:" + input, configuration: config)
            try check(service.tasks[0].status == .failed, "sandbox must refuse outside access: \(command)")
            try check(service.tasks[0].tools.last?.output.contains("outside marker") == false, "outside contents must not leak")
            try check(try String(contentsOf: outside) == "outside marker\n", "denied write preserves the external file")
        }
        let stopped = Task { await service.send(taskID: id, text: "command-fixture:{\"command\":\"printf stop-diagnostic; printf started > started.txt; /bin/sh -c 'sleep 1; printf late > late.txt' & wait\"}", configuration: config) }
        try await wait { FileManager.default.fileExists(atPath: workspace.appendingPathComponent("started.txt").path) }
        service.stop(taskID: id)
        await stopped.value
        try check(service.tasks[0].status == .stopped, "stop terminates a running command")
        try check(service.tasks[0].tools.last?.output.contains("标准输出：\nstop-diagnostic") == true, "user stop retains emitted command diagnostics")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("late.txt").path), "stopped subprocess cannot perform a delayed write")
        try "#include <unistd.h>\n#include <stdio.h>\nint main(void) { if (setpgid(0,getpgid(getppid())) != 0) { perror(\"setpgid\"); return 9; } FILE *f=fopen(\"moved-group.txt\",\"w\"); if (!f) return 8; fclose(f); puts(\"moved-process-group\"); fflush(stdout); sleep(4); return 0; }\n".write(to: workspace.appendingPathComponent("escape.c"), atomically: true, encoding: .utf8)
        let compiler = Process()
        compiler.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        compiler.arguments = [workspace.appendingPathComponent("escape.c").path, "-o", workspace.appendingPathComponent("escape-group").path]
        try compiler.run(); compiler.waitUntilExit()
        try check(compiler.terminationStatus == 0, "prepare actual process-group fixture")
        let escapeStart = Date()
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"exec ./escape-group\",\"timeout\":1500}", configuration: config)
        try check(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("moved-group.txt").path), "fixture must move its process group: \(service.tasks[0].tools.last?.output ?? "")")
        try check(Date().timeIntervalSince(escapeStart) < 3.5, "timeout must finish promptly even if its direct child moves to another process group")
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"printf timeout-diagnostic; printf stderr-diagnostic >&2; sleep 1; printf late > timeout.txt\",\"timeout\":100}", configuration: config)
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("超时") == true, "timeout must not report a passed check")
        try check(service.tasks[0].tools.last?.output.contains("标准输出：\ntimeout-diagnostic") == true && service.tasks[0].tools.last?.output.contains("标准错误：\nstderr-diagnostic") == true, "timeout preserves diagnostics emitted before termination")
        try await Task.sleep(nanoseconds: 1_200_000_000)
        try check(!FileManager.default.fileExists(atPath: workspace.appendingPathComponent("timeout.txt").path), "timeout terminates pending writes")
        let expandedInput = String(data: try JSONSerialization.data(withJSONObject: ["command": "cat outside-link", "read_paths": [outside.path]] as [String: Any]), encoding: .utf8)!
        for allow in [false, true] {
            let expanded = Task { await service.send(taskID: id, text: "command-fixture:" + expandedInput, configuration: config) }
            try await wait { !service.tasks[0].permissions.isEmpty }
            let permission = service.tasks[0].permissions[0]
            try check(permission.description.contains(outside.path) && permission.description.contains("只读"), "approval identifies the exact extra read scope")
            service.answerPermission(taskID: id, requestID: permission.id, allow: allow)
            await expanded.value
            try check(service.tasks[0].status == (allow ? .completed : .failed), "command honors the scope approval decision")
            try check(service.tasks[0].tools.last?.output.contains("outside marker") == allow, "only approved reads return outside content")
        }
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"cat outside-link\"}", configuration: config)
        try check(service.tasks[0].status == .failed, "scope approval lasts for one command only")
        let readOnlyWrite = String(data: try JSONSerialization.data(withJSONObject: ["command": "printf changed > outside-link", "read_paths": [outside.path]] as [String: Any]), encoding: .utf8)!
        let writeAttempt = Task { await service.send(taskID: id, text: "command-fixture:" + readOnlyWrite, configuration: config) }
        try await wait { !service.tasks[0].permissions.isEmpty }
        service.answerPermission(taskID: id, requestID: service.tasks[0].permissions[0].id, allow: true)
        await writeAttempt.value
        try check(service.tasks[0].status == .failed && (try String(contentsOf: outside)) == "outside marker\n", "extra read permission never grants write permission")
        let linkInput = String(data: try JSONSerialization.data(withJSONObject: ["command": "ln '\(outside.path)' imported-link && printf changed > imported-link", "read_paths": [outside.path]] as [String: Any]), encoding: .utf8)!
        let linkAttempt = Task { await service.send(taskID: id, text: "command-fixture:" + linkInput, configuration: config) }
        try await wait { !service.tasks[0].permissions.isEmpty }
        service.answerPermission(taskID: id, requestID: service.tasks[0].permissions[0].id, allow: true)
        await linkAttempt.value
        try check(try String(contentsOf: outside) == "outside marker\n", "read approval must not let a command create a writable outside alias")
        let replaced = Task { await service.send(taskID: id, text: "command-fixture:" + expandedInput, configuration: config) }
        try await wait { !service.tasks[0].permissions.isEmpty }
        try FileManager.default.moveItem(at: outside, to: directory.appendingPathComponent("original-outside.txt"))
        try "replacement marker\n".write(to: outside, atomically: true, encoding: .utf8)
        service.answerPermission(taskID: id, requestID: service.tasks[0].permissions[0].id, allow: true)
        await replaced.value
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("授权路径已更换") == true, "replacing a path during approval invalidates the request")
        try FileManager.default.removeItem(at: outside)
        try FileManager.default.moveItem(at: directory.appendingPathComponent("original-outside.txt"), to: outside)
        let permissionStop = Task { await service.send(taskID: id, text: "command-fixture:" + expandedInput, configuration: config) }
        try await wait { !service.tasks[0].permissions.isEmpty }
        service.stop(taskID: id)
        await permissionStop.value
        try check(service.tasks[0].status == .stopped, "stopping a scope request never launches the command")
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"/usr/bin/curl -sS --max-time 1 http://127.0.0.1:\(port)/\"}", configuration: config)
        try check(service.tasks[0].status == .failed, "commands cannot access even loopback network without network permission")
        let detachedCommand = "/usr/bin/perl -MPOSIX -e '$|=1; if (fork() == 0) { POSIX::setsid(); print qq(detached-ready\\n); open(my $f, q(<), q(outside-link)) or die qq(read denied:$!\\n); print <$f>; exit 0; } wait; exit($? >> 8)'"
        let detachedInput = String(data: try JSONSerialization.data(withJSONObject: ["command": detachedCommand]), encoding: .utf8)!
        await service.send(taskID: id, text: "command-fixture:" + detachedInput, configuration: config)
        try check(service.tasks[0].tools.last?.output.contains("detached-ready") == true, "the child really forked and created its own session")
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("outside marker") == false, "detaching cannot escape the inherited file sandbox")
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"/usr/bin/env > command-env.txt\"}", configuration: config)
        let environment = try String(contentsOf: workspace.appendingPathComponent("command-env.txt"))
        try check(!environment.contains("test-only") && !environment.contains("CLAURST_HOME"), "shell processes do not inherit model credentials or private runtime locations")
        try FileManager.default.linkItem(at: outside, to: workspace.appendingPathComponent("hard-link"))
        await service.send(taskID: id, text: "command-fixture:{\"command\":\"printf changed > hard-link\"}", configuration: config)
        try check(try String(contentsOf: outside) == "outside marker\n", "pre-existing hard links cannot mutate an outside alias")
        try check(service.tasks[0].status == .failed && service.tasks[0].tools.last?.output.contains("硬链接") == true, "unsupported hard-link workspaces are explicitly refused")
        print("PASS: workspace commands through TaskService → ACP → OS sandbox")
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskCommandTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    @MainActor static func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        try check(condition(), "expected task event did not arrive")
    }
}
