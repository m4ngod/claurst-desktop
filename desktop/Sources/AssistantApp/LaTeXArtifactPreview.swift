import SwiftUI
import PDFKit
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct LaTeXArtifactPreview: View {
    let artifact: LaTeXArtifact
    let workspace: URL
    let back: () -> Void
    let close: () -> Void
    @State private var tab = "PDF"
    @State private var pdfData: Data?
    @State private var source = "正在读取…"
    @State private var log = "正在读取…"
    @State private var error: String?

    @State private var page = 0
    @State private var expanded = false
    @State private var showReviewNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: back) { Image(systemName: "chevron.left") }.help("返回成果").accessibilityLabel("返回成果")
                Text(artifact.mainFile.lastPathComponent).font(.headline).lineLimit(1)
                Spacer()
                Menu {
                    Button("打开源文件") { open(artifact.mainFile) }
                    Button("打开项目") { open(artifact.mainFile.deletingLastPathComponent()) }
                    Button("导出 PDF…") { exportPDF() }.disabled(pdfData == nil)
                    Button("在 Finder 中显示") {
                        if allowed(artifact.pdfFile) { NSWorkspace.shared.activateFileViewerSelecting([artifact.pdfFile]) }
                    }
                } label: { Image(systemName: "ellipsis.circle") }.help("成果操作").accessibilityLabel("成果操作")
                Button { expanded = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .help("放大 PDF 预览").accessibilityLabel("放大 PDF 预览").disabled(pdfData == nil)
                Button(action: close) { Image(systemName: "xmark") }.help("关闭素材与成果").accessibilityLabel("关闭素材与成果")
            }.buttonStyle(.plain)
            Text("已编译 \(artifact.pageCount) 页 · \(artifact.compiledAt)")
                .font(.caption2).foregroundColor(.secondary).lineLimit(1)
            Picker("查看成果", selection: $tab) {
                Text("PDF").tag("PDF")
                Text("LaTeX").tag("LaTeX")
                Text("日志").tag("日志")
            }.pickerStyle(.segmented)
            Group {
                if tab == "PDF", let pdfData {
                    PDFPagePreview(data: pdfData, digest: artifact.pdfSHA256, pageCount: artifact.pageCount, page: $page)
                        .id(artifact.pdfSHA256)
                } else if tab == "PDF" {
                    Text(error == nil ? "正在打开 PDF…" : "PDF 暂不可预览").foregroundColor(.secondary)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(tab == "LaTeX" ? source : log).font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(artifact.reviewNotes.isEmpty ? "内容与布局需结合对话核对" : "\(artifact.reviewNotes.count) 条编译警告，需核对") {
                showReviewNotes = true
            }.font(.caption2).buttonStyle(.plain)
                .foregroundColor(artifact.reviewNotes.isEmpty ? .secondary : .orange)
                .popover(isPresented: $showReviewNotes) {
                    ScrollView {
                        Text("编译成功不代表内容、引用与页面布局已核对；检查结果请结合对话。这里的 LaTeX 显示当前主文件，修改后需重新编译。\n\n"
                             + artifact.reviewNotes.joined(separator: "\n"))
                            .font(.caption).textSelection(.enabled).padding(16)
                    }.frame(width: 320, height: 180)
                }
            if let error { Text(error).font(.caption).foregroundColor(.red).lineLimit(2).help(error) }
        }.padding(12)
            .task(id: artifact.id) { await load() }
            .sheet(isPresented: $expanded) {
                if let pdfData {
                    VStack(spacing: 12) {
                        HStack {
                            Text(artifact.pdfFile.lastPathComponent).font(.headline)
                            Spacer()
                            Button("关闭放大预览") { expanded = false }
                        }
                        PDFPagePreview(data: pdfData, digest: artifact.pdfSHA256, pageCount: artifact.pageCount, page: $page)
                    }.padding(16)
                        .frame(width: min(820, (NSScreen.main?.visibleFrame.width ?? 900) - 80),
                               height: min(700, (NSScreen.main?.visibleFrame.height ?? 800) - 100))
                }
            }
    }

    private func allowed(_ file: URL) -> Bool {
        guard artifact.isValid(in: workspace), file.resolvingSymlinksInPath().path.hasPrefix(workspace.resolvingSymlinksInPath().path + "/") else {
            error = "成果文件已移出原工作文件夹，无法打开。"; return false
        }
        return true
    }
    private func open(_ file: URL) {
        if allowed(file), !NSWorkspace.shared.open(file) { error = "无法打开文件，请确认文件仍存在且有可用应用。" }
    }
    private func exportPDF() {
        guard let pdfData else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = artifact.pdfFile.lastPathComponent
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try pdfData.write(to: destination, options: .atomic) }
        catch { self.error = "PDF 导出失败：\(error.localizedDescription)" }
    }
    private func load() async {
        pdfData = nil; error = nil; page = 0
        let artifact = artifact, workspace = workspace
        let result = await Task.detached { () -> (Data?, String, String, String?) in
            func text(_ file: URL) -> String {
                guard file.resolvingSymlinksInPath().path.hasPrefix(workspace.resolvingSymlinksInPath().path + "/") else { return "文件已移出工作文件夹，未读取。" }
                do {
                    let handle = try FileHandle(forReadingFrom: file)
                    defer { try? handle.close() }
                    let bytes = try handle.read(upToCount: 512 * 1024 + 1) ?? Data()
                    return String(decoding: bytes.prefix(512 * 1024), as: UTF8.self)
                        + (bytes.count > 512 * 1024 ? "\n[预览截断，请打开源文件查看完整内容]" : "")
                } catch { return "文件缺失或无法读取：\(error.localizedDescription)" }
            }
            do { return (try artifact.checkedPDFData(in: workspace), text(artifact.mainFile), text(artifact.logFile), nil) }
            catch { return (nil, text(artifact.mainFile), text(artifact.logFile), error.localizedDescription) }
        }.value
        guard !Task.isCancelled else { return }
        pdfData = result.0; source = result.1; log = result.2; error = result.3
    }
}

@MainActor private struct PDFPagePreview: View {
    let data: Data
    let digest: String
    let pageCount: Int
    @Binding var page: Int

    var body: some View {
        VStack(spacing: 6) {
            CompiledPDFView(data: data, digest: digest, page: $page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button { page -= 1 } label: { Image(systemName: "chevron.left") }
                    .help("上一页").accessibilityLabel("上一页").disabled(page <= 0)
                Text("第 \(page + 1) / \(pageCount) 页").font(.caption).monospacedDigit()
                Button { page += 1 } label: { Image(systemName: "chevron.right") }
                    .help("下一页").accessibilityLabel("下一页").disabled(page + 1 >= pageCount)
            }.buttonStyle(.plain)
        }
    }
}

@MainActor private struct CompiledPDFView: NSViewRepresentable {
    let data: Data
    let digest: String
    @Binding var page: Int

    @MainActor final class Coordinator: NSObject {
        var parent: CompiledPDFView
        var digest = ""
        var updating = false
        init(_ parent: CompiledPDFView) { self.parent = parent }
        @objc func pageChanged(_ notification: Notification) {
            guard !updating, let view = notification.object as? PDFView,
                  let document = view.document, let current = view.currentPage else { return }
            let index = document.index(for: current)
            if index != NSNotFound, index != parent.page { parent.page = index }
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        // Continuous mode fits the width, leaving only the top margin visible in a short panel.
        view.displayMode = .singlePage
        view.autoScales = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
                                               name: .PDFViewPageChanged, object: view)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updating = true
        defer { context.coordinator.updating = false }
        if context.coordinator.digest != digest {
            view.document = PDFDocument(data: data)
            view.autoScales = true
            context.coordinator.digest = digest
        }
        if let target = view.document?.page(at: page), view.currentPage !== target {
            view.go(to: target)
        }
    }
}

struct LaTeXHelp: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("LaTeX 排版组件").font(.headline); Spacer(); Button("关闭") { dismiss() } }
            Text("应用使用内置编译器与基础中文排版资源，任务编译时不联网下载。中文主文件可使用 ctexart 和 fontset=claurst，章节、图片与参考文献应保存在项目文件夹中。")
            Text("如果提示组件缺失或不完整，请重新打开完整的应用安装包；源码开发者需先完成构建文档中的排版资源准备步骤。")
            Text("如果提示找不到宏包或字体，请将具体错误留在对话中，让助手采用已包含的基础模板，或把合法可用的支持文件放入项目后再次编译。应用不会自行安装系统软件或发送项目到在线排版服务。")
            Text("PDF 已生成后仍要核对内容、引用和页面布局。编译日志、未解决警告与当前 LaTeX 源文件均可在成果预览中查看。")
        }.font(.callout).textSelection(.enabled).padding(22).frame(width: 520)
    }
}
