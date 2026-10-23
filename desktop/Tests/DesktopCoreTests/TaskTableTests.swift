import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskTableTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe()
        fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(data: output.fileHandleForReading.availableData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/tables"), to: workspace)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let deadline = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 60_000_000_000); service.shutdown() }
            catch { }
        }
        defer { deadline.cancel() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        let id = service.createTask(workspace: workspace)
        await service.send(taskID: id, text: #"table-fixture:{"file_path":"sales.csv","action":"read"}"#, configuration: config)
        let result = service.tasks[0]
        try check(result.status == .completed && result.sources.count == 1, "CSV must produce actual structured cells: \(result.tools.map(\.output))")
        let source = result.sources[0]
        try check(source.excerpt.contains("A1") && source.excerpt.contains("区域") && source.excerpt.contains("10.25") && source.excerpt.contains("含,逗号"), "CSV header, number and quoted delimiter must survive parsing")
        try check(source.excerpt.contains("B5=缺失") && source.excerpt.contains("物理行 4") && source.excerpt.contains("物理行 6") && source.excerpt.contains("跨\\n行"), "missing values and multiline record positions must stay visible")
        let excelID = service.createTask(workspace: workspace)
        await service.send(taskID: excelID, text: #"table-fixture:{"file_path":"sales.xlsx","action":"read","sheet":"交易"}"#, configuration: config)
        let excel = service.tasks[0]
        try check(excel.status == .completed && excel.sources.count == 1, "Excel must produce an actual worksheet source: \(excel.tools.map(\.output))")
        let cells = excel.sources[0].excerpt
        try check(cells.contains("EXCEL-731") && cells.contains("B2=10.25") && cells.contains("B5=缺失"), "Excel must preserve numeric cells and missing values")
        try check(cells.contains("B2*2") && cells.contains("20.5") && cells.contains("未重新计算") && cells.contains("UNSUPPORTED(B3)"), "formula text and cached/missing values must be marked as uncalculated")
        try check(excel.sources[0].tableLocation?.sheet == "交易", "actual worksheet name must reach the sidebar")
        for (file, sheet) in [("sales.csv", ""), ("sales.xlsx", "交易")] {
            let original = try Data(contentsOf: workspace.appendingPathComponent(file))
            let statisticsID = service.createTask(workspace: workspace)
            var arguments: [String: Any] = ["file_path": file, "action": "group_sum", "group_column": "A", "value_column": "B"]
            if !sheet.isEmpty { arguments["sheet"] = sheet }
            let payload = String(data: try JSONSerialization.data(withJSONObject: arguments), encoding: .utf8)!
            await service.send(taskID: statisticsID, text: "table-fixture:" + payload, configuration: config)
            let calculated = service.tasks[0]
            try check(calculated.status == .completed && calculated.sources.count == 1, "actual group statistics must succeed: \(calculated.tools.map(\.output))")
            let report = calculated.sources[0].excerpt
            try check(report.contains("组 \"华东\"：合计=13；有效数=2；缺失数=0") && report.contains("组 \"华西\"：合计=7；有效数=1；缺失数=1"), "group totals must match independently worked 10.25 + 2.75 = 13 and 7 with one missing")
            try check(report.contains("十进制") && report.contains("A2:A5") && report.contains("B2:B5") && report.contains("B5") && report.contains("SHA-256"), "calculation must retain method, source ranges, missing cells and input identity")
            try check(try Data(contentsOf: workspace.appendingPathComponent(file)) == original, "analysis must not change the original input")
        }
        let failures: [(String, String, String)] = [
            ("unclosed.csv", "read", "CSV 解析失败"),
            ("ragged.csv", "read", "CSV 解析失败"),
            ("invalid-utf8.csv", "read", "CSV 解析失败"),
            ("broken.xlsx", "read", "损坏"),
            ("precision.xlsx", "read", "数值精度"),
            ("array-formula.xlsx", "read", "数组公式"),
            ("non-numeric.csv", "group_sum", "B2"),
            ("missing-group.csv", "group_sum", "A2")
        ]
        for (file, action, expected) in failures {
            var arguments: [String: Any] = ["file_path": file, "action": action]
            if action == "group_sum" { arguments["group_column"] = "A"; arguments["value_column"] = "B" }
            let payload = String(data: try JSONSerialization.data(withJSONObject: arguments), encoding: .utf8)!
            let failedID = service.createTask(workspace: workspace)
            await service.send(taskID: failedID, text: "table-fixture:" + payload, configuration: config)
            try check(service.tasks[0].status == .failed && service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains(expected), "\(file) must fail visibly without a fabricated source/result: \(service.tasks[0].tools.map(\.output))")
        }
        let expansionID = service.createTask(workspace: workspace)
        await service.send(taskID: expansionID, text: #"table-fixture:{"file_path":"shared-expansion.xlsx","action":"read","limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains("文字数据超过"), "shared string references must not bypass the expanded content budget even for a short read")
        let formulaID = service.createTask(workspace: workspace)
        await service.send(taskID: formulaID, text: #"table-fixture:{"file_path":"sales.xlsx","action":"group_sum","sheet":"交易","group_column":"A","value_column":"D"}"#, configuration: config)
        try check(service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains("D2 含公式") && service.tasks[0].tools[0].output.contains("不使用缓存"), "statistics must refuse formula cache as freshly calculated data")
        let secondSheetID = service.createTask(workspace: workspace)
        await service.send(taskID: secondSheetID, text: #"table-fixture:{"file_path":"sales.xlsx","action":"read","sheet":"说明","offset":3,"limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.first?.tableLocation?.sheet == "说明" && service.tasks[0].sources[0].tableLocation?.first_row == 3 && service.tasks[0].sources[0].excerpt.contains("B3=\"第二表：SHEET-418\""), "other worksheets and leading blank rows/columns must retain true coordinates")
        let partialID = service.createTask(workspace: workspace)
        await service.send(taskID: partialID, text: #"table-fixture:{"file_path":"sales.csv","action":"read","limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.first?.tableLocation?.last_row == 1 && service.tasks[0].sources[0].excerpt.contains("offset=2"), "partial table reads must expose continuation")
        await service.send(taskID: partialID, text: #"table-fixture:{"file_path":"sales.csv","action":"read","offset":2,"limit":1}"#, configuration: config)
        try check(service.tasks[0].sources.last?.tableLocation?.first_row == 2 && service.tasks[0].sources.last?.excerpt.contains("10.25") == true, "table continuation must preserve actual record coordinates")
        let outside = directory.appendingPathComponent("outside.xlsx")
        try FileManager.default.copyItem(at: workspace.appendingPathComponent("sales.xlsx"), to: outside)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("link.xlsx"), withDestinationURL: outside)
        let restrictedID = service.createTask(workspace: workspace)
        let pending = Task { await service.send(taskID: restrictedID, text: #"table-fixture:{"file_path":"link.xlsx","action":"read"}"#, configuration: config) }
        let permissionDeadline = Date().addingTimeInterval(10)
        while service.tasks[0].permissions.isEmpty && Date() < permissionDeadline { try await Task.sleep(nanoseconds: 20_000_000) }
        guard let permission = service.tasks[0].permissions.first else { throw NSError(domain: "TaskTableTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Outside workbook must request permission before parsing"]) }
        service.answerPermission(taskID: restrictedID, requestID: permission.id, allow: false)
        await pending.value
        try check(service.tasks[0].sources.isEmpty && !service.tasks[0].tools[0].output.contains("EXCEL-731"), "external table refusal must prevent extraction")
        let incompleteFolder = directory.appendingPathComponent("incomplete-install")
        try FileManager.default.createDirectory(at: incompleteFolder, withIntermediateDirectories: true)
        let incompleteRuntime = incompleteFolder.appendingPathComponent("claurst-desktop-runtime")
        try FileManager.default.copyItem(at: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), to: incompleteRuntime)
        let incomplete = TaskService(executable: incompleteRuntime, storageDirectory: directory.appendingPathComponent("missing-parser-settings"))
        defer { incomplete.shutdown() }
        let incompleteID = incomplete.createTask(workspace: workspace)
        await incomplete.send(taskID: incompleteID, text: #"table-fixture:{"file_path":"sales.csv","action":"group_sum","group_column":"A","value_column":"B"}"#, configuration: config)
        try check(incomplete.tasks[0].sources.isEmpty && incomplete.tasks[0].tools[0].output.contains("计算组件缺失") && incomplete.tasks[0].tools[0].output.contains("未执行统计"), "missing calculation component must not fabricate results")
        service.shutdown()
        let reopened = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        let saved = reopened.tasks.first { $0.id == secondSheetID }?.sources.first
        try check(saved?.tableLocation?.sheet == "说明" && saved?.tableLocation?.first_row == 3 && saved?.excerpt.contains("SHEET-418") == true, "table locations and snapshots must persist through reopening")
        print("PASS: tables through TaskService → ACP → actual parsing and calculation")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskTableTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
