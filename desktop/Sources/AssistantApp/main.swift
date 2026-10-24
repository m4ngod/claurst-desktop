import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

private let paper = WorkspaceStyle.canvas
private let sidebarColor = WorkspaceStyle.sidebar
private let accent = WorkspaceStyle.accent

@main struct AssistantApplication: App {
    @StateObject private var service = TaskService(executable: Bundle.main.resourceURL!.appendingPathComponent("claurst-desktop-runtime"))
    var body: some Scene {
        WindowGroup("Claurst Desktop", id: "workspace") {
            WorkspaceView(service: service)
                .frame(minWidth: 640, minHeight: 480)
                .tint(accent)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands { ApplicationInfoCommands(); WorkspaceCommands() }
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
    @State private var showCapabilities = false
    @State private var showTaskPopover = false
    @State private var workspaceWidth: CGFloat = 1180
    @FocusState private var composerFocused: Bool
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
            ZStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    if showTasks && geometry.size.width >= 840 && (!inspector || geometry.size.width >= 1180) {
                        taskSidebar
                        Divider()
                    }
                    VStack(spacing: 0) {
                        header
                        Divider().opacity(0.55)
                        HStack(spacing: 0) {
                            conversation
                            if inspector && geometry.size.width >= 900 {
                                Divider()
                                artifactPanel.frame(width: latexPreview == nil ? 310 : min(460, geometry.size.width * 0.4))
                            }
                        }
                    }
                    .disabled(inspector && geometry.size.width < 900)
                    .accessibilityHidden(inspector && geometry.size.width < 900)
                }
                if inspector && geometry.size.width < 900 {
                    Color.black.opacity(0.16).ignoresSafeArea()
                        .onTapGesture { inspector = false }
                        .accessibilityHidden(true)
                    artifactPanel.frame(width: min(390, geometry.size.width - 40))
                        .background(WorkspaceStyle.surface)
                        .overlay(alignment: .leading) { Divider() }
                        .shadow(color: .black.opacity(0.12), radius: 16, x: -6)
                }
            }
            .background(paper)
            .onAppear { workspaceWidth = geometry.size.width }
            .onChange(of: geometry.size.width) { workspaceWidth = $0 }
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
            showTaskPopover = false
            if let task = selected,
               let profile = service.modelProfiles.first(where: { $0.model == task.modelName && $0.endpoint == task.endpoint }) {
                activeProfileID = profile.id
            }
        }
        .focusedSceneValue(\.workspaceActions, WorkspaceActions(
            newTask: { newTask() }, chooseFolder: { chooseFolder() },
            focusComposer: { inspector = false; composerFocused = true }, settings: { settings = true },
            toggleTasks: { toggleTasks() }, toggleArtifacts: { inspector.toggle() }))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in service.shutdown() }
    }

    private var taskSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claurst").font(.system(size: 23, weight: .medium, design: .serif))
                Text("桌面助手").font(.system(size: 11)).foregroundColor(.secondary)
            }.padding(.horizontal, 10).padding(.top, 24)
            Button(action: { newTask() }) {
                HStack {
                    Label("新任务", systemImage: "square.and.pencil")
                    Spacer()
                    Text("⌘N").font(.caption).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(WorkspaceButtonStyle()).background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 8))
            Button(action: { chooseFolder() }) {
                Label("选择工作文件夹", systemImage: "folder").frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(WorkspaceButtonStyle())
            HStack {
                Text("最近任务")
                Spacer()
                Text("\(service.tasks.count)").monospacedDigit()
            }.font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 10).padding(.top, 8)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(service.tasks) { task in
                        Button { selection = task.id; folder = task.workspace } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title).font(.system(size: 13, weight: selection == task.id ? .medium : .regular)).lineLimit(2)
                                TaskStatusLabel(status: task.status, compact: true)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(WorkspaceButtonStyle(selected: selection == task.id))
                            .help(task.title)
                            .accessibilityAddTraits(selection == task.id ? [.isSelected] : [])
                    }
                    if service.tasks.isEmpty {
                        Text("开始新任务后，对话会保存在这里。")
                            .font(.caption).foregroundColor(.secondary).padding(10)
                    }
                }.padding(1)
            }
            Divider().opacity(0.6)
            Button { settings = true } label: {
                Label("模型设置", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(WorkspaceButtonStyle())
        }.padding(12).frame(width: 204).background(sidebarColor)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { toggleTasks() } label: { Image(systemName: "sidebar.left").frame(width: 18, height: 18) }
                .help("显示或隐藏任务列表（⌃⌘S）").accessibilityLabel("任务列表")
                .popover(isPresented: $showTaskPopover) { taskSidebar.frame(height: 460) }
            Menu {
                Button("新任务") { newTask() }
                Button("选择工作文件夹") { chooseFolder() }
                Button("输入任务要求") { composerFocused = true }
                Divider()
                ForEach(service.tasks) { task in Button(task.title) { selection = task.id; folder = task.workspace } }
            } label: { Text(selected?.title ?? "新任务").font(.system(size: 13, weight: .medium)).lineLimit(1) }
                .menuStyle(.borderlessButton).foregroundColor(.primary).tint(.primary).fixedSize(horizontal: false, vertical: true)
                .help(selected?.title ?? "新任务")
            Spacer(minLength: 8)
            if selected?.isTest == true { Text("测试模型").font(.caption).foregroundColor(accent) }
            TaskStatusLabel(status: selected?.status ?? .ready)
            Button { settings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 18, height: 18) }
                .help("模型设置（⌘,）").accessibilityLabel("模型设置")
            Button { inspector.toggle() } label: { Image(systemName: "sidebar.right").frame(width: 18, height: 18) }
                .buttonStyle(WorkspaceButtonStyle(selected: inspector))
                .help("素材与成果（⌃⌘I）").accessibilityLabel("素材与成果")
                .accessibilityValue(inspector ? "已展开" : "已收起")

        }.buttonStyle(WorkspaceButtonStyle()).padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 10)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkle").font(.system(size: 25, weight: .light)).foregroundColor(accent)
            Text("从一件具体的事开始").font(.system(size: 28, weight: .regular, design: .serif))
            Text("编程、阅读素材与研究写作。\n告诉我你想完成什么，我们从这里开始。")
                .font(.system(size: 14)).foregroundColor(.secondary).lineSpacing(6)
            HStack(spacing: 12) {
                Button(action: { chooseFolder() }) { Label(folder == nil ? "选择工作文件夹" : "更换工作文件夹", systemImage: "folder") }
                    .buttonStyle(.bordered)
                Button("支持哪些素材？") { showCapabilities.toggle() }
                    .buttonStyle(WorkspaceButtonStyle())
                    .popover(isPresented: $showCapabilities) {
                        Text("可读写文本，读取 PDF、Word（.docx）、Excel（.xlsx）和 UTF-8 CSV，并对表格分组求和。扫描 PDF 与 PNG/JPEG 可本地识别印刷文字，结果需对照原图核对。Excel 公式不重算；暂不支持旧格式、宏或加密文档。选定目录不会自动上传整个文件夹。")
                            .font(.callout).lineSpacing(4).padding(20).frame(width: 340)
                    }
            }.font(.system(size: 12))
        }.padding(.vertical, 36).frame(maxWidth: .infinity, alignment: .leading)
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
                        if selected?.messages.isEmpty != false { welcome }
                        ForEach(selected?.messages ?? []) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message.role == "user" ? "你" : "Claurst").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                                WebCitationText(text: message.text.isEmpty ? (message.id == selected?.messages.last?.id && selected?.status.isActive == true ? "正在处理…" : "本次执行没有返回文本。") : message.text,
                                    sources: message.role == "assistant" ? selected?.webSources ?? [] : []) { webSourcePreview = $0 }
                            }.font(.system(size: 14)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? WorkspaceStyle.subtle.opacity(0.55) : .clear, in: RoundedRectangle(cornerRadius: 12))
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
                        requirementList
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
                    }.frame(maxWidth: 720).padding(24).frame(maxWidth: .infinity)
                }.onChange(of: selected?.messages.last?.text) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.permissions.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.questions.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
                    .onChange(of: selected?.requirements.count) { _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            composer
        }
    }

    @ViewBuilder private var requirementList: some View {
        ForEach((selected?.requirements ?? []).filter { $0.state == .received }) { requirement in
            VStack(alignment: .leading, spacing: 6) {
                Label("补充要求 · 已收到", systemImage: "text.badge.plus").font(.caption).foregroundColor(.secondary)
                Text(requirement.text).textSelection(.enabled)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(sidebarColor, in: RoundedRectangle(cornerRadius: 8))
        }
        let applied = (selected?.requirements ?? []).filter { $0.state == .applied }
        if !applied.isEmpty {
            DisclosureGroup("已应用的补充要求 · \(applied.count)") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(applied) { Text($0.text).textSelection(.enabled) }
                }.padding(.top, 8)
            }.font(.callout).foregroundColor(.secondary).padding(12)
                .background(sidebarColor, in: RoundedRectangle(cornerRadius: 8))
                .id(selection)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text(selected?.status.isActive == true ? "补充要求，或随时停止当前任务…" : "描述任务，或继续补充你的想法…")
                            .foregroundColor(.secondary).padding(.horizontal, 13).padding(.top, 14)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextEditor(text: Binding(get: { draft }, set: { draft = $0 }))
                        .scrollContentBackground(.hidden).frame(height: 72).padding(8)
                        .focused($composerFocused).accessibilityLabel("任务要求")
                        .accessibilityHint("Command Return 发送；Return 换行")
                }.font(.system(size: 14))
                HStack(spacing: 4) {
                    Button(action: { chooseFolder() }) { Label(folder?.lastPathComponent ?? "工作文件夹", systemImage: "folder").lineLimit(1) }
                        .help(selected?.workspace.path ?? folder?.path ?? "选择任务的工作文件夹")
                    Button { settings = true } label: {
                        Label(selected?.modelName ?? activeProfile?.model ?? "配置模型", systemImage: "slider.horizontal.3").lineLimit(1)
                    }.help("选择模型与服务配置")
                    Spacer(minLength: 4)
                    if selected?.status.isActive == true {
                        Button { if let selection { service.stop(taskID: selection) } } label: { Label("停止", systemImage: "stop.fill") }
                            .buttonStyle(.bordered).disabled(selected?.status == .stopping)
                            .help("停止当前执行，保留已完成内容")
                        Button("补充要求", action: { send() }).buttonStyle(.borderedProminent)
                            .disabled(selected?.status == .preparing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command)
                    } else {
                        Button(action: { send() }) {
                            Label(selected?.status == .stopped ? "继续" : "发送", systemImage: "arrow.up")
                        }.buttonStyle(.borderedProminent)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selected?.requirements.contains(where: { $0.state == .received }) != true)
                            .keyboardShortcut(.return, modifiers: .command).help("发送任务（⌘↵）")
                    }
                }.font(.system(size: 12)).buttonStyle(WorkspaceButtonStyle()).padding(.horizontal, 8).padding(.bottom, 8)
            }
            .background(WorkspaceStyle.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(composerFocused ? accent.opacity(0.65) : WorkspaceStyle.border, lineWidth: composerFocused ? 1.5 : 1))
            .shadow(color: .black.opacity(0.025), radius: 5, y: 2)
            if selected?.requirements.contains(where: { $0.state == .received }) == true {
                Text(selected?.status.isActive == true ? "补充要求已收到，将在下一轮执行时按顺序应用。" : "仍有未应用的补充要求，点发送可继续。")
                    .font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Text("工作范围：" + (selected?.workspace.path ?? folder?.path ?? "尚未选择"))
                    .lineLimit(1).truncationMode(.middle)
                    .help(selected?.workspace.path ?? folder?.path ?? "请选择工作文件夹")
                Spacer(minLength: 0)
                Text("⌘↵ 发送").fixedSize()
            }.font(.system(size: 10)).foregroundColor(.secondary)
            if selected?.endpoint == nil && activeProfile == nil {
                Text("请选择文件夹并配置模型后开始").font(.caption).foregroundColor(.secondary)
            }
        }.frame(maxWidth: 768).padding(.horizontal, 24).padding(.bottom, 14).frame(maxWidth: .infinity)
    }

    @ViewBuilder private var artifactPanel: some View {
        if let artifact = latexPreview, let task = selected {
            LaTeXArtifactPreview(artifact: artifact, workspace: task.workspace,
                back: { latexPreview = nil }, close: { inspector = false })
                .background(WorkspaceStyle.surface)
        } else {
            artifactList
        }
    }

    private var artifactList: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("素材与成果").font(.system(size: 14, weight: .semibold)); Spacer(); Button { inspector = false } label: { Image(systemName: "xmark").frame(width: 16, height: 16) }.buttonStyle(WorkspaceButtonStyle()).help("关闭素材与成果（Esc）").accessibilityLabel("关闭素材与成果").keyboardShortcut(.cancelAction) }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Group {
                        if selected?.latexArtifacts.isEmpty == false {
                            Text("文档成果").font(.system(size: 12, weight: .semibold))
                            ForEach(selected?.latexArtifacts ?? []) { artifact in
                                Button { latexPreview = artifact } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(artifact.pdfFile.lastPathComponent, systemImage: "doc.richtext")
                                        Text("\(artifact.pageCount) 页 · " + artifact.compiledAt).font(.caption2)
                                        Text(artifact.reviewNotes.isEmpty ? "已编译 · 内容与布局仍需核对" : "已编译 · \(artifact.reviewNotes.count) 条警告待核对")
                                            .font(.caption).foregroundColor(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(WorkspaceButtonStyle())
                            }
                            Divider()
                        }
                        Button("排版组件说明") { latexHelp = true }.font(.caption)
                    }
                    Group {
                        Text("已读取的文件").font(.system(size: 12, weight: .semibold))
                        if selected?.sources.isEmpty != false { Text("读取的素材会在这里保留来源位置。").font(.caption).foregroundColor(.secondary) }
                        ForEach(selected?.sources ?? []) { source in
                            Button { sourcePreview = source } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(source.file.lastPathComponent, systemImage: "doc.text")
                                    Text(source.locationLabel + " · 查看读取内容").font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(WorkspaceButtonStyle())
                        }
                    }
                    if selected?.webSources.isEmpty == false {
                        Divider()
                        Text("已读取的网页").font(.system(size: 12, weight: .semibold))
                        ForEach(selected?.webSources ?? []) { source in
                            Button { webSourcePreview = source } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(source.displayTitle, systemImage: "globe")
                                    Text(source.url.host ?? source.url.absoluteString).font(.caption).foregroundColor(.secondary)
                                    Text(source.locationLabel).font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(WorkspaceButtonStyle())
                        }
                    }
                    Group {
                        Divider()
                        ProjectChecksView(task: selected)
                        Divider()
                    }
                    Text("执行记录").font(.system(size: 12, weight: .semibold))
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
                    Text("文件修改").font(.system(size: 12, weight: .semibold))
                    if selected?.changes.isEmpty != false { Text("尚无文件修改").font(.caption).foregroundColor(.secondary) }
                    ForEach(selected?.changes ?? []) { change in
                        Button { changePreview = change } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label(change.file.lastPathComponent, systemImage: "doc.badge.gearshape")
                                Text("修改原因（助手说明）：" + (change.reason ?? "未提供")).font(.caption).foregroundColor(.secondary)
                                Text(change.summary + (change.restoredAt == nil ? " · 查看变化与恢复" : " · 已恢复")).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(WorkspaceButtonStyle())
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.font(.system(size: 12)).padding(16).frame(maxHeight: .infinity).background(WorkspaceStyle.surface)
    }

    private func toggleTasks() {
        if workspaceWidth < 840 || (inspector && workspaceWidth < 1180) {
            showTaskPopover.toggle()
        } else {
            showTasks.toggle()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let pending = selection == nil ? newDraft : ""
            folder = url; selection = service.createTask(workspace: url)
            composerFocused = true
            if !pending.isEmpty { draft = pending; newDraft = "" }
        }
    }
    private func newTask() {
        guard let folder else { chooseFolder(); return }
        selection = service.createTask(workspace: folder)
        composerFocused = true
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
