import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

@MainActor struct ChangePreview: View {
    @ObservedObject var service: TaskService
    let taskID: UUID
    let initialChange: FileChange
    @Environment(\.dismiss) private var dismiss
    @State private var openError: String?
    private var task: DesktopTask? { service.tasks.first { $0.id == taskID } }
    private var change: FileChange { task?.changes.first { $0.id == initialChange.id } ?? initialChange }
    private var currentFile: URL { change.restoredAt == nil ? change.file : (change.originalFile ?? change.file) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(change.summary + " · " + change.file.lastPathComponent).font(.headline)
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(change.file.path).font(.caption).textSelection(.enabled)
                Text("修改原因（助手说明）：" + (change.reason ?? "未提供")).font(.callout).textSelection(.enabled)
                Text("− 为修改前内容，+ 为修改后内容").foregroundColor(.secondary)
            }
            ScrollView([.horizontal, .vertical]) {
                Text(change.diff.isEmpty ? "文件内容未发生变化" : change.diff)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).frame(minHeight: 240)
                .background(WorkspaceStyle.canvas, in: RoundedRectangle(cornerRadius: 8))
            Text("恢复前会核对当前内容与路径，冲突时保留当前文件。支持普通文件的移动、删除和文本修改；单文件恢复上限 32 MiB。外部命令、文件夹和符号链接不支持恢复。")
                .font(.caption).foregroundColor(.secondary)
            if let restoredAt = change.restoredAt {
                Text("已恢复 · " + restoredAt.formatted()).font(.caption).foregroundColor(.secondary)
            }
            if let error = change.restoreError { Text(error).font(.caption).foregroundColor(.red).textSelection(.enabled) }
            ForEach(task?.permissions ?? []) { permission in
                VStack(alignment: .leading, spacing: 8) {
                    Text(permission.description).textSelection(.enabled)
                    Text("此恢复在本地执行；越界授权仅限本次操作。").font(.caption)
                    HStack {
                        Button("拒绝") { service.answerPermission(taskID: taskID, requestID: permission.id, allow: false) }
                        Button("仅允许这一次") { service.answerPermission(taskID: taskID, requestID: permission.id, allow: true) }
                    }
                }
            }
            if let openError { Text(openError).font(.caption).foregroundColor(.red) }
            HStack {
                Button(change.restoredAt == nil ? "恢复本次修改" : "已恢复") {
                    let id = change.id
                    Task { await service.restoreChange(taskID: taskID, changeID: id) }
                }.disabled(change.restoredAt != nil || task?.status.isActive == true)
                Button("查看恢复材料") { NSWorkspace.shared.activateFileViewerSelecting([change.record]) }
                Spacer()
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([currentFile]) }
                Button("打开文件") {
                    openError = NSWorkspace.shared.open(currentFile) ? nil : "无法打开文件，请确认文件仍存在且有可用的打开应用。"
                }
            }
        }.padding(24).frame(minWidth: 560, minHeight: 360).background(WorkspaceStyle.surface)
    }
}
