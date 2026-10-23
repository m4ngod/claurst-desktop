import Foundation
import CryptoKit

public struct LaTeXArtifact: Identifiable, Codable {
    public let id: String
    public let mainPath: String
    public let pdfPath: String
    public let logPath: String
    public let compiledAt: String
    public let pageCount: Int
    public let pdfSHA256: String
    public var warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case id, warnings
        case mainPath = "main_path", pdfPath = "pdf_path", logPath = "log_path"
        case compiledAt = "compiled_at", pageCount = "page_count", pdfSHA256 = "pdf_sha256"
    }
    public var mainFile: URL { URL(fileURLWithPath: mainPath) }
    public var pdfFile: URL { URL(fileURLWithPath: pdfPath) }
    public var logFile: URL { URL(fileURLWithPath: logPath) }
    public var reviewNotes: [String] { warnings ?? [] }

    public func isValid(in workspace: URL) -> Bool {
        let root = workspace.standardizedFileURL.path + "/"
        let paths = [mainPath, pdfPath, logPath]
        return UUID(uuidString: id) != nil && pageCount > 0
            && ISO8601DateFormatter().date(from: compiledAt) != nil
            && pdfSHA256.count == 64 && pdfSHA256.allSatisfy { $0.isHexDigit }
            && paths.allSatisfy { $0.hasPrefix("/") && URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(root) }
            && mainFile.pathExtension == "tex" && pdfFile.pathExtension == "pdf"
            && pdfFile.deletingLastPathComponent() == logFile.deletingLastPathComponent()
            && pdfFile.deletingLastPathComponent().lastPathComponent.hasPrefix("claurst-latex-")
            && reviewNotes.count <= 100
    }

    /// Preview and export the bytes that were actually compiled, not a later replacement.
    public func checkedPDFData(in workspace: URL) throws -> Data {
        guard isValid(in: workspace), pdfFile.resolvingSymlinksInPath().path.hasPrefix(workspace.resolvingSymlinksInPath().path + "/") else {
            throw SettingsFailure("成果位置不在原工作文件夹内，无法打开。")
        }
        let handle = try FileHandle(forReadingFrom: pdfFile)
        defer { try? handle.close() }
        let bytes = try handle.read(upToCount: 32 * 1024 * 1024 + 1) ?? Data()
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard bytes.count <= 32 * 1024 * 1024 && digest == pdfSHA256 else {
            throw SettingsFailure("PDF 在编译后已改变，无法作为这次成果预览或导出。请重新编译。")
        }
        return bytes
    }
}
