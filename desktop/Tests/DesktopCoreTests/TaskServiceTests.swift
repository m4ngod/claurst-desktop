import Foundation
import Combine
import Security
import LocalAuthentication
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskServiceTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output
        fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let portData = output.fileHandleForReading.availableData
        let port = String(data: portData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let settingsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let keychainService = "local.claurst.desktop.tests.\(UUID().uuidString)"
        defer { removeTestCredentials(keychainService); removeTestCredentials(keychainService + ".removal") }
        defer { try? FileManager.default.removeItem(at: settingsDirectory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: settingsDirectory, keychainService: keychainService, allowKeychainUI: false)
        defer { service.shutdown() }
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let duringSave = Task { @MainActor in service.createTask(workspace: workspace) }
        let saved = try await service.saveModelProfile(name: "本机测试服务", configuration: config)
        let taskVisibleWhenSaveReturns = service.tasks.first?.id
        let saveActionID = await duringSave.value
        try assertEqual(taskVisibleWhenSaveReturns, saveActionID)

        let ordinarySettings = try String(contentsOf: settingsDirectory.appendingPathComponent("models.json"))
        try assertEqual(ordinarySettings.contains("test-only"), false)
        let restored = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: settingsDirectory, keychainService: keychainService, allowKeychainUI: false)
        defer { restored.shutdown() }
        try assertEqual(restored.modelProfiles.map(\.id), [saved.id])
        // Loading a real Keychain item must yield the UI executor so another
        // user action can create a task even while credentials are being read.
        let responsiveAction = Task { @MainActor in restored.createTask(workspace: workspace) }
        let readback = try await restored.modelConfiguration(profileID: saved.id)
        let taskVisibleWhenCredentialsReturn = restored.tasks.first?.id
        let responsiveTaskID = await responsiveAction.value
        try assertEqual(taskVisibleWhenCredentialsReturn, responsiveTaskID)
        try assertEqual(readback, config)
        let cancelledStart = restored.createTask(workspace: workspace)
        let stopDuringCredentials = restored.$tasks.sink { tasks in
            if tasks.first(where: { $0.id == cancelledStart })?.status.rawValue == "正在读取模型凭据" {
                Task { @MainActor in restored.stop(taskID: cancelledStart) }
            }
        }
        var acceptedCancelledDraft = false
        await restored.send(taskID: cancelledStart,
            text: "write-fixture:{\"file_path\":\"cancelled-start.txt\",\"content\":\"must not execute\"}", profileID: saved.id) {
            acceptedCancelledDraft = true
        }
        stopDuringCredentials.cancel()
        try assertEqual(restored.tasks.first(where: { $0.id == cancelledStart })?.status, .stopped)
        try assertEqual(acceptedCancelledDraft, false)
        try assertEqual(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("cancelled-start.txt").path), false)
        let checked = try await restored.checkModelProfile(id: saved.id)
        try assertEqual(checked.textCapability, .verified)
        try assertEqual(checked.toolCapability, .verified)
        try assertEqual(checked.imageCapability, .verified)
        try assertEqual(checked.checkedAt != nil, true)
        let savedAgain = try await restored.saveModelProfile(id: saved.id, name: "本机服务改名", configuration: config)
        try assertEqual(savedAgain.toolCapability, .verified)
        try assertEqual(savedAgain.checkedAt, checked.checkedAt)
        let restoredTask = restored.createTask(workspace: workspace)
        await restored.send(taskID: restoredTask, text: "restored", profileID: saved.id)
        try assertEqual(restored.tasks.first?.messages.last?.text, "测试回复：restored")
        let first = service.createTask(workspace: workspace)
        await service.send(taskID: first, text: "first", configuration: config)
        if let error = service.tasks.first(where: { $0.id == first })?.error { FileHandle.standardError.write(Data((error + "\n").utf8)) }
        try assertEqual(service.tasks.first(where: { $0.id == first })?.status, .completed)
        try assertEqual(service.tasks.first(where: { $0.id == first })?.messages.last?.text, "测试回复：first")
        let second = service.createTask(workspace: workspace)
        await service.send(taskID: second, text: "second", configuration: config)
        try assertEqual(service.tasks.first(where: { $0.id == second })?.messages.last?.text, "测试回复：second")
        try assertEqual(service.tasks.first(where: { $0.id == first })?.messages.last?.text, "测试回复：first")
        let split = service.createTask(workspace: workspace)
        var exposedPrefix = false
        let observation = service.$tasks.sink { tasks in
            if tasks.first(where: { $0.id == split })?.messages.last?.text.contains("test-") == true { exposedPrefix = true }
        }
        await service.send(taskID: split, text: "simulate-split-secret", configuration: config)
        observation.cancel()
        try assertEqual(exposedPrefix, false)
        try assertEqual(service.tasks.first(where: { $0.id == split })?.messages.last?.text, "[密钥已隐藏]")
        let changed = ModelConfiguration(endpoint: "http://127.0.0.1:1/v1", model: "another-model", apiKey: "other-key", isTest: true)
        var rejectedDraft = "must-not-leak-to-old-service"
        await service.send(taskID: first, text: rejectedDraft, configuration: changed) { rejectedDraft = "" }
        try assertEqual(rejectedDraft, "must-not-leak-to-old-service")
        try assertEqual(service.tasks.first(where: { $0.id == first })?.status, .failed)
        try assertEqual(service.tasks.first(where: { $0.id == first })?.error?.contains("新建任务"), true)
        try assertEqual(service.tasks.first(where: { $0.id == first })?.messages.last?.text, "测试回复：first")
        let failed = service.createTask(workspace: workspace)
        await service.send(taskID: failed, text: "simulate-auth-error", configuration: config)
        try assertEqual(service.tasks.first(where: { $0.id == failed })?.status, .failed)
        let error = service.tasks.first(where: { $0.id == failed })?.error ?? ""
        try assertEqual(error.contains("test-only"), false)
        try assertEqual(error.isEmpty, false)
        try assertEqual(service.tasks.first(where: { $0.id == second })?.status, .completed)
        let sample = workspace.appendingPathComponent("notes.md")
        try "# 样本\n项目预算为 73 元。\n".write(to: sample, atomically: true, encoding: .utf8)
        let reading = service.createTask(workspace: workspace)
        await service.send(taskID: reading, text: "read-fixture:notes.md", configuration: config)
        let readTask = service.tasks.first(where: { $0.id == reading })!
        try assertEqual(readTask.status, .completed)
        try assertEqual(readTask.messages.last?.text.contains("2\t项目预算为 73 元。"), true)
        try assertEqual(readTask.sources.first?.file.resolvingSymlinksInPath(), sample.resolvingSymlinksInPath())
        try assertEqual(readTask.sources.first?.firstLine, 1)
        try assertEqual(readTask.sources.first?.lastLine, 2)
        try assertEqual(readTask.sources.first?.excerpt.contains("项目预算为 73 元。"), true)
        let outside = settingsDirectory.appendingPathComponent("private.txt")
        try "OUTSIDE-PRIVATE-DATA".write(to: outside, atomically: true, encoding: .utf8)
        let restricted = service.createTask(workspace: workspace)
        let pendingRead = Task { await service.send(taskID: restricted, text: "read-fixture:" + outside.path, configuration: config) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks.first(where: { $0.id == restricted })?.permissions.isEmpty != false && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let question = service.tasks.first(where: { $0.id == restricted })?.permissions.first
        try assertEqual(question != nil, true)
        try assertEqual(question?.description.contains("private.txt"), true)
        service.answerPermission(taskID: restricted, requestID: question!.id, allow: false)
        await pendingRead.value
        let deniedTask = service.tasks.first(where: { $0.id == restricted })!
        try assertEqual(deniedTask.sources.isEmpty, true)
        try assertEqual(deniedTask.messages.last?.text.contains("OUTSIDE-PRIVATE-DATA"), false)
        try assertEqual(deniedTask.tools.last?.status, "失败")
        let streamedRead = service.createTask(workspace: workspace)
        await service.send(taskID: streamedRead, text: "read-stream-fixture:notes.md", configuration: config)
        let streamedTask = service.tasks.first(where: { $0.id == streamedRead })!
        try assertEqual(streamedTask.sources.count, 1)
        try assertEqual(streamedTask.tools.count, 1)
        try assertEqual(streamedTask.tools.first?.status, "完成")
        let allowed = service.createTask(workspace: workspace)
        let allowedRead = Task { await service.send(taskID: allowed, text: "read-fixture:" + outside.path, configuration: config) }
        let approval = try await waitForPermission(service, taskID: allowed)
        service.answerPermission(taskID: allowed, requestID: approval.id, allow: true)
        try await waitForFinish(service, taskID: allowed)
        await allowedRead.value
        try assertEqual(service.tasks.first(where: { $0.id == allowed })?.sources.last?.excerpt.contains("OUTSIDE-PRIVATE-DATA"), true)
        let secondAttempt = Task { await service.send(taskID: allowed, text: "read-fixture:" + outside.path, configuration: config) }
        let secondApproval = try await waitForPermission(service, taskID: allowed)
        service.answerPermission(taskID: allowed, requestID: secondApproval.id, allow: false)
        await secondAttempt.value
        try assertEqual(service.tasks.first(where: { $0.id == allowed })?.sources.count, 1)
        let outsideLink = workspace.appendingPathComponent("outside-link.txt")
        try FileManager.default.createSymbolicLink(at: outsideLink, withDestinationURL: outside)
        for path in ["../" + settingsDirectory.lastPathComponent + "/private.txt", "outside-link.txt"] {
            let escaped = service.createTask(workspace: workspace)
            let attempt = Task { await service.send(taskID: escaped, text: "read-fixture:" + path, configuration: config) }
            let question = try await waitForPermission(service, taskID: escaped)
            try assertEqual(question.description.contains("private.txt"), true)
            service.answerPermission(taskID: escaped, requestID: question.id, allow: false)
            await attempt.value
            let result = service.tasks.first(where: { $0.id == escaped })!
            try assertEqual(result.sources.isEmpty, true)
            try assertEqual(result.messages.last?.text.contains("OUTSIDE-PRIVATE-DATA"), false)
        }
        let insideLink = workspace.appendingPathComponent("inside-link.txt")
        try FileManager.default.createSymbolicLink(at: insideLink, withDestinationURL: sample)
        let linked = service.createTask(workspace: workspace)
        await service.send(taskID: linked, text: "read-fixture:inside-link.txt", configuration: config)
        try assertEqual(service.tasks.first(where: { $0.id == linked })?.sources.first?.file.resolvingSymlinksInPath(), sample.resolvingSymlinksInPath())
        let removalDirectory = settingsDirectory.appendingPathComponent("removal")
        let removal = TaskService(executable: URL(fileURLWithPath: "/unused"), storageDirectory: removalDirectory, keychainService: keychainService + ".removal", allowKeychainUI: false)
        let removable = try await removal.saveModelProfile(name: "删除失败样本", configuration: config)

        let metadata = removalDirectory.appendingPathComponent("models.json")
        let metadataBytes = try Data(contentsOf: metadata)
        try FileManager.default.removeItem(at: metadata)
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
        var removalFailed = false
        do { try await removal.removeModelProfile(id: removable.id) } catch { removalFailed = true }
        try FileManager.default.removeItem(at: metadata)
        try metadataBytes.write(to: metadata)
        try assertEqual(removalFailed, true)
        try assertEqual(try await removal.modelConfiguration(profileID: removable.id).apiKey, "test-only")
        let duringRemoval = Task { @MainActor in removal.createTask(workspace: workspace) }
        try await removal.removeModelProfile(id: removable.id)
        let taskVisibleWhenRemovalReturns = removal.tasks.first?.id
        let removalActionID = await duringRemoval.value
        try assertEqual(taskVisibleWhenRemovalReturns, removalActionID)
        try assertEqual(removal.modelProfiles.isEmpty, true)
        let writing = service.createTask(workspace: workspace)
        await service.send(taskID: writing, text: "write-fixture:{\"file_path\":\"created.md\",\"content\":\"# 新建文件\\n预算：73 元\\n\"}", configuration: config)
        let created = workspace.appendingPathComponent("created.md")
        try assertEqual(FileManager.default.fileExists(atPath: created.path), true)
        try assertEqual(try String(contentsOf: created), "# 新建文件\n预算：73 元\n")
        await service.send(taskID: writing, text: "read-fixture:created.md", configuration: config)
        await service.send(taskID: writing, text: "write-fixture:{\"file_path\":\"created.md\",\"content\":\"# 新建文件\\n预算：80 元\\n\"}", configuration: config)
        try assertEqual(try String(contentsOf: created), "# 新建文件\n预算：80 元\n")
        let changes = service.tasks.first(where: { $0.id == writing })!.changes
        try assertEqual(changes.count, 2)
        try assertEqual(changes.first?.before, nil)
        try assertEqual(changes.last?.before, "# 新建文件\n预算：73 元\n")
        try assertEqual(changes.last?.after, "# 新建文件\n预算：80 元\n")
        try assertEqual(changes.last?.diff.contains("-预算：73 元"), true)
        try assertEqual(changes.last?.diff.contains("+预算：80 元"), true)
        try assertEqual(FileManager.default.fileExists(atPath: changes.last!.record.path), true)
        let conflicting = service.createTask(workspace: workspace)
        await service.send(taskID: conflicting, text: "read-fixture:created.md", configuration: config)
        try "# 用户外部编辑\n预算：90 元\n".write(to: created, atomically: true, encoding: .utf8)
        await service.send(taskID: conflicting, text: "write-fixture:{\"file_path\":\"created.md\",\"content\":\"预算：100 元\\n\"}", configuration: config)
        try assertEqual(try String(contentsOf: created), "# 用户外部编辑\n预算：90 元\n")
        try assertEqual(service.tasks.first(where: { $0.id == conflicting })?.tools.last?.status, "失败")
        try assertEqual(service.tasks.first(where: { $0.id == conflicting })?.changes.isEmpty, true)
        try assertEqual(service.tasks.first(where: { $0.id == conflicting })?.status, .failed)
        let empty = workspace.appendingPathComponent("empty.md")
        try "".write(to: empty, atomically: true, encoding: .utf8)
        let emptyTask = service.createTask(workspace: workspace)
        await service.send(taskID: emptyTask, text: "read-fixture:empty.md", configuration: config)
        await service.send(taskID: emptyTask, text: "write-fixture:{\"file_path\":\"empty.md\",\"content\":\"补充内容\\n\"}", configuration: config)
        try assertEqual(try String(contentsOf: empty), "补充内容\n")
        try assertEqual(service.tasks.first(where: { $0.id == emptyTask })?.changes.last?.before, "")
        let outsideDirectoryLink = workspace.appendingPathComponent("outside-directory")
        try FileManager.default.createSymbolicLink(at: outsideDirectoryLink, withDestinationURL: settingsDirectory)
        for path in ["../" + settingsDirectory.lastPathComponent + "/write-denied.md", "outside-directory/write-denied.md", "outside-link.txt"] {
            let boundary = service.createTask(workspace: workspace)
            let arguments = String(data: try JSONSerialization.data(withJSONObject: ["file_path": path, "content": "不得写入"]), encoding: .utf8)!
            let attempted = Task { await service.send(taskID: boundary, text: "write-fixture:" + arguments, configuration: config) }
            let approval = try await waitForPermission(service, taskID: boundary)
            service.answerPermission(taskID: boundary, requestID: approval.id, allow: false)
            await attempted.value
            try assertEqual(service.tasks.first(where: { $0.id == boundary })?.changes.isEmpty, true)
            try assertEqual(service.tasks.first(where: { $0.id == boundary })?.status, .failed)
            try assertEqual(FileManager.default.fileExists(atPath: settingsDirectory.appendingPathComponent("write-denied.md").path), false)
            try assertEqual(try String(contentsOf: outside), "OUTSIDE-PRIVATE-DATA")
        }
        let backupFailure = service.createTask(workspace: workspace)
        await service.send(taskID: backupFailure, text: "read-fixture:created.md", configuration: config)
        let blockedBackup = settingsDirectory.appendingPathComponent("runtime/" + backupFailure.uuidString + "/changes")
        try "模拟无法创建备份目录".write(to: blockedBackup, atomically: true, encoding: .utf8)
        await service.send(taskID: backupFailure, text: "write-fixture:{\"file_path\":\"created.md\",\"content\":\"不应覆盖\\n\"}", configuration: config)
        try assertEqual(try String(contentsOf: created), "# 用户外部编辑\n预算：90 元\n")
        try assertEqual(service.tasks.first(where: { $0.id == backupFailure })?.changes.isEmpty, true)
        try assertEqual(service.tasks.first(where: { $0.id == backupFailure })?.status, .failed)
        let deletionConflict = service.createTask(workspace: workspace)
        await service.send(taskID: deletionConflict, text: "read-fixture:empty.md", configuration: config)
        try FileManager.default.removeItem(at: empty)
        await service.send(taskID: deletionConflict, text: "write-fixture:{\"file_path\":\"empty.md\",\"content\":\"不应重新创建\\n\"}", configuration: config)
        try assertEqual(FileManager.default.fileExists(atPath: empty.path), false)
        try assertEqual(service.tasks.first(where: { $0.id == deletionConflict })?.changes.isEmpty, true)
        for atomicEditorSave in [false, true] {
            let concurrent = workspace.appendingPathComponent("concurrent.md")
            try "读取时的内容\n".write(to: concurrent, atomically: true, encoding: .utf8)
            let concurrentTask = service.createTask(workspace: workspace)
            await service.send(taskID: concurrentTask, text: "read-fixture:concurrent.md", configuration: config)
            // A real external editor saves on filesystem activity while the
            // assistant prepares a large replacement. Only model HTTP is fake.
            let descriptor = open(workspace.path, O_EVTONLY)
            try assertEqual(descriptor >= 0, true)
            let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: DispatchQueue(label: "external-editor", qos: .userInteractive))
            let saved = EditorSaveState()
            watcher.setEventHandler {
                watcher.cancel()
                do {
                    try "外部编辑必须保留\n".write(to: concurrent, atomically: atomicEditorSave, encoding: .utf8)
                    saved.markSaved()
                } catch { FileHandle.standardError.write(Data("External editor fixture failed: \(error)\n".utf8)) }
            }
            watcher.setCancelHandler { close(descriptor) }
            watcher.resume()
            let started = Date()
            await service.send(taskID: concurrentTask, text: "write-large-fixture:concurrent.md", configuration: config)
            try assertEqual(Date().timeIntervalSince(started) < 20, true)
            watcher.cancel()
            try assertEqual(saved.didSave(), true)
            try assertEqual(try String(contentsOf: concurrent) == "外部编辑必须保留\n", true)
            try assertEqual(service.tasks.first(where: { $0.id == concurrentTask })?.changes.isEmpty, true)
            try assertEqual(service.tasks.first(where: { $0.id == concurrentTask })?.tools.last?.status, "失败")
        }
        print("PASS: task service → Claurst ACP → model HTTP → streaming conversation")
    }
    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, line: Int = #line) throws {
        if actual != expected { throw NSError(domain: "TaskServiceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Line \(line): Expected \(expected), got \(actual)"]) }
    }
    @MainActor static func waitForPermission(_ service: TaskService, taskID: UUID) async throws -> PermissionQuestion {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let question = service.tasks.first(where: { $0.id == taskID })?.permissions.first { return question }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw NSError(domain: "TaskServiceTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected permission request"])
    }
    @MainActor static func waitForFinish(_ service: TaskService, taskID: UUID) async throws {
        let deadline = Date().addingTimeInterval(5)
        while service.tasks.first(where: { $0.id == taskID })?.status.isActive == true && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try assertEqual(service.tasks.first(where: { $0.id == taskID })?.status.isActive, false)
    }
}

// The real filesystem event callback and the task service run on different
// queues. This state only coordinates the external editor test fixture.
private final class EditorSaveState {
    private let lock = NSLock()
    private var saved = false
    func markSaved() { lock.lock(); defer { lock.unlock() }; saved = true }
    func didSave() -> Bool { lock.lock(); defer { lock.unlock() }; return saved }
}

private func removeTestCredentials(_ service: String) {
    let context = LAContext()
    context.interactionNotAllowed = true
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service, kSecUseAuthenticationContext as String: context]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
        FileHandle.standardError.write(Data("Test credential cleanup failed: \(status)\n".utf8))
    }
}
