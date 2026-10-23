import Foundation
import Security
import LocalAuthentication
import Darwin

public enum CapabilityState: String, Codable {
    case verified = "已验证", unknown = "未知", unsupported = "不支持"
}
public struct ModelProfile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var endpoint: String
    public var model: String
    public var isTest: Bool
    var secretReference: String
    public var textCapability: CapabilityState = .unknown
    public var toolCapability: CapabilityState = .unknown
    public var imageCapability: CapabilityState = .unknown
    // Absence in older saved profiles means search has not been enabled.
    public var webSearchEnabled: Bool?
    public var checkedAt: Date?
    public var checkDetails: String?
}

struct SettingsFailure: LocalizedError {
    var message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

/// Only this module crosses the configuration/Keychain boundary.
/// The JSON file contains opaque credential references, never credential data.
final class ModelSettingsStore: Sendable {
    private static let credentialQueue = DispatchQueue(label: "claurst.keychain", qos: .userInitiated)
    private let directory: URL
    private let service: String
    private let allowInteraction: Bool
    private var file: URL { directory.appendingPathComponent("models.json") }

    init(directory: URL, service: String, allowInteraction: Bool) {
        self.directory = directory
        self.service = service
        self.allowInteraction = allowInteraction
    }
    func load() throws -> [ModelProfile] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        do { return try JSONDecoder().decode([ModelProfile].self, from: Data(contentsOf: file)) }
        catch { throw SettingsFailure("模型配置无法读取，请保留 models.json 并修复配置文件；原配置未被覆盖。") }
    }
    func save(_ profiles: [ModelProfile]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(profiles)
        let temporary = directory.appendingPathComponent(".models-" + UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try data.write(to: temporary, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        // No fallible operation follows the commit: callers can safely retain
        // or remove credentials based on whether this method threw.
        guard rename(temporary.path, file.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
    func createSecret(_ value: String) async throws -> String {
        try await credentialOperation { try self.createSecretBlocking(value) }
    }
    private func createSecretBlocking(_ value: String) throws -> String {
        let reference = UUID().uuidString
        var attributes = query(reference)
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrLabel as String] = "Claurst 桌面助手模型密钥"
        try check(SecItemAdd(attributes as CFDictionary, nil))
        return reference
    }
    private func credentialOperation<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        // Security's synchronous IPC can wait for a user indefinitely. A
        // dedicated queue keeps it off both the UI and cooperative executors.
        try await withCheckedThrowingContinuation { continuation in
            Self.credentialQueue.async { continuation.resume(with: Result(catching: operation)) }
        }
    }
    func readSecret(_ reference: String) async throws -> String {
        try await credentialOperation { try self.secret(reference) }
    }
    private func secret(_ reference: String) throws -> String {
        var attributes = query(reference)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        try check(SecItemCopyMatching(attributes as CFDictionary, &result))
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw SettingsFailure("钥匙串中的模型密钥无法读取，请在设置中重新保存。")
        }
        return value
    }
    func removeSecret(_ reference: String) async throws {
        try await credentialOperation { try self.removeSecretBlocking(reference) }
    }
    private func removeSecretBlocking(_ reference: String) throws {
        let status = SecItemDelete(query(reference) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    private func query(_ reference: String) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !allowInteraction
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
            kSecUseAuthenticationContext as String: context
        ]
    }
    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecItemNotFound {
            throw SettingsFailure("模型密钥不存在，请在模型设置重新输入并保存。")
        }
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed || status == errSecUserCanceled {
            throw SettingsFailure("钥匙串已锁定或访问未获允许。请解锁系统钥匙串后重试；密钥未转存到普通文件。")
        }
        throw SettingsFailure("系统钥匙串操作失败（\(status)），请检查钥匙串访问权限后重试。")
    }
}

func validateModelConfiguration(_ configuration: ModelConfiguration) throws {
    guard let components = URLComponents(string: configuration.endpoint), let host = components.host,
          !host.isEmpty, components.user == nil, components.password == nil,
          components.query == nil, components.fragment == nil,
          components.scheme == "https" || (components.scheme == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)) else {
        throw SettingsFailure("请填写不含凭据的 HTTPS 模型地址；本机服务可使用 HTTP。")
    }
    guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw SettingsFailure("请填写模型名称。")
    }
    guard !configuration.model.lowercased().contains("claude"), !configuration.model.lowercased().contains("anthropic"),
          !configuration.endpoint.lowercased().contains("anthropic") else {
        throw SettingsFailure("本应用不使用 Claude 或 Anthropic 服务，请选择非 Claude 模型。")
    }
}
