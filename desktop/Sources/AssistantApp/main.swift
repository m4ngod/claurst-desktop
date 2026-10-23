import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

private let paper = Color(red: 0.98, green: 0.975, blue: 0.96)
private let sidebarColor = Color(red: 0.935, green: 0.93, blue: 0.90)
private let accent = Color(red: 0.72, green: 0.40, blue: 0.29)

@main struct AssistantApplication: App {
    @StateObject private var service = TaskService(executable: Bundle.main.resourceURL!.appendingPathComponent("claurst-desktop-runtime"))
    var body: some Scene {
        WindowGroup("Claurst Desktop · 开发版") {
            WorkspaceView(service: service)
                .frame(minWidth: 640, minHeight: 480)
                .tint(accent)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { ApplicationInfoCommands() }
        Window("许可证与第三方说明", id: "third-party-notices") {
            ThirdPartyNoticesView()
        }
        .defaultSize(width: 940, height: 660)
    }
}

@MainActor private struct WorkspaceView: View {
    @ObservedObject var service: TaskService
    @State private var selection: UUID?
    @State private var folder: URL?
    @State private var drafts: [UUID: String] = [:]
    @State private var newDraft = ""
    @State private var inspector = false
    @State private var showTasks = true
    @State private var settings = false
    @State private var activeProfileID: UUID?
    @State private var sourcePreview: FileSource?
    @State private var webSourcePreview: WebSource?
    @State private var changePreview: FileChange?
    @State private var latexPreview: LaTeXArtifact?
    @State private var latexHelp = false
    private var activeProfile: ModelProfile? { service.modelProfiles.first { $0.id == activeProfileID } }
    private var selected: DesktopTask? { service.tasks.first { $0.id == selection } }
    private var draft: String {
        get { selection.map { drafts[$0] ?? "" } ?? newDraft }
        nonmutating set {
            if let selection { drafts[selection] = newValue } else { newDraft = newValue }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if showTasks && geometry.size.width >= 820 { taskSidebar }
                VStack(spacing: 0) {
                    header
                    Divider()
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            if inspector && geometry.size.width < 1080 {
                                artifactPanel.frame(height: latexPreview == nil ? min(180, geometry.size.height * 0.28) : min(320, geometry.size.height * 0.45))
                            }
                            conversation
                        }
                        if inspector && geometry.size.width >= 1080 { artifactPanel.frame(width: latexPreview == nil ? 300 : min(480, geometry.size.width * 0.4)) }
                    }
                }
            }
            .background(paper)

        }
        .sheet(isPresented: $settings) { ModelSettingsView(service: service, activeProfileID: $activeProfileID) }
        .sheet(item: $sourcePreview) { SourcePreview(source: $0) }
        .sheet(item: $webSourcePreview) { WebSourcePreview(source: $0) }
        .sheet(isPresented: $latexHelp) { LaTeXHelp() }
        .sheet(item: $changePreview) { change in
            if let selection { ChangePreview(service: service, taskID: selection, initialChange: change) }
        }
        .onAppear {
            activeProfileID = service.modelProfiles.first?.id
            if selection == nil, let task = service.tasks.first { selection = task.id; folder = task.workspace }
        }
        .onChange(of: selection) { _ in
            latexPreview = nil
            if let task = selected,
               let profile = service.modelProfiles.first(where: { $0.model == task.modelName && $0.endpoint == task.endpoint }) {
                activeProfileID = profile.id
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in service.shutdown() }
    }

    private var taskSidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Claurst").font(.system(size: 24, design: .serif)).padding(.top, 28)
            Text("独立通用桌面助手").font(.caption).foregroundColor(.secondary)
            Button(action: { newTask() }) { Label("新任务", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.bordered)
            Button(action: { chooseFolder() }) { Label("选择工作文件夹", systemImage: "folder") }.buttonStyle(.plain)
            Text("最近任务").font(.caption).foregroundColor(.secondary).padding(.top, 12)
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(service.tasks) { task in
                        Button { selection = task.id; folder = task.workspace } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).lineLimit(1)
                                Text(task.status.rawValue).font(.caption2).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                .background(selection == task.id ? Color.black.opacity(0.06) : .clear).cornerRadius(7)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer()
            Button { settings = true } label: { Label("模型设置", systemImage: "slider.horizontal.3") }.buttonStyle(.plain)
            Text("开发版本 · 功能逐项验证中").font(.caption2).foregroundColor(.secondary)
        }.padding(16).frame(width: 180).background(sidebarColor)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { showTasks.toggle() } label: { Image(systemName: "sidebar.left") }.help("任务列表")
            Menu {
                Button("新任务", action: { newTask() })
                Button("选择工作文件夹", action: { chooseFolder() })
                ForEach(service.tasks) { task in Button(task.title) { selection = task.id; folder = task.workspace } }
            } label: { Text(selected?.title ?? "新任务").lineLimit(1) }
            Spacer()
            if selected?.isTest == true { Text("测试模型").font(.caption).foregroundColor(accent) }
            Text(selected?.status.rawValue ?? "准备就绪").font(.caption).foregroundColor(.secondary)
            Button { inspector.toggle() } label: { Label("素材与成果", systemImage: "sidebar.right") }
        }.buttonStyle(.plain).padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 15)
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 23) {
                        if let historyError = service.historyError {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(historyError).foregroundColor(.red).textSelection(.enabled)
                                HStack {
                                    Button("打开历史目录") { NSWorkspace.shared.open(service.historyDirectory) }
                                    Button("重新载入历史") { service.reloadHistory() }
                                }
                            }
                        }
                        if selected?.messages.isEmpty != false {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("从一件具体的事开始").font(.system(size: 30, weight: .regular, design: .serif))
                                Text("描述你想完成的任务。\n编程、阅读素材与研究写作，都从这里开始。")
                                    .foregroundColor(.secondary).lineSpacing(6)
                                Text("可读写文本，读取 PDF、Word（.docx）、Excel（.xlsx）和 UTF-8 CSV，并对表格分组求和。扫描 PDF 与 PNG/JPEG 可本地识别印刷文字，结果需对照原图核对。Excel 公式不重算；暂不支持旧格式、宏或加密文档。选定目录不会自动上传整个文件夹。").font(.caption).foregroundColor(accent)
                                Button("选择工作文件夹", action: { chooseFolder() }).buttonStyle(.bordered)
                            }.padding(.top, 55)
                        }
                        ForEach(selected?.messages ?? []) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message.role == "user" ? "你" : "助手").font(.caption).foregroundColor(.secondary)
                                WebCitationText(text: message.text.isEmpty ? (message.id == selected?.messages.last?.id && selected?.status.isActive == true ? "正在处理…" : "本次执行没有返回文本。") : message.text,
                                    sources: message.role == "assistant" ? selected?.webSources ?? [] : []) { webSourcePreview = $0 }
                            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? sidebarColor : .clear).cornerRadius(10)
                        }
                        if let error = selected?.error {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundColor(.red).textSelection(.enabled)
                        }
                        if let notice = selected?.controlNotice {
                            Text(notice).font(.callout).foregroundColor(.secondary).textSelection(.enabled)
                        }
                        ForEach(selected?.recoveryWarnings ?? [], id: \.self) { warning in
                            Text(warning).font(.callout).foregroundColor(.secondary).textSelection(.enabled)
                        }
                        ForEach(selected?.questions ?? []) { question in
                            UserQuestionView(question: question) { answer in
                                if let selection { service.answerQuestion(taskID: selection, requestID: question.id, text: answer) }
                            }
                        }
                        ForEach(selected?.requirements ?? []) { requirement in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("补充要求 · " + requirement.state.rawValue).font(.caption).foregroundColor(.secondary)
                                Text(requirement.text).textSelection(.enabled)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(sidebarColor).cornerRadius(8)
                        }
                        ForEach(selected?.permissions ?? []) { permission in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("需要你的授权").font(.headline)
                                Text(permission.description).textSelection(.enabled)
                                Text("允许后，工具将执行上方说明的操作；读取的内容会发送给当前模型。此授权不会保存为永久规则。")
                                    .font(.caption).foregroundColor(.secondary)
                                HStack {
                                    Button("拒绝") { if let selection { service.answerPermission(taskID: selection, requestID: permission.id, allow: false) } }
                                    Button("仅允许这一次") { if let selection { service.answerPermission(taskID: selection, requestID: permission.id, allow: true) } }
                                }.buttonStyle(.bordered)
                            }.padding(14).background(sidebarColor).cornerRadius(10)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }.frame(maxWidth: 720).padding(28).frame(maxWidth: .infinity)
                }.onChange(of: selected?.messages.last?.text) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.permissions.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.questions.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.requirements.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: Binding(get: { draft }, set: { draft = $0 })).font(.body).scrollContentBackground(.hidden).frame(height: 65).padding(8)
                    .accessibilityLabel("任务要求")
                HStack {
                    Button(action: { chooseFolder() }) { Label(folder?.lastPathComponent ?? "工作文件夹", systemImage: "folder") }.lineLimit(1)
                    Button { settings = true } label: { Label(selected?.modelName ?? activeProfile?.model ?? "配置模型", systemImage: "slider.horizontal.3") }.lineLimit(1)
                    Spacer()
                    if selected?.status.isActive == true {
                        Button("停止") { if let selection { service.stop(taskID: selection) } }.buttonStyle(.bordered)
                        Button("补充要求", action: { send() }).buttonStyle(.borderedProminent)
                            .disabled(selected?.status == .preparing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("发送", action: { send() }).buttonStyle(.borderedProminent)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selected?.requirements.contains(where: { $0.state == .received }) != true)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }.font(.caption).buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 10)
            }.background(Color.white).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)))
                .padding(.horizontal, 24).padding(.bottom, 8)
            if selected?.requirements.contains(where: { $0.state == .received }) == true {
                Text(selected?.status.isActive == true ? "补充要求已收到，将在下一轮执行时按顺序应用。" : "仍有未应用的补充要求，点发送可继续。")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Text("工作范围：" + (selected?.workspace.path ?? folder?.path ?? "尚未选择"))
                .font(.caption2).foregroundColor(.secondary).lineLimit(1).help(selected?.workspace.path ?? "")
            Text(selected?.endpoint.map { "模型服务：" + $0 } ?? "请选择文件夹并配置模型后开始").font(.caption2).foregroundColor(.secondary).lineLimit(1).padding(.bottom, 14)
        }
    }

    @ViewBuilder private var artifactPanel: some View {
        if let artifact = latexPreview, let task = selected {
            LaTeXArtifactPreview(artifact: artifact, workspace: task.workspace,
                back: { latexPreview = nil }, close: { inspector = false })
                .background(sidebarColor)
        } else {
            artifactList
        }
    }

    private var artifactList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("素材与成果").font(.headline); Spacer(); Button { inspector = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Group {
                        if selected?.latexArtifacts.isEmpty == false {
                            Text("文档成果").font(.headline)
                            ForEach(selected?.latexArtifacts ?? []) { artifact in
                                Button { latexPreview = artifact } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(artifact.pdfFile.lastPathComponent, systemImage: "doc.richtext")
                                        Text("\(artifact.pageCount) 页 · " + artifact.compiledAt).font(.caption2)
                                        Text(artifact.reviewNotes.isEmpty ? "已编译 · 内容与布局仍需核对" : "已编译 · \(artifact.reviewNotes.count) 条警告待核对")
                                            .font(.caption).foregroundColor(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                            }
                            Divider()
                        }
                        Button("排版组件说明") { latexHelp = true }.font(.caption)
                    }
                    Group {
                        Text("已读取的文件").font(.headline)
                        if selected?.sources.isEmpty != false { Text("尚未读取文件").foregroundColor(.secondary) }
                        ForEach(selected?.sources ?? []) { source in
                            Button { sourcePreview = source } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(source.file.lastPathComponent, systemImage: "doc.text")
                                    Text(source.locationLabel + " · 查看读取内容").font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                        }
                    }
                    if selected?.webSources.isEmpty == false {
                        Divider()
                        Text("已读取的网页").font(.headline)
                        ForEach(selected?.webSources ?? []) { source in
                            Button { webSourcePreview = source } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(source.displayTitle, systemImage: "globe")
                                    Text(source.url.host ?? source.url.absoluteString).font(.caption).foregroundColor(.secondary)
                                    Text(source.locationLabel).font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain)
                        }
                    }
                    Group {
                        Divider()
                        ProjectChecksView(task: selected)
                        Divider()
                    }
                    Text("执行记录").font(.headline)
                    ForEach(selected?.tools ?? []) { tool in
                        DisclosureGroup {
                            Text(tool.output).font(.caption).textSelection(.enabled)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.title.isEmpty ? "工具调用" : tool.title)
                                Text(tool.status).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    Divider()
                    Text("文件修改").font(.headline)
                    if selected?.changes.isEmpty != false { Text("尚无文件修改").font(.caption).foregroundColor(.secondary) }
                    ForEach(selected?.changes ?? []) { change in
                        Button { changePreview = change } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(change.file.lastPathComponent, systemImage: "doc.badge.gearshape")
                                Text("修改原因（助手说明）：" + (change.reason ?? "未提供")).font(.caption).foregroundColor(.secondary)
                                Text(change.summary + (change.restoredAt == nil ? " · 查看变化与恢复" : " · 已恢复")).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(20).frame(maxHeight: .infinity).background(sidebarColor)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let pending = selection == nil ? newDraft : ""
            folder = url; selection = service.createTask(workspace: url)
            if !pending.isEmpty { draft = pending; newDraft = "" }
        }
    }
    private func newTask() {
        guard let folder else { chooseFolder(); return }
        selection = service.createTask(workspace: folder)
    }
    private func send() {
        guard let profileID = activeProfileID else { settings = true; return }
        guard let folder else { chooseFolder(); return }
        if selection == nil {
            let pending = newDraft
            selection = service.createTask(workspace: folder)
            draft = pending; newDraft = ""
        }
        guard let id = selection else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请按已收到的补充要求继续。" : draft
        Task { await service.send(taskID: id, text: text, profileID: profileID) {
            if drafts[id] == text {
                var updated = drafts
                updated[id] = ""
                drafts = updated
            }
        } }
    }
}
