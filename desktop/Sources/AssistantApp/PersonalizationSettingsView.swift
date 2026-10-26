import SwiftUI
import AppKit
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct PersonalizationSettingsView: View {
    @ObservedObject var service: TaskService
    @Environment(\.dismiss) private var dismiss
    @State private var instructions = ""
    @State private var soulDraft = ""
    @State private var editingSoul = false
    @State private var feedback: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("个性化").font(.system(size: 22, weight: .semibold))
                Text("分别设定做事规则与表达风格。").font(.callout).foregroundColor(.secondary)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("个性化内容", selection: $editingSoul) {
                        Text("自定义指令").tag(false)
                        Text("Soul · 表达风格").tag(true)
                    }.pickerStyle(.segmented).onChange(of: editingSoul) { _ in feedback = nil }
                    Text(editingSoul ? "例如：表达温和、直接，少用客套话。Soul 定义性格与表达风格；冲突时自定义指令优先。" : "例如：先给结论；修改代码后运行相关检查。当前任务的明确要求和具体项目约束优先，设定不会扩大工具权限。")
                        .font(.caption).foregroundColor(.secondary)
                    TextEditor(text: editingSoul ? $soulDraft : $instructions).font(.body).frame(minHeight: 200)
                        .padding(6).background(WorkspaceStyle.canvas, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(WorkspaceStyle.border))
                        .accessibilityLabel(editingSoul ? "Soul 编辑器" : "自定义指令编辑器")
                    HStack {
                        Button("清空草稿") {
                            if editingSoul { soulDraft = "" } else { instructions = "" }
                            failed = false; feedback = "草稿已清空，保存后生效。"
                        }
                        Button("还原已保存内容") {
                            if editingSoul { soulDraft = service.soul } else { instructions = service.customInstructions }
                            feedback = nil
                        }
                        Spacer()
                        Text("\((editingSoul ? soulDraft : instructions).utf8.count) / 32768 字节").font(.caption2).foregroundColor(.secondary)
                    }
                    if editingSoul {
                        HStack {
                            Button("导入 SOUL.md…") { importSoul() }
                            Button("导出已保存的 Soul…") { exportSoul() }
                        }
                        Text("导入只填入草稿，保存前不生效；不会执行文件中的脚本或加载资源。导出仅包含已保存的 Soul，不包含未保存草稿。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text("保存在本机，保存后下一次发送生效，包括继续已有任务。正在运行的请求保持原设定。相关内容会发送给你选择的模型服务。上限 32 KiB UTF-8 文本。")
                        .font(.caption).foregroundColor(.secondary)
                    if let message = feedback ?? service.personalizationError {
                        Label(message, systemImage: failed ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.callout).foregroundColor(failed ? .red : .secondary).textSelection(.enabled)
                    }
                }.padding(24)
            }
            Divider()
            HStack {
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(editingSoul ? "保存 Soul" : "保存自定义指令") {
                    do {
                        if editingSoul { try service.saveSoul(soulDraft) } else { try service.saveCustomInstructions(instructions) }
                        failed = false; feedback = "已保存，下次发送生效。"
                    }
                    catch { failed = true; feedback = "保存失败：" + error.localizedDescription }
                }.buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
            }.padding(20)
        }.frame(width: 540, height: min(660, (NSScreen.main?.visibleFrame.height ?? 800) - 120))
            .tint(WorkspaceStyle.accent)
            .onAppear { instructions = service.customInstructions; soulDraft = service.soul }
    }

    private func importSoul() {
        let panel = NSOpenPanel()
        panel.title = "导入 Soul 到草稿"
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do { soulDraft = try service.importSoul(from: file); failed = false; feedback = "已导入草稿，请检查后保存。" }
        catch { failed = true; feedback = "导入失败：" + error.localizedDescription }
    }

    private func exportSoul() {
        let panel = NSSavePanel()
        panel.title = "导出已保存的 Soul"
        panel.nameFieldStringValue = "SOUL.md"
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do { try service.exportSoul(to: file); failed = false; feedback = "已导出已保存的 Soul。" }
        catch { failed = true; feedback = "导出失败：" + error.localizedDescription }
    }
}
