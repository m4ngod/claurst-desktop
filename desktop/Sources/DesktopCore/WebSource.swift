import Foundation

/// A successful tool read, not a search snippet or a model-supplied link.
public struct WebSource: Identifiable, Codable {
    public let id: String
    public let requestedURL: URL
    public let url: URL
    public private(set) var title: String?
    public let retrievedAt: String
    public let firstLine: Int
    public let lastLine: Int
    public let totalLines: Int
    public private(set) var excerpt: String
    public let contentType: String
    public let responseSHA256: String

    private enum CodingKeys: String, CodingKey {
        case id, url, title, excerpt
        case requestedURL = "requested_url", retrievedAt = "retrieved_at"
        case firstLine = "first_line", lastLine = "last_line", totalLines = "total_lines"
        case contentType = "content_type", responseSHA256 = "response_sha256"
    }
    public var displayTitle: String { title ?? "网页未提供标题" }
    public var reference: String { "[网页:\(id)]" }
    public var locationLabel: String { "正文第 \(firstLine)–\(lastLine) 行 / 共 \(totalLines) 行" }
    func redacting(secret: String) throws -> WebSource {
        guard !secret.isEmpty else { return self }
        // Preserve verifiable identifiers and URLs; inventing a redacted URL
        // would make the citation point somewhere that was never read.
        let identifiers = [id, requestedURL.absoluteString, url.absoluteString, retrievedAt, contentType, responseSHA256]
        guard !identifiers.contains(where: { $0.contains(secret) || ($0.removingPercentEncoding?.contains(secret) ?? false) }) else {
            throw SettingsFailure("网页来源标识包含模型凭据，未保存此来源。")
        }
        var result = self
        result.title = title?.replacingOccurrences(of: secret, with: "[密钥已隐藏]")
        result.excerpt = excerpt.replacingOccurrences(of: secret, with: "[密钥已隐藏]")
        return result
    }
    public var isValid: Bool {
        UUID(uuidString: id) != nil && Self.isWebURL(url) && Self.isWebURL(requestedURL)
            && ISO8601DateFormatter().date(from: retrievedAt) != nil
            && firstLine > 0 && lastLine >= firstLine && totalLines >= lastLine
            && !excerpt.isEmpty && excerpt.utf8.count <= 50 * 1024
            && ["text/html", "application/xhtml+xml", "text/plain"].contains(contentType)
            && responseSHA256.count == 64 && responseSHA256.allSatisfy { $0.isHexDigit }
    }
    private static func isWebURL(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil && url.user == nil && url.password == nil
    }
}
