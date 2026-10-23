import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

/// Explicit opt-in only: uses profiles saved by the user, never accepts a key on argv.
@main struct LiveModelChecks {
    @MainActor static func main() async throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), allowKeychainUI: false)
        defer { service.shutdown() }
        let workspace = root.appendingPathComponent(".build-tools/live-model-sample")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try "# 验证素材\n项目代号：银杏\n预算：73 元\n".write(to: workspace.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        for profile in service.modelProfiles where !profile.isTest {
            if CommandLine.arguments.contains("--write") {
                let directory = workspace.appendingPathComponent("write-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let budget = directory.appendingPathComponent("budget.md")
                let output = directory.appendingPathComponent("result.txt")
                try "# 项目\n预算：73 元\n".write(to: budget, atomically: true, encoding: .utf8)
                let task = service.createTask(workspace: directory)
                await service.send(taskID: task, text: "这是文件写入验收。请先 Read budget.md，再通过 Write 将预算从 73 元改为 80 元，保留标题和其他格式；Write 的 content 必须恰好为 JSON 字符串 \"# 项目\\n预算：80 元\\n\"。然后用 Write 新建 result.txt，content 必须恰好为 JSON 字符串 \"银杏：80 元\\n\"。这里的 \\n 表示真实换行，两个文件最后都要保留一个换行。result.txt 尚不存在，直接创建，不必先读取。两次写入都成功后简短报告结果。", profileID: profile.id)
                guard let result = service.tasks.first(where: { $0.id == task }),
                      result.status == .completed,
                      try String(contentsOf: budget) == "# 项目\n预算：80 元\n",
                      try String(contentsOf: output) == "银杏：80 元\n",
                      result.changes.count == 2,
                      result.changes.contains(where: { $0.file.resolvingSymlinksInPath() == budget.resolvingSymlinksInPath() && $0.before == "# 项目\n预算：73 元\n" && $0.diff.contains("-预算：73 元") && $0.diff.contains("+预算：80 元") }) else {
                    let result = service.tasks.first(where: { $0.id == task })
                    print("\(profile.name) | 写入验收失败 | \(result?.status.rawValue ?? "无任务") | \(result?.error ?? "内容或差异不匹配")")
                    for tool in result?.tools ?? [] { print("工具：\(tool.title) | \(tool.status) | \(tool.output)") }
                    throw NSError(domain: "LiveModelChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "真实模型写入验收未通过"])
                }
                print("\(profile.name) | 写入通过 | 创建与覆盖的磁盘内容、差异、修改前版本均匹配 | 工作文件夹：\(directory.path)")
                continue
            }
            do {
                let checked = try await service.checkModelProfile(id: profile.id)
                print("\(profile.name) | \(profile.model) | 文本：\(checked.textCapability.rawValue) | \(checked.checkDetails ?? "")")
                let task = service.createTask(workspace: workspace)
                await service.send(taskID: task, text: "请调用 Read 读取 notes.md，告诉我项目代号和预算，并引用文件路径与行号。不要猜测。", profileID: profile.id)
                if let result = service.tasks.first(where: { $0.id == task }) {
                    print("\(profile.name) | 读取任务：\(result.status.rawValue) | \(result.messages.last?.text ?? "") | \(result.error ?? "")")
                    for tool in result.tools { print("工具：\(tool.title) | \(tool.status) | \(tool.output)") }
                    print("已验证来源数：\(result.sources.count)")
                }
            } catch { print("\(profile.name) | 检查失败：\(error.localizedDescription)") }
        }
    }
}
