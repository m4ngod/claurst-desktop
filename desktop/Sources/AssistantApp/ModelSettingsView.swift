import SwiftUI
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct ModelSettingsView: View {
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
        VStack(alignment: .leading, spacing: 14) {
            ScrollView {
            VStack(alignment: .leading, spacing: 14) {
            Text("模型与隐私").font(.title2)
            Picker("服务配置", selection: $editingID) {
                Text("添加服务").tag(nil as UUID?)
                ForEach(service.modelProfiles) { Text($0.name).tag(Optional($0.id)) }
            }.onChange(of: editingID) { id in load(id) }.disabled(checking)
            Group {
            TextField("配置名称", text: $name)
            TextField("OpenAI 兼容服务地址，包含 /v1 等路径", text: $endpoint)
            TextField("非 Claude 模型名称", text: $model)
            SecureField(editingID == nil ? "API Key（本机服务可留空）" : "新 API Key（留空保留已有密钥）", text: $key).disabled(clearKey)
            }.disabled(checking)
            if editingID != nil { Toggle("清除已有密钥（用于不需要密钥的服务）", isOn: $clearKey).font(.caption).disabled(checking) }
            Group {
                Toggle("联网搜索：使用当前服务的 Responses API", isOn: $webSearchEnabled).disabled(checking)
                Text("仅适用于支持 web_search 的服务，沿用上方地址、模型和密钥。开启后检索词会发送到该服务及其搜索提供方，并按服务规则消耗额度；不会自动切换其他服务。关闭后仍可直接读取指定公开网页。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("连接检查验证文本、工具与图像；搜索请在任务中实际验证，未返回搜索记录时会明确报错。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Group {
            Text("密钥保存在 macOS 钥匙串。任务要求、对话及工具实际读取的相关内容会发给所选服务；图像仅在相关功能启用时发送。选择文件夹不会自动上传整个目录。")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("连接检查会发送生成的随机色块图片，不包含用户文件。通过检查只证明该次图像输入有效，不保证识别准确。")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("服务地址、模型和密钥的修改适用于新任务；搜索开关在下一次发送任务时生效，运行中的请求可点停止取消。")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let profile {
                HStack {
                    capability("文本", profile.textCapability)
                    capability("工具", profile.toolCapability)
                    capability("图像", profile.imageCapability)
                }
                if let details = profile.checkDetails { Text(details).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
                if let date = profile.checkedAt { Text("检查于 \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundColor(.secondary) }
            }
            if checking { Text("正在访问模型配置；若系统弹出钥匙串提示，请在系统窗口中处理。")
                .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let error = message ?? service.settingsError { Text(error).font(.caption).foregroundColor(.red).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            }
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
                Button("取消") { dismiss() }.disabled(checking)
                Button("保存") {
                    checking = true
                    Task {
                        defer { checking = false }
                        if await save() != nil { dismiss() }
                    }
                }.buttonStyle(.borderedProminent).disabled(checking)
            }
        }.textFieldStyle(.roundedBorder).padding(26).frame(width: 500, height: 560)
            .onAppear { editingID = activeProfileID ?? service.modelProfiles.first?.id; load(editingID) }
            .onDisappear { key = "" }
    }
    private func capability(_ name: String, _ state: CapabilityState) -> some View {
        Text("\(name)：\(state.rawValue)").font(.caption)
            .padding(6).background(state == .verified ? Color.green.opacity(0.10) : Color.gray.opacity(0.08)).cornerRadius(5)
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
