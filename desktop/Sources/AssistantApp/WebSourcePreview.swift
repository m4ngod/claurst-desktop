import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

struct WebSourcePreview: View {
    let source: WebSource
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(source.displayTitle).font(.headline).lineLimit(3)
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(source.url.absoluteString).font(.caption).textSelection(.enabled)
            if source.requestedURL != source.url {
                Text("请求链接：" + source.requestedURL.absoluteString).font(.caption).textSelection(.enabled)
            }
            Text("访问时间：" + source.retrievedAt).font(.caption).foregroundColor(.secondary)
            Text(source.locationLabel).foregroundColor(.secondary)
            Text("以下是读取时的静态正文记录，行号来自提取后的文本。网页可能更新；动态、登录及嵌入内容可能未读取。")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView([.horizontal, .vertical]) {
                Text(source.excerpt).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).frame(minHeight: 240)
                .background(WorkspaceStyle.canvas, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text(source.lastLine < source.totalLines ? "仅记录上方范围，仍有未读正文。" : "可对照原网页核验内容。").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("打开原网页") {
                    if source.isValid { NSWorkspace.shared.open(source.url) }
                }.disabled(!source.isValid)
            }
        }.padding(24).frame(minWidth: 560, minHeight: 360).background(WorkspaceStyle.surface)
    }
}

/// Only references backed by successful tool reads become clickable citations.
/// Page text and arbitrary model Markdown never create trusted source links.
struct WebCitationText: View {
    let text: String
    let sources: [WebSource]
    let onOpen: (WebSource) -> Void
    var body: some View {
        Text(attributed).textSelection(.enabled).lineSpacing(5)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "claurst-web", let source = sources.first(where: { $0.id == url.host && $0.isValid }) {
                    onOpen(source)
                    return .handled
                }
                return .discarded
            })
    }
    private var attributed: AttributedString {
        guard let pattern = try? NSRegularExpression(pattern: #"\[网页:([0-9a-fA-F-]{36})\]"#) else { return AttributedString(text) }
        var result = AttributedString()
        var cursor = text.startIndex
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), let idRange = Range(match.range(at: 1), in: text),
                  let source = sources.first(where: { $0.id == text[idRange].lowercased() && $0.isValid }),
                  let link = URL(string: "claurst-web://" + source.id) else { continue }
            result += AttributedString(String(text[cursor..<range.lowerBound]))
            var citation = AttributedString("[" + source.displayTitle + "]")
            citation.link = link
            result += citation
            cursor = range.upperBound
        }
        result += AttributedString(String(text[cursor...]))
        return result
    }
}
