import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import DesktopCore
#endif

/// Shared surfaces retain the warm workspace while following system appearance.
enum WorkspaceStyle {
    static let canvas = adaptive("canvas", light: 0xFAF9F6, dark: 0x232321)
    static let sidebar = adaptive("sidebar", light: 0xF0EFEB, dark: 0x1D1D1C)
    static let surface = adaptive("surface", light: 0xFFFFFF, dark: 0x2B2B29)
    static let subtle = adaptive("subtle", light: 0xEAE8E2, dark: 0x353532)
    static let accent = adaptive("accent", light: 0xA45138, dark: 0xE1A08A)
    static let border = Color.primary.opacity(0.12)

    private static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Claurst.\(name)")) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}

/// Color feedback is immediate, including for keyboard activation and Reduce Motion.
struct WorkspaceButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        WorkspaceButtonBody(configuration: configuration, selected: selected)
    }
}

private struct WorkspaceButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovered = false

    var body: some View {
        configuration.label
            .padding(.horizontal, 9).padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(RoundedRectangle(cornerRadius: 7).fill(
                configuration.isPressed ? Color.primary.opacity(0.13) :
                    (selected || (hovered && enabled) ? Color.primary.opacity(0.065) : .clear)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(
                selected ? WorkspaceStyle.accent.opacity(contrast == .increased ? 0.9 : 0.25) : .clear))
            .opacity(enabled ? 1 : 0.45)
            .onHover { hovered = $0 }
    }
}

struct TaskStatusLabel: View {
    let status: TaskStatus
    var compact = false
    private var symbol: String {
        switch status {
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        case .stopped, .stopping: return "pause.circle"
        case .waiting, .answering: return "person.crop.circle.badge.questionmark"
        case .running, .preparing: return "circle.dotted"
        case .elsewhere: return "macwindow"
        case .ready: return "circle"
        }
    }
    private var color: Color {
        switch status {
        case .failed: return .red
        case .waiting, .answering, .running, .preparing: return WorkspaceStyle.accent
        default: return .secondary
        }
    }
    var body: some View {
        Label(status.rawValue, systemImage: symbol)
            .font(.system(size: compact ? 11 : 12))
            .foregroundColor(color).lineLimit(1)
            .accessibilityElement(children: .combine)
    }
}

struct WorkspaceActions {
    var newTask: () -> Void
    var chooseFolder: () -> Void
    var focusComposer: () -> Void
    var settings: () -> Void
    var toggleTasks: () -> Void
    var toggleArtifacts: () -> Void
}

private struct WorkspaceActionsKey: FocusedValueKey {
    typealias Value = WorkspaceActions
}

extension FocusedValues {
    var workspaceActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.workspaceActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新任务") { actions?.newTask() }.keyboardShortcut("n", modifiers: .command).disabled(actions == nil)
            Button("新窗口") { openWindow(id: "workspace") }.keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .appSettings) {
            Button("模型设置…") { actions?.settings() }.keyboardShortcut(",", modifiers: .command).disabled(actions == nil)
        }
        CommandMenu("任务") {
            Button("选择工作文件夹…") { actions?.chooseFolder() }.keyboardShortcut("o", modifiers: [.command, .shift])
            Button("输入任务要求") { actions?.focusComposer() }.keyboardShortcut("l", modifiers: .command)
            Divider()
            Button("任务列表") { actions?.toggleTasks() }.keyboardShortcut("s", modifiers: [.control, .command])
            Button("素材与成果") { actions?.toggleArtifacts() }.keyboardShortcut("i", modifiers: [.control, .command])
        }
    }
}
