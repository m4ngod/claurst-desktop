import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

struct SourcePreview: View {
    let source: FileSource
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(source.file.lastPathComponent).font(.headline)
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(source.file.path).font(.caption).textSelection(.enabled)
            Text((source.documentLocation?.visual == true ? "供模型查看的图像记录 · " :
                (source.tableLocation == nil ? "工具实际读取的内容 · " : "本地读取与计算记录 · ")) + source.locationLabel).foregroundColor(.secondary)
            if source.tableLocation != nil {
                Text("按实际单元格或 CSV 记录定位。公式仅显示缓存，未重新计算；统计方法、范围与缺失值见下方记录。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if source.documentLocation?.visual == true {
                Text("已生成所选页面或图片的图像副本，识别结论仍须对照原图核验。此记录不证明模型服务已接收或理解图像；调用结果见对话。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if source.documentLocation?.recognition == true {
                Text("本地文字识别记录，尚未逐项验证。请对照原图核对数字和文字；像素区域、置信分数及限制见下方。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if source.documentLocation?.unit == .paragraph {
                Text("正文按文档顺序计段，含表格和空段落；不提供固定页码。页眉页脚、批注、脚注、文本框与图片未读取；删除修订忽略，插入修订保留。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if source.documentLocation?.unit == .page {
                Text("仅提取文字层；图片和扫描页未进行 OCR。")
                    .font(.caption).foregroundColor(.secondary)
            }
            ScrollView([.horizontal, .vertical]) {
                Text(source.excerpt).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).frame(minHeight: 240)
                .background(WorkspaceStyle.canvas, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Text("这是读取时的记录；文件之后可能已改变。").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("打开原文件") { NSWorkspace.shared.open(source.file) }
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([source.file]) }
            }
        }.padding(24).frame(minWidth: 560, minHeight: 360).background(WorkspaceStyle.surface)
    }
}
