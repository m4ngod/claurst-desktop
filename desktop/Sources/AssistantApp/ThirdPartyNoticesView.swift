import AppKit
import SwiftUI

private struct NoticeEntry: Decodable, Identifiable {
    let path: String
    let title: String
    let category: String
    let detail: String
    var id: String { path }
}

private struct NoticeCatalog: Decodable {
    let entries: [NoticeEntry]
}

/// Local bundle documents only. HTML is displayed as text, never executed.
struct ThirdPartyNoticesView: View {
    @State private var entries: [NoticeEntry] = []
    @State private var selected: String?
    @State private var query = ""
    @State private var content = ""
    @State private var error: String?
    @State private var exportError: String?
    private var root: URL? { Bundle.main.resourceURL?.appendingPathComponent("notices", isDirectory: true) }
    private var current: NoticeEntry? { entries.first { $0.id == selected } }
    private var filtered: [NoticeEntry] {
        entries.filter { query.isEmpty || ($0.title + " " + $0.category + " " + $0.detail).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("许可证与第三方说明").font(.title2.bold())
                Spacer()
                Button("总览") { selected = nil; showDocument(nil) }
                Button("导出原文到 Finder", action: exportOriginal).disabled(error != nil)
            }.padding()
            Divider()
            HSplitView {
                VStack(alignment: .leading) {
                    TextField("搜索组件、版本或许可", text: $query)
                        .textFieldStyle(.roundedBorder).padding([.horizontal, .top], 10)
                    Text("\(filtered.count) 份原文").font(.caption).foregroundColor(.secondary).padding(.horizontal, 12)
                    List(filtered, selection: $selected) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title).lineLimit(2)
                            Text(entry.category).font(.caption).foregroundColor(.secondary)
                        }.padding(.vertical, 3).tag(entry.id)
                    }.listStyle(.sidebar)
                }.frame(minWidth: 220, idealWidth: 280, maxWidth: 400)
                VStack(alignment: .leading, spacing: 8) {
                    Text(current?.title ?? "Claurst Desktop").font(.headline).textSelection(.enabled)
                    if let current, !current.detail.isEmpty {
                        Text(current.detail).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
                    }
                    if let error {
                        Text(error).foregroundColor(.red).textSelection(.enabled)
                        Spacer()
                    } else {
                        NoticeTextView(text: content)
                    }
                }.padding().frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
        .onAppear(perform: load)
        .onChange(of: selected) { _ in showDocument(current) }
        .alert("无法导出原文", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("好", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private func exportOriginal() {
        do {
            guard let source = documentURL(current) else { throw CocoaError(.fileReadInvalidFileName) }
            // Finder URL selection can block inside a signed app bundle on macOS 27.
            // Export a distinct original-byte copy, leaving the sealed bundle untouched.
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("claurst-notice-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            let copy = folder.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: copy)
            if !NSWorkspace.shared.selectFile(copy.path, inFileViewerRootedAtPath: "") {
                exportError = "原文已导出，但 Finder 未能定位：\(copy.path)"
            }
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func documentURL(_ entry: NoticeEntry?) -> URL? {
        guard let root else { return nil }
        let path = entry?.path ?? "README.txt"
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        let url = root.appendingPathComponent(path).resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { return nil }
        return url
    }

    private func load() {
        do {
            guard let root else { throw CocoaError(.fileNoSuchFile) }
            entries = try JSONDecoder().decode(NoticeCatalog.self, from: Data(contentsOf: root.appendingPathComponent("index.json"))).entries
            showDocument(current)
        } catch {
            self.error = "无法读取随应用附带的说明，请重新构建或安装完整应用。\n\(error.localizedDescription)"
        }
    }

    private func showDocument(_ entry: NoticeEntry?) {
        do {
            guard let url = documentURL(entry) else { throw CocoaError(.fileReadInvalidFileName) }
            let data = try Data(contentsOf: url)
            guard data.count <= 8 * 1024 * 1024,
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            content = text
            error = nil
        } catch {
            content = ""
            self.error = "无法显示此原文：\(error.localizedDescription)"
        }
    }
}

private struct NoticeTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(width: 8, height: 8)
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
        view.setSelectedRange(NSRange(location: 0, length: 0))
        view.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}

struct ApplicationInfoCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 Claurst Desktop") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [
                    .applicationName: "Claurst Desktop",
                    .applicationVersion: "0.1.0-dev",
                    .credits: NSAttributedString(string: "基于 Claurst 0.2.0 的独立桌面助手。\n开发版本，公开发布验收进行中。")
                ])
            }
            Button("许可证与第三方说明…") { openWindow(id: "third-party-notices") }
        }
    }
}
