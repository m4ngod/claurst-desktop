import Foundation
import Darwin

struct Personalization: Codable {
    var version = 1
    var customInstructions = ""
    var soul: String?
}

/// Independent from model credentials and task history; a failed save keeps the old value.
final class PersonalizationStore {
    private let file: URL
    init(directory: URL) { file = directory.appendingPathComponent("personalization.json") }

    func load() throws -> Personalization {
        guard FileManager.default.fileExists(atPath: file.path) else { return Personalization() }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 524_289) ?? Data()
        guard data.count <= 524_288 else { throw SettingsFailure("个性化文件过大，原数据已保留。") }
        let value = try JSONDecoder().decode(Personalization.self, from: data)
        guard value.version == 1 else { throw SettingsFailure("个性化格式不受支持，原文件已保留。") }
        return value
    }

    func change(_ edit: (inout Personalization) -> Void) throws -> Personalization {
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(directory.appendingPathComponent(".personalization-lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw SettingsFailure("个性化存储无法锁定。") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw SettingsFailure("另一窗口正在保存个性化，请稍后重试。") }
        defer { flock(fd, LOCK_UN) }
        var value = try load()
        edit(&value)
        try save(value)
        return value
    }

    private func save(_ value: Personalization) throws {
        try Self.validate(value.customInstructions)
        try Self.validate(value.soul ?? "")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let temporary = file.deletingLastPathComponent().appendingPathComponent(".personalization-" + UUID().uuidString)
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        try handle.write(contentsOf: JSONEncoder().encode(value))
        try handle.synchronize()
        guard rename(temporary.path, file.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    static func validate(_ text: String) throws {
        guard text.utf8.count <= 32_768, !text.contains("\0") else {
            throw SettingsFailure("请输入不超过 32 KiB 的 UTF-8 文本，不能包含空字符。")
        }
    }
}
