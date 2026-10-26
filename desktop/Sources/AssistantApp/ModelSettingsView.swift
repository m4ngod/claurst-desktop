import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct ModelSettingsView: View {
    @ObservedObject var service: TaskService
    @Binding var activeProfileID: UUID?
    var workspace: URL?
    @State private var section = "模型服务"

    var body: some View {
        VStack(spacing: 0) {
            Picker("设置分区", selection: $section) {
                Text("模型服务").tag("模型服务")
                Text("个性化").tag("个性化")
                Text("记忆").tag("记忆")
            }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.top, 20)
            if section == "模型服务" { ModelConnectionView(service: service, activeProfileID: $activeProfileID) }
            else if section == "个性化" { PersonalizationSettingsView(service: service) }
            else { MemorySettingsView(service: service, workspace: workspace) }
        }.background(WorkspaceStyle.surface)
    }
}

@MainActor private struct ModelConnectionView: View {
    @ObservedObject var service: TaskService
    @Binding var activeProfileID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var endpoint = ""
    @State private var model = ""
    @State private var key = ""
    @State private var clearKey = false
    @State private var webSearchEnabled = false
    @State private var message: String?
    @State private var checking = false
    private var profile: ModelProfile? { service.modelProfiles.first { $0.id == editingID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("模型设置").font(.system(size: 22, weight: .semibold))
                Text("连接你选择的模型服务。密钥保存在本机钥匙串。")
                    .font(.callout).foregroundColor(.secondary)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("服务配置", symbol: "server.rack")
                        Picker("选择配置", selection: $editingID) {
                            Text("添加服务").tag(nil as UUID?)
                            ForEach(service.modelProfiles) { Text($0.name).tag(Optional($0.id)) }
                        }.onChange(of: editingID) { id in load(id) }.disabled(checking)
                        field("配置名称") { TextField("例如：日常助手", text: $name) }
                        field("服务地址") { TextField("OpenAI 兼容地址，包含 /v1 等路径", text: $endpoint) }
                        field("模型名称") { TextField("填写服务提供的非 Claude 模型名称", text: $model) }
                        field("API Key") {
                            SecureField(editingID == nil ? "本机服务可留空" : "留空则保留已有密钥", text: $key).disabled(clearKey)
                        }
                        if editingID != nil {
                            Toggle("清除已有密钥（用于不需要密钥的服务）", isOn: $clearKey).font(.caption).disabled(checking)
                        }
                        Text("服务地址、模型和密钥的修改适用于新任务。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("联网搜索", symbol: "globe")
                        Toggle("使用当前服务的 Responses API", isOn: $webSearchEnabled).font(.callout).foregroundColor(.primary).disabled(checking)
                        Text("仅适用于支持 web_search 的服务，沿用上方地址、模型和密钥。开启后，检索词会发送到该服务及其搜索提供方，并按服务规则消耗额度；不会自动切换其他服务。关闭后仍可直接读取指定公开网页。")
                        Text("搜索开关在下一次发送任务时生效，运行中的请求可点停止取消。搜索能力请在任务中实际验证，未返回搜索记录时会明确报错。")
                    }.font(.caption).foregroundColor(.secondary)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("隐私与连接检查", symbol: "lock.shield")
                        Text("任务要求、对话及工具实际读取的相关内容会发给所选服务；图像仅在相关功能启用时发送。选择文件夹不会自动上传整个目录。")
                        Text("连接检查验证文本、工具与图像，会发送生成的随机色块图片，不包含用户文件。通过检查只证明该次图像输入有效，不保证识别准确。")
                        if let profile {
                            HStack(spacing: 8) {
                                capability("文本", profile.textCapability)
                                capability("工具", profile.toolCapability)
                                capability("图像", profile.imageCapability)
                            }.padding(.top, 4)
                            if let details = profile.checkDetails { Text(details).textSelection(.enabled) }
                            if let date = profile.checkedAt {
                                Text("检查于 \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption2)
                            }
                        }
                    }.font(.caption).foregroundColor(.secondary)
                    if checking {
                        Label("正在访问模型配置；若系统弹出钥匙串提示，请在系统窗口中处理。", systemImage: "hourglass")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if let error = message ?? service.settingsError {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundColor(.red).textSelection(.enabled)
                    }
                }.fixedSize(horizontal: false, vertical: true).padding(24)
            }
            Divider()
            HStack {
                Button(checking ? "正在检查…" : "保存并检查连接") {
                    checking = true
                    Task {
                        defer { checking = false }
                        guard let id = await save() else { return }
                        do { try await service.checkModelProfile(id: id) }
                        catch { message = error.localizedDescription }
                    }
                }.disabled(checking)
                Spacer()
                Button("取消") { dismiss() }.disabled(checking).keyboardShortcut(.cancelAction)
                Button("保存") {
                    checking = true
                    Task {
                        defer { checking = false }
                        if await save() != nil { dismiss() }
                    }
                }.buttonStyle(.borderedProminent).disabled(checking).keyboardShortcut("s", modifiers: .command)
            }.controlSize(.regular).padding(20)
        }.textFieldStyle(.roundedBorder).background(WorkspaceStyle.surface)
            .frame(width: 540, height: min(660, (NSScreen.main?.visibleFrame.height ?? 800) - 80))
            .tint(WorkspaceStyle.accent)
            .onAppear { editingID = activeProfileID ?? service.modelProfiles.first?.id; load(editingID) }
            .onDisappear { key = "" }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium))
            content().accessibilityLabel(title).disabled(checking)
        }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
    }

    private func capability(_ name: String, _ state: CapabilityState) -> some View {
        Label("\(name)：\(state.rawValue)", systemImage: state == .verified ? "checkmark.circle" : "circle.dotted")
            .font(.caption).foregroundColor(.primary).padding(7)
            .background(WorkspaceStyle.subtle.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
    }
    private func load(_ id: UUID?) {
        guard let stored = service.modelProfiles.first(where: { $0.id == id }) else {
            name = ""; endpoint = ""; model = ""; key = ""; clearKey = false; webSearchEnabled = false; message = nil
            return
        }
        name = stored.name; endpoint = stored.endpoint; model = stored.model
        webSearchEnabled = stored.webSearchEnabled == true
        key = ""; clearKey = false; message = nil; activeProfileID = stored.id
    }
    private func save() async -> UUID? {
        do {
            var secret = key
            if !clearKey && key.isEmpty, let id = editingID {
                secret = try await service.modelConfiguration(profileID: id).apiKey
            }
            if clearKey { secret = "" }
            let configuration = ModelConfiguration(endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                model: model.trimmingCharacters(in: .whitespacesAndNewlines), apiKey: secret, webSearchEnabled: webSearchEnabled)
            let saved = try await service.saveModelProfile(id: editingID, name: name, configuration: configuration)
            editingID = saved.id; activeProfileID = saved.id; key = ""; message = nil
            return saved.id
        } catch { message = error.localizedDescription; return nil }
    }
}
