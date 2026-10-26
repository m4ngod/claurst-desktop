import Foundation
import Darwin
import CryptoKit

public struct SavedMemory: Identifiable, Codable {
    public let id: UUID
    public var content: String
    public let category: String
    public let scope: String
    public let workspaceKey: String?
    public let sourceTask: UUID
    public let sourceTurn: Int
    public let createdAt: Date
    public var updatedAt: Date
    public var manuallyEdited: Bool
    public var protectedTopic: String?
}

public enum MemoryClearScope: String, CaseIterable, Identifiable {
    case personal = "个人偏好", workspace = "当前工作区", all = "全部记忆"
    public var id: String { rawValue }
}

struct MemoryState: Codable {
    var version = 1
    var enabled = false
    var generation = UUID()
    var records: [SavedMemory] = []
    // Only positions, never deleted text. Old turns are never scanned or replayed.
    var processed: [String: Int] = [:]
}

struct MemoryCandidate: Decodable {
    let content: String
    let evidence: String
    let scope: String
    let category: String
}

/// Mutations reload under a file lock, so late extraction and another app instance
/// cannot resurrect deleted records or silently replace a user's correction.
final class MemoryStore {
    let file: URL
    init(directory: URL) { file = directory.appendingPathComponent("memories.json") }

    func load() throws -> MemoryState {
        guard FileManager.default.fileExists(atPath: file.path) else { return MemoryState() }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 2_097_153) ?? Data()
        guard data.count <= 2_097_152 else { throw SettingsFailure("记忆文件超过 2 MiB，原数据已保留。") }
        let state = try JSONDecoder().decode(MemoryState.self, from: data)
        guard state.version == 1 else { throw SettingsFailure("记忆格式不受支持，原数据已保留。") }
        return state
    }

    @discardableResult func change(_ edit: (inout MemoryState) throws -> Void) throws -> MemoryState {
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(directory.appendingPathComponent(".memory-lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw SettingsFailure("记忆存储无法锁定，请检查目录权限。") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw SettingsFailure("另一窗口正在更新记忆，请稍后重试。") }
        defer { flock(fd, LOCK_UN) }
        var state = try load()
        try edit(&state)
        let data = try JSONEncoder().encode(state)
        guard data.count <= 2_097_152 else { throw SettingsFailure("记忆存储达到容量上限，原数据已保留。") }
        let temporary = directory.appendingPathComponent(".memory-" + UUID().uuidString)
        let output = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard output >= 0 else { throw SettingsFailure("记忆无法保存，请检查磁盘空间和目录权限。") }
        let handle = FileHandle(fileDescriptor: output, closeOnDealloc: true)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: temporary) }
        try handle.write(contentsOf: data)
        try handle.synchronize()
        guard rename(temporary.path, file.path) == 0 else { throw SettingsFailure("记忆保存失败，原数据未更改。") }
        return state
    }

    func reserve(task: UUID, turn: Int, generation: UUID) throws -> Bool {
        var reserved = false
        try change { state in
            guard state.enabled, state.generation == generation,
                  turn > (state.processed[task.uuidString] ?? 0) else { return }
            state.processed[task.uuidString] = turn
            reserved = true
        }
        return reserved
    }

    func accept(_ candidates: [MemoryCandidate], input: String, observations: String, workspaceKey: String?, task: UUID, turn: Int, generation: UUID) throws -> (state: MemoryState, skippedConflicts: Bool) {
        var skipped = false
        let state = try change { state in
            guard state.enabled, state.generation == generation else { return }
            for candidate in candidates.prefix(8) {
                let text = candidate.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
                // Keep the user's exact words, not a model's invented paraphrase.
                guard !text.isEmpty, text.utf8.count <= 1024, input.contains(text) || observations.contains(text) else { continue }
                let personal = candidate.scope == "personal" && input.contains(text) && Self.isPersonalPreference(text, category: candidate.category)
                let key = personal ? nil : workspaceKey
                let observedFact = candidate.category == "fact" && !Self.isPersonalPreference(text, category: "style")
                guard personal || (key != nil && Self.isProjectFact(text) && (input.contains(text) || observedFact)),
                      !state.records.contains(where: { $0.workspaceKey == key && $0.content.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }),
                      state.records.count < 500 else { continue }
                let category = personal ? candidate.category : "fact"
                let topic = Self.conflictTopic(text, personal: personal)
                if state.records.contains(where: { $0.manuallyEdited && $0.workspaceKey == key && ($0.protectedTopic == topic || Self.conflictTopic($0.content, personal: $0.scope == "personal") == topic) }) {
                    skipped = true; continue
                }
                state.records.append(SavedMemory(id: UUID(), content: text, category: category, scope: personal ? "personal" : "project", workspaceKey: key,
                    sourceTask: task, sourceTurn: turn, createdAt: Date(), updatedAt: Date(), manuallyEdited: false, protectedTopic: topic))
            }
        }
        return (state, skipped)
    }

    static func isPersonalPreference(_ text: String, category: String) -> Bool {
        ["language", "style", "workflow"].contains(category) && preferenceTopic(text) != nil
    }

    // Only explicitly general response preferences may cross workspaces. An
    // unfamiliar phrase stays local even when a model labels it personal.
    private static func preferenceTopic(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let patterns = [
            ("detail", #"^(我偏好|我喜欢|我希望|我习惯|请始终|以后)(简洁|简短|详细|详尽)(回答|回复|说明)[。.!！]?$"#),
            ("detail", #"^i prefer (concise|brief|short|detailed|thorough) (answers|responses|replies)[.!]?$"#),
            ("language", #"^(我偏好|我喜欢|我希望|我习惯|请始终|以后)(用|使用)?(中文|英文|英语|简体中文|繁体中文|日语|日文|法语|西班牙语)(回答|回复)[。.!！]?$"#),
            ("language", #"^(i prefer (answers|responses|replies) in|please always (answer|respond) in) (chinese|english|japanese|french|spanish)[.!]?$"#),
            ("format", #"^(我偏好|我喜欢|我希望|请始终|以后)(先给结论再解释|先说结论再解释|用列表回答|分点回答)[。.!！]?$"#),
        ]
        return patterns.first { value.range(of: $0.1, options: .regularExpression) != nil }?.0
    }

    static func conflictTopic(_ text: String, personal: Bool) -> String {
        if personal, let topic = preferenceTopic(text) { return "personal:" + topic }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let separator = normalized.range(of: #"为|是|[:：]| is | uses? | equals? "#, options: .regularExpression) {
            let subject = normalized[..<separator.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !subject.isEmpty && subject.utf8.count <= 160 { return "subject:" + subject }
        }
        return "statement:" + SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func containsCredential(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["api_key", "apikey", "api key", "password", "secret", "token", "密钥", "密码", "凭据", "口令", "sk-", "[已隐藏]",
                "authorization", "bearer ", "basic ", "cookie", "credential", "access_key", "accesskey", "private key", "ssh-rsa", "ssh-ed25519"].contains(where: lower.contains)
            || lower.range(of: #"\b(akia|asia)[a-z0-9]{16}\b"#, options: .regularExpression) != nil
    }

    static func isProjectFact(_ text: String) -> Bool {
        let lower = text.lowercased()
        return !containsCredential(text) && !["忽略", "执行", "删除", "上传", "授权", "权限", "ignore", "execute", "system prompt", "assistant:", "user:", "请", "必须"].contains(where: lower.contains)
    }

    static func extractionInput(_ text: String, secret: String) -> String {
        let redacted = secret.isEmpty ? text : text.replacingOccurrences(of: secret, with: "[已隐藏]")
        // Remove whole PEM blocks, including multiline payloads without labels.
        let withoutKeys = redacted.replacingOccurrences(of: #"(?s)-----BEGIN [^-]*PRIVATE KEY-----.*?(-----END [^-]*PRIVATE KEY-----|$)"#, with: "[已隐藏]", options: .regularExpression)
        return String(withoutKeys.split(separator: "\n", omittingEmptySubsequences: false).filter { !containsCredential(String($0)) }.joined(separator: "\n").prefix(12_000))
    }
}
