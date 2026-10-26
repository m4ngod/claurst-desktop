import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct MemorySettingsView: View {
    @ObservedObject var service: TaskService
    var workspace: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var feedback: String?
    @State private var editing: SavedMemory?
    @State private var clearScope: MemoryClearScope = .personal
    @State private var confirmClear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("已保存记忆").font(.system(size: 22, weight: .semibold))
                Toggle("自动整理并使用记忆", isOn: Binding(get: { service.memoryEnabled }, set: { value in
                    do { try service.setMemoryEnabled(value); feedback = value ? "已开启，只整理之后的新轮次。" : "已关闭，已有记忆保留。" }
                    catch { feedback = "更新失败：" + error.localizedDescription }
                }))
                Text("默认关闭。开启后，成功完成的普通任务会由所选模型自动整理，无需逐条审批；这会增加模型调用用量。记忆保存在本机，使用时发送给所选服务。")
                    .font(.caption).foregroundColor(.secondary)
            }.padding(24)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("关闭、编辑或删除会影响后续请求，并作废尚未结束的整理。已发送的请求和可见聊天中的文字无法撤回；可停止当前任务并新建会话。")
                        .font(.caption).foregroundColor(.secondary)
                    Text("首版跨工作区共享明确的回答语言、详略和格式偏好；无法确定为通用偏好的内容留在当前工作区。")
                        .font(.caption).foregroundColor(.secondary)
                    Text(workspace.map { "个人偏好与当前工作区：" + $0.lastPathComponent } ?? "未选择工作区，仅显示个人偏好")
                        .font(.callout).foregroundColor(.secondary)
                    if let workspace { Text(workspace.path).font(.caption2).foregroundColor(.secondary).textSelection(.enabled) }
                    if service.memories(in: workspace).isEmpty {
                        Text("还没有已保存记忆").font(.headline)
                        Text("开启后从新完成的任务整理，不查找或回填旧聊天。").foregroundColor(.secondary)
                    }
                    ForEach(service.memories(in: workspace)) { memory in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(memory.content).textSelection(.enabled)
                            Text("\(memory.scope == "personal" ? "个人偏好 · 全局" : "项目事实 · 当前工作区") · \(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundColor(.secondary)
                            Text("来源：\(service.memorySource(memory))")
                                .font(.caption).foregroundColor(.secondary)
                            if memory.manuallyEdited { Label("已手动更正", systemImage: "pencil").font(.caption) }
                            HStack {
                                Button("编辑") { editing = memory }
                                Button("删除这条记忆", role: .destructive) {
                                    do { try service.deleteMemory(id: memory.id); feedback = "已删除，后续请求不再引用。" }
                                    catch { feedback = "删除失败：" + error.localizedDescription }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                            .background(WorkspaceStyle.canvas, in: RoundedRectangle(cornerRadius: 8))
                    }
                    Divider()
                    Picker("清空范围", selection: $clearScope) {
                        Text("个人偏好").tag(MemoryClearScope.personal)
                        if workspace != nil { Text("当前工作区").tag(MemoryClearScope.workspace) }
                        Text("全部记忆（含其他工作区）").tag(MemoryClearScope.all)
                    }
                    Button("清空\(clearScope.rawValue)…", role: .destructive) { confirmClear = true }
                        .disabled(service.memoryCount(scope: clearScope, workspace: workspace) == 0)
                    if let text = feedback ?? service.memoryError { Text(text).font(.callout).textSelection(.enabled) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
            Divider()
            HStack { Spacer(); Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(20)
        }.frame(width: 540, height: min(660, (NSScreen.main?.visibleFrame.height ?? 800) - 120)).tint(WorkspaceStyle.accent)
            .sheet(item: $editing) { MemoryEditView(service: service, memory: $0) }
            .confirmationDialog("清空\(clearScope.rawValue)？", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清空\(clearScope.rawValue)", role: .destructive) {
                    do { try service.clearMemories(scope: clearScope, workspace: workspace); feedback = "已清空\(clearScope.rawValue)。" }
                    catch { feedback = "清空失败：" + error.localizedDescription }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将删除 \(service.memoryCount(scope: clearScope, workspace: workspace)) 条\(clearScope == .all ? "记忆，包括其他工作区" : clearScope.rawValue)。聊天历史、自定义指令、Soul 和项目文件保留。此操作无法撤销。")
            }
    }
}

@MainActor private struct MemoryEditView: View {
    @ObservedObject var service: TaskService
    let memory: SavedMemory
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("更正记忆").font(.title2)
            Text(memory.scope == "personal" ? "个人偏好 · 全局" : "项目事实 · 当前工作区").foregroundColor(.secondary)
            TextEditor(text: $text).frame(height: 180).accessibilityLabel("记忆内容")
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(WorkspaceStyle.border))
            Text("保存后影响后续请求。自动整理会跳过与手动更正冲突的候选，不静默覆盖。最多 1024 字节。")
                .font(.caption).foregroundColor(.secondary)
            if let error { Text(error).font(.caption).foregroundColor(.red) }
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存更正") {
                    do { try service.editMemory(id: memory.id, content: text); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
            }
        }.padding(24).frame(width: 460).onAppear { text = memory.content }
    }
}
