import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskOrganizeTests {
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
        let workspace = directory.appendingPathComponent("workspace").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("archive"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let settings = directory.appendingPathComponent("settings")
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let service = TaskService(executable: runtime, storageDirectory: settings)
        defer { service.shutdown() }
        let source = workspace.appendingPathComponent("sample.bin")
        let destination = workspace.appendingPathComponent("archive/renamed.bin")
        let original = Data([0, 255, 128, 42, 10])
        try original.write(to: source)
        let id = service.createTask(workspace: workspace)
        let run = Task { await service.send(taskID: id, text: "move-fixture:{\"file_path\":\"sample.bin\",\"destination\":\"archive/renamed.bin\"}", configuration: config) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks[0].status == .ready || service.tasks[0].status.isActive {
            try check(service.tasks[0].permissions.isEmpty, "workspace move must not ask for approval")
            try check(Date() < deadline, "move must finish")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        await run.value
        try check(service.tasks[0].status == .completed, "move must complete through the real tool")
        try check(!FileManager.default.fileExists(atPath: source.path), "move removes the original pathname")
        try check(try Data(contentsOf: destination) == original, "move preserves binary bytes")
        try check(service.tasks[0].changes.first?.summary == "移动文件", "move is visible in file changes")
        try check(service.tasks[0].changes.first?.diff.contains(source.path) == true, "change identifies the original path")
        service.shutdown()
        let reopened = TaskService(executable: runtime, storageDirectory: settings)
        defer { reopened.shutdown() }
        try check(reopened.tasks[0].changes.first?.summary == "移动文件", "move evidence survives reopening")
        await reopened.send(taskID: id, text: "delete-fixture:{\"file_path\":\"archive/renamed.bin\"}", configuration: config)
        try check(reopened.tasks[0].status == .completed, "delete must complete through the real tool")
        try check(!FileManager.default.fileExists(atPath: destination.path), "delete removes the selected file")
        try check(reopened.tasks[0].changes.last?.summary == "删除文件", "deletion is visible in file changes")
        reopened.shutdown()
        let recovery = TaskService(executable: runtime, storageDirectory: settings)
        defer { recovery.shutdown() }
        let deletion = recovery.tasks[0].changes.last!.id
        let restoredDeletion = await recovery.restoreChange(taskID: id, changeID: deletion)
        try check(restoredDeletion, "deleted binary can be restored after reopening without a model configuration")
        try check(try Data(contentsOf: destination) == original, "restore preserves deleted binary bytes")
        let restoredMove = await recovery.restoreChange(taskID: id, changeID: recovery.tasks[0].changes[0].id)
        try check(restoredMove, "moving can be reversed from the saved change")
        try check(try Data(contentsOf: source) == original && !FileManager.default.fileExists(atPath: destination.path), "reversing a move restores its original path and bytes")
        let budget = workspace.appendingPathComponent("budget.md")
        try "预算：73 元\n".write(to: budget, atomically: true, encoding: .utf8)
        await recovery.send(taskID: id, text: "read-fixture:budget.md", configuration: config)
        await recovery.send(taskID: id, text: "write-fixture:{\"file_path\":\"budget.md\",\"content\":\"预算：80 元\\n\"}", configuration: config)
        let rewrite = recovery.tasks[0].changes.last!.id
        let restoredWrite = await recovery.restoreChange(taskID: id, changeID: rewrite)
        try check(restoredWrite, "managed text overwrites can be restored")
        try check(try String(contentsOf: budget) == "预算：73 元\n", "overwrite recovery returns the prior text")
        await recovery.send(taskID: id, text: "read-fixture:budget.md", configuration: config)
        await recovery.send(taskID: id, text: "write-fixture:{\"file_path\":\"budget.md\",\"content\":\"预算：90 元\\n\"}", configuration: config)
        let conflictingWrite = recovery.tasks[0].changes.last!.id
        try "用户的新预算\n".write(to: budget, atomically: true, encoding: .utf8)
        let refusedWrite = await recovery.restoreChange(taskID: id, changeID: conflictingWrite)
        try check(!refusedWrite && (try String(contentsOf: budget)) == "用户的新预算\n", "recovery never overwrites a subsequent user edit")
        try check(recovery.tasks[0].changes.last?.restoreError?.contains("恢复材料") == true, "recovery failure provides preserved material and a reason")

        try Data("occupied".utf8).write(to: destination)
        await recovery.send(taskID: id, text: "move-fixture:{\"file_path\":\"sample.bin\",\"destination\":\"archive/renamed.bin\"}", configuration: config)
        try check(recovery.tasks[0].status == .failed && (try Data(contentsOf: source)) == original, "occupied destination refuses a move and preserves its source")
        try check(try String(contentsOf: destination) == "occupied", "move cannot overwrite an occupied destination")
        try FileManager.default.removeItem(at: destination)
        await recovery.send(taskID: id, text: "move-fixture:{\"file_path\":\"sample.bin\",\"destination\":\"archive/renamed.bin\"}", configuration: config)
        let secondMove = recovery.tasks[0].changes.last!.id
        try Data("new occupant".utf8).write(to: source)
        let refusedMove = await recovery.restoreChange(taskID: id, changeID: secondMove)
        try check(!refusedMove && (try String(contentsOf: source)) == "new occupant", "undo move refuses an occupied original path")
        try check(try Data(contentsOf: destination) == original, "failed move recovery leaves the moved file intact")
        try FileManager.default.removeItem(at: source)
        try Data("later bytes".utf8).write(to: destination)
        let editedMove = await recovery.restoreChange(taskID: id, changeID: secondMove)
        try check(!editedMove && (try String(contentsOf: destination)) == "later bytes", "undo move refuses files edited after the move")

        await recovery.send(taskID: id, text: "delete-fixture:{\"file_path\":\"archive/renamed.bin\"}", configuration: config)
        let secondDeletion = recovery.tasks[0].changes.last!.id
        try Data("replacement".utf8).write(to: destination)
        let refusedDeletion = await recovery.restoreChange(taskID: id, changeID: secondDeletion)
        try check(!refusedDeletion && (try String(contentsOf: destination)) == "replacement", "restore deletion refuses newly occupied paths")

        let outside = directory.appendingPathComponent("outside.bin").resolvingSymlinksInPath()
        try original.write(to: outside)
        let parameters = String(data: try JSONSerialization.data(withJSONObject: ["file_path": outside.path]), encoding: .utf8)!
        let denied = Task { await recovery.send(taskID: id, text: "delete-fixture:" + parameters, configuration: config) }
        try await wait { recovery.tasks[0].permissions.isEmpty == false }
        recovery.answerPermission(taskID: id, requestID: recovery.tasks[0].permissions[0].id, allow: false)
        await denied.value
        try check(try Data(contentsOf: outside) == original, "outside deletion denial preserves data")
        let allowed = Task { await recovery.send(taskID: id, text: "delete-fixture:" + parameters, configuration: config) }
        try await wait { recovery.tasks[0].permissions.isEmpty == false }
        recovery.answerPermission(taskID: id, requestID: recovery.tasks[0].permissions[0].id, allow: true)
        await allowed.value
        try check(!FileManager.default.fileExists(atPath: outside.path), "outside deletion executes after approval")
        let outsideChange = recovery.tasks[0].changes.last!.id
        let denyRestore = Task { await recovery.restoreChange(taskID: id, changeID: outsideChange) }
        try await wait { recovery.tasks[0].permissions.isEmpty == false }
        recovery.answerPermission(taskID: id, requestID: recovery.tasks[0].permissions[0].id, allow: false)
        let deniedRestore = await denyRestore.value
        try check(!deniedRestore && !FileManager.default.fileExists(atPath: outside.path), "outside recovery needs a fresh approval")
        let allowRestore = Task { await recovery.restoreChange(taskID: id, changeID: outsideChange) }
        try await wait { recovery.tasks[0].permissions.isEmpty == false }
        // Switching tasks while recovery is awaiting permission must not direct
        // its completion into the newly selected task's records.
        let newer = recovery.createTask(workspace: workspace)
        let recovering = recovery.tasks.first { $0.id == id }!
        recovery.answerPermission(taskID: id, requestID: recovering.permissions[0].id, allow: true)
        let allowedRestore = await allowRestore.value
        try check(allowedRestore && (try Data(contentsOf: outside)) == original, "outside recovery succeeds after approval")
        try check(recovery.tasks.first { $0.id == newer }?.changes.isEmpty == true, "recovery stays attached to its original task")
        recovery.shutdown()
        let final = TaskService(executable: runtime, storageDirectory: settings)
        defer { final.shutdown() }
        try check(final.tasks.first { $0.id == id }?.changes.first { $0.id == outsideChange }?.restoredAt != nil, "recovery result survives reopening")

        let large = workspace.appendingPathComponent("large.bin")
        FileManager.default.createFile(atPath: large.path, contents: nil)
        let handle = try FileHandle(forWritingTo: large)
        try handle.truncate(atOffset: 32 * 1024 * 1024 + 1); try handle.close()
        await final.send(taskID: newer, text: "delete-fixture:{\"file_path\":\"large.bin\"}", configuration: config)
        try check(final.tasks.first { $0.id == newer }?.status == .failed && FileManager.default.fileExists(atPath: large.path), "oversized deletion refuses without touching the file")
        await final.send(taskID: newer, text: "read-fixture:large.bin", configuration: config)
        await final.send(taskID: newer, text: "write-fixture:{\"file_path\":\"large.bin\",\"content\":\"small replacement\"}", configuration: config)
        try check(final.tasks.first { $0.id == newer }?.status == .failed, "oversized overwrite refuses because its before version exceeds the recovery limit")
        let size = try FileManager.default.attributesOfItem(atPath: large.path)[.size] as? NSNumber
        try check(size?.intValue == 32 * 1024 * 1024 + 1, "unsupported large file keeps its content")
        if !CommandLine.arguments.contains("--skip-large-request") {
            await final.send(taskID: newer, text: "write-oversized-fixture:oversized.txt", configuration: config)
            try check(final.tasks.first { $0.id == newer }?.status == .failed && !FileManager.default.fileExists(atPath: workspace.appendingPathComponent("oversized.txt").path), "oversized new writes refuse before changing the workspace")
        }
        let oldParent = workspace.appendingPathComponent("original-parent")
        let replacement = workspace.appendingPathComponent("replacement-parent")
        try FileManager.default.createDirectory(at: oldParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: true)
        try "before".write(to: oldParent.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        await final.send(taskID: newer, text: "read-fixture:original-parent/f.txt", configuration: config)
        await final.send(taskID: newer, text: "write-fixture:{\"file_path\":\"original-parent/f.txt\",\"content\":\"after\"}", configuration: config)
        let parentChange = final.tasks.first { $0.id == newer }!.changes.last!.id
        try FileManager.default.moveItem(at: oldParent, to: workspace.appendingPathComponent("saved-parent"))
        try "after".write(to: replacement.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: oldParent, withDestinationURL: replacement)
        let redirected = await final.restoreChange(taskID: newer, changeID: parentChange)
        try check(!redirected && (try String(contentsOf: replacement.appendingPathComponent("f.txt"))) == "after", "recovery refuses a parent redirected through a symlink")
        try FileManager.default.removeItem(at: oldParent)
        try FileManager.default.createDirectory(at: oldParent, withIntermediateDirectories: true)
        try "after".write(to: oldParent.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        let replaced = await final.restoreChange(taskID: newer, changeID: parentChange)
        try check(!replaced && (try String(contentsOf: oldParent.appendingPathComponent("f.txt"))) == "after", "recovery refuses a replaced directory even when content happens to match")
        print("PASS: file organization through TaskService → ACP → real files")
    }

    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskOrganizeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    @MainActor static func wait(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        try check(condition(), "permission request did not arrive")
    }
}
