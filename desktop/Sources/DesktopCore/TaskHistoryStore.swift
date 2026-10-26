import Foundation
import Darwin

/// Each task is a separate atomic record, so one damaged task does not hide the others.
final class TaskHistoryStore {
    let directory: URL
    private var saved: [UUID: Data] = [:]
    private var leases: [UUID: Int32] = [:]
    private struct Record: Codable {
        let version: Int
        let task: DesktopTask
    }

    init(directory: URL) { self.directory = directory.appendingPathComponent("history", isDirectory: true) }
    deinit { releaseTasks() }

    /// A task belongs to one application instance until that instance closes it.
    /// The OS releases these locks even if the application is killed.
    func claim(_ id: UUID) throws {
        guard leases[id] == nil else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let descriptor = open(directory.appendingPathComponent(".lease-" + id.uuidString).path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw SettingsFailure("此任务正在另一个应用窗口中使用。请回到该窗口，或关闭它后重新载入历史；未启动新的执行。")
        }
        leases[id] = descriptor
    }

    func releaseTasks() {
        for descriptor in leases.values { close(descriptor) }
        leases.removeAll()
    }

    private func ownedElsewhere(_ id: UUID) -> Bool {
        guard leases[id] == nil else { return false }
        let descriptor = open(directory.appendingPathComponent(".lease-" + id.uuidString).path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return true }
        defer { close(descriptor) }
        return flock(descriptor, LOCK_EX | LOCK_NB) != 0
    }

    func load(preserving activeIDs: Set<UUID> = []) -> (tasks: [DesktopTask], warning: String?) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return ([], nil) }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            var tasks: [DesktopTask] = []
            var damaged = 0
            for file in files where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let record = try JSONDecoder().decode(Record.self, from: data)
                    guard record.version == 1, file.lastPathComponent == record.task.id.uuidString + ".json" else {
                        throw SettingsFailure("历史格式不受支持")
                    }
                    if !activeIDs.contains(record.task.id) { saved[record.task.id] = data }
                    var task = record.task
                    guard !task.isTemporary else { continue }
                    let anotherOwner = ownedElsewhere(task.id)
                    task.recoveryWarnings = []
                    let references = Set(task.sources.map(\.file) + task.changes.map(\.file)
                        + task.latexArtifacts.flatMap { [$0.mainFile, $0.pdfFile, $0.logFile] })
                    for file in references.sorted(by: { $0.path < $1.path }) where !FileManager.default.fileExists(atPath: file.path) {
                        task.recoveryWarnings.append("文件已缺失或无法访问：\(file.path)。读取记录与差异仍可查看；请恢复文件后重试，或让助手依据当前文件继续。")
                    }
                    if task.changes.contains(where: { !FileManager.default.fileExists(atPath: $0.record.path) }) {
                        task.recoveryWarnings.append("部分修改前版本记录已缺失，历史差异仍保留；依赖该记录的恢复不可用。")
                    }
                    if !anotherOwner && !task.permissions.isEmpty {
                        task.recoveryWarnings.append("上次尚未完成的越界授权已失效。后续访问会重新请求授权。")
                    }
                    task.requiresHistoryRecovery = !task.messages.isEmpty
                    if anotherOwner {
                        task.status = .elsewhere
                        task.controlNotice = "此任务仍在另一个应用窗口中，未被判定为中断。关闭该窗口后可重新载入历史并继续。"
                    } else if task.status.isActive {
                        task.status = .stopped
                        task.controlNotice = "上次执行已中断，未标记为完成。已完成的修改仍保留；发送要求后可基于历史继续。"
                    }
                    task.permissions.removeAll()
                    for index in task.questions.indices { task.questions[index].isPending = false }
                    for index in task.tools.indices where task.tools[index].status == "执行中" {
                        task.tools[index].status = anotherOwner ? "另一个窗口执行中" : "已中断，结果待核对"
                        if !anotherOwner && task.tools[index].check?.state == .running { task.tools[index].check?.state = .unconfirmed }
                    }
                    tasks.append(task)
                } catch { damaged += 1 }
            }
            return (tasks.sorted { $0.createdAt > $1.createdAt }, damaged == 0 ? nil : "有 \(damaged) 份任务历史损坏或格式不受支持，原文件已保留。可打开历史目录修复后重新载入；其他任务仍可使用。")
        } catch { return ([], "无法读取任务历史。请检查历史目录权限后重新载入；原文件未被覆盖。") }
    }

    func save(_ tasks: [DesktopTask]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let lock = open(directory.appendingPathComponent(".lock").path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard lock >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            throw SettingsFailure("另一个应用正在保存任务历史，请稍后重试。")
        }
        defer { flock(lock, LOCK_UN) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for task in tasks where !task.isTemporary && leases[task.id] != nil {
            let data = try encoder.encode(Record(version: 1, task: task))
            guard saved[task.id] != data else { continue }
            let destination = directory.appendingPathComponent(task.id.uuidString + ".json")
            let current = FileManager.default.fileExists(atPath: destination.path) ? try Data(contentsOf: destination) : nil
            guard current == saved[task.id] else {
                throw SettingsFailure("任务历史已被另一个应用修改或移除。请结束另一窗口的执行，再点「重新载入历史」后重试；未覆盖其记录。")
            }
            let temporary = directory.appendingPathComponent(".task-" + UUID().uuidString)
            let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            guard rename(temporary.path, destination.path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            saved[task.id] = data
        }
    }
}
