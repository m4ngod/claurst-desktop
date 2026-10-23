import SwiftUI
#if SWIFT_PACKAGE
import DesktopCore
#endif

struct ProjectChecksView: View {
    let task: DesktopTask?
    private var checks: [ToolExecution] { task?.tools.filter { $0.check != nil } ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("项目检查").font(.headline)
            if checks.isEmpty {
                Text("未运行 · 尚无项目检查记录").font(.caption).foregroundColor(.secondary)
            }
            ForEach(checks) { tool in
                if let check = tool.check {
                    DisclosureGroup {
                        Text(tool.output.isEmpty ? "等待工具返回结果" : tool.output).font(.caption).textSelection(.enabled)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(check.name)
                            Text(check.state.label)
                                .font(.caption).foregroundColor(check.state == .failed ? .red : .secondary)
                        }
                    }
                }
            }
            Text("退出码仅反映整条命令，需核对输出；后续修改需重跑。任务结束不代表问题已验证解决。")
                .font(.caption2).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
