import Foundation
import PDFKit

struct Part: Codable {
    let index: Int
    let text: String
}
struct ParsedDocument: Codable {
    var parts: [Part] = []
    var total = 0
    var error: String?
    var image: RenderedImage?
}
struct ParseFailure: Error { let message: String }

@main struct DocumentParser {
    static func main() {
        let result: ParsedDocument
        do {
            guard CommandLine.arguments.count == 4,
                  let first = Int(CommandLine.arguments[2]), first > 0,
                  let limit = Int(CommandLine.arguments[3]), (1...20).contains(limit) else {
                throw ParseFailure(message: "文档起始位置或读取范围无效")
            }
            let bytes = try FileHandle.standardInput.read(upToCount: 32 * 1024 * 1024 + 1) ?? Data()
            guard bytes.count <= 32 * 1024 * 1024 else { throw ParseFailure(message: "文档超过 32 MiB，未解析") }
            switch CommandLine.arguments[1] {
            case "pdf": result = try readPDF(bytes, first: first, limit: limit)
            case "docx": result = try readWord(bytes, first: first, limit: limit)
            case "ocr-image": result = try recognizeImage(bytes, first: first, limit: limit)
            case "ocr-pdf": result = try recognizePDF(bytes, first: first, limit: limit)
            case "view-image": result = try renderImage(bytes, first: first, limit: limit)
            case "view-pdf": result = try renderPDFPage(bytes, first: first, limit: limit)
            case "validate-pdf": result = try validatePDF(bytes)
            default: throw ParseFailure(message: "不支持的文档格式")
            }
        }
        catch { result = ParsedDocument(error: (error as? ParseFailure)?.message ?? "文档解析失败，未取得可引用内容") }
        do { try FileHandle.standardOutput.write(contentsOf: JSONEncoder().encode(result)) }
        catch { exit(1) }
    }

    private static func validatePDF(_ bytes: Data) throws -> ParsedDocument {
        guard let document = PDFDocument(data: bytes), !document.isEncrypted && !document.isLocked,
              document.pageCount > 0 else { throw ParseFailure(message: "编译输出不是可打开的未加密 PDF") }
        for index in Set([0, document.pageCount - 1]) {
            guard let page = document.page(at: index) else { throw ParseFailure(message: "编译输出含不可打开的 PDF 页面") }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width.isFinite && bounds.height.isFinite && bounds.width > 0 && bounds.height > 0 else {
                throw ParseFailure(message: "编译输出的 PDF 页面尺寸无效")
            }
        }
        return ParsedDocument(parts: [Part(index: 1, text: "PDF 结构可读取；内容、引用与页面布局仍需核对。")], total: document.pageCount)
    }

    private static func readPDF(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        guard let document = PDFDocument(data: bytes) else { throw ParseFailure(message: "PDF 损坏或格式无效，未读取内容") }
        guard !document.isEncrypted && !document.isLocked else { throw ParseFailure(message: "加密 PDF 暂不支持，请提供未加密副本；未读取内容") }
        guard document.allowsCopying else { throw ParseFailure(message: "PDF 不允许提取内容，未读取") }
        guard document.pageCount > 0 else { throw ParseFailure(message: "PDF 没有页面，未取得文字") }
        guard first <= document.pageCount else { throw ParseFailure(message: "起始页超过 PDF 总页数") }
        var result = ParsedDocument(total: document.pageCount)
        var remaining = 50 * 1024
        var hasText = false
        for index in (first - 1)..<min(document.pageCount, first - 1 + limit) {
            guard let page = document.page(at: index) else { throw ParseFailure(message: "PDF 页面损坏，未能完成本次读取") }
            let text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.utf8.count <= remaining else {
                throw ParseFailure(message: "所选 PDF 页面文字超过 50 KiB，请缩小 limit；单页过大时暂不支持")
            }
            hasText = hasText || !text.isEmpty
            remaining -= text.utf8.count
            result.parts.append(Part(index: index + 1, text: text.isEmpty ? "[本页没有可提取文字，可能为空白或扫描页；未进行 OCR]" : text))
        }
        guard hasText else {
            return emptySelection(unit: "页", first: first, last: min(document.pageCount, first - 1 + limit), total: document.pageCount,
                message: "所选 PDF 页面没有可提取文字，可能为空白或扫描型 PDF；未进行 OCR，不能声称已读取图像内容")
        }
        return result
    }
    private static func readWord(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        let delegate = WordParagraphParser()
        let parser = XMLParser(data: bytes)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        guard parser.parse(), delegate.hasBody else { throw ParseFailure(message: delegate.failure ?? "DOCX 正文损坏或包含不支持的 XML 结构；未读取内容") }
        let paragraphs = delegate.paragraphs
        guard !paragraphs.isEmpty else { throw ParseFailure(message: "DOCX 正文没有段落，未取得文字") }
        guard first <= paragraphs.count else { throw ParseFailure(message: "起始段落超过 DOCX 正文总段数") }
        let selection = (first - 1)..<min(paragraphs.count, first - 1 + limit)
        guard selection.contains(where: { !paragraphs[$0].isEmpty }) else {
            return emptySelection(unit: "段", first: first, last: selection.upperBound, total: paragraphs.count,
                message: "所选 DOCX 正文段落没有可提取文字；图片未进行 OCR")
        }
        guard selection.reduce(0, { $0 + paragraphs[$1].utf8.count }) <= 50 * 1024 else { throw ParseFailure(message: "所选 DOCX 文字超过 50 KiB，请缩小 limit；单段过大时暂不支持") }
        return ParsedDocument(parts: selection.map { Part(index: $0 + 1, text: paragraphs[$0].isEmpty ? "[空段落或无可提取文字；图片未进行 OCR]" : paragraphs[$0]) }, total: paragraphs.count)
    }

    private static func emptySelection(unit: String, first: Int, last: Int, total: Int, message: String) -> ParsedDocument {
        let continuation = last < total ? "；后续尚未读取，请使用 offset=\(last + 1) 继续" : "；已到文档末尾"
        return ParsedDocument(total: total, error: "\(message)。本次第 \(first)–\(last) \(unit)，共 \(total) \(unit)\(continuation)")
    }
}

// Number body paragraphs (including table cells and blank paragraphs) in XML order.
// Word pagination depends on layout; it is deliberately not inferred here.
private final class WordParagraphParser: NSObject, XMLParserDelegate {
    var paragraphs: [String] = []
    var hasBody = false
    var failure: String?
    private var inBody = false
    private var paragraph: String?
    private var inText = false
    private var skipDepth = 0
    private var depth = 0
    private let wordNamespaces = ["http://schemas.openxmlformats.org/wordprocessingml/2006/main", "http://purl.oclc.org/ooxml/wordprocessingml/main"]

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        depth += 1
        let isWord = wordNamespaces.contains(namespaceURI ?? "")
        if depth == 1 && (!isWord || element != "document") { parser.abortParsing(); return }
        if namespaceURI == "http://schemas.openxmlformats.org/markup-compatibility/2006" && element == "AlternateContent" {
            failure = "DOCX 包含暂不支持的兼容性替代内容（AlternateContent）；未读取内容"
            parser.abortParsing(); return
        }
        if skipDepth > 0 { skipDepth += 1; return }
        guard isWord else { return }
        if ["del", "moveFrom", "drawing", "pict", "txbxContent"].contains(element) { skipDepth = 1; return }
        if element == "body" {
            guard depth == 2 && !hasBody else { parser.abortParsing(); return }
            hasBody = true; inBody = true
        }
        guard inBody else { return }
        if element == "altChunk" {
            failure = "DOCX 包含暂不支持的嵌入正文（altChunk）；未读取内容，请在 Word 中转换为普通正文后重试"
            parser.abortParsing(); return
        }
        if element == "p" {
            guard paragraph == nil else { parser.abortParsing(); return }
            paragraph = ""
        }
        if paragraph != nil {
            if element == "t" { inText = true }
            if element == "tab" { paragraph?.append("\t") }
            if element == "br" || element == "cr" { paragraph?.append("\n") }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inText && skipDepth == 0 { paragraph?.append(string) } }
    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        defer { depth -= 1 }
        if skipDepth > 0 { skipDepth -= 1; return }
        guard wordNamespaces.contains(namespaceURI ?? "") else { return }
        if element == "t" { inText = false }
        if element == "p", let text = paragraph {
            paragraphs.append(text.trimmingCharacters(in: .whitespacesAndNewlines)); paragraph = nil
        }
        if element == "body" { inBody = false }
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) { parser.abortParsing() }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) { parser.abortParsing() }
}
