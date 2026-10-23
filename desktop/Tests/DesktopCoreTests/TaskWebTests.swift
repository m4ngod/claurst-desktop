import Foundation
import Combine
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskWebTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/web_server.py").path]
        let output = Pipe(); fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appendingPathComponent("settings")
        let executable = root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime")
        let service = TaskService(executable: executable, storageDirectory: settings)
        defer { service.shutdown() }
        // The HTTP fixture is the explicit external-network boundary. Local
        // network access goes through the same visible authorization as users.
        let observation = service.$tasks.sink { tasks in
            for task in tasks {
                for permission in task.permissions {
                    Task { @MainActor in service.answerPermission(taskID: task.id, requestID: permission.id, allow: true) }
                }
            }
        }
        defer { observation.cancel() }
        let configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        // A real tool result is larger than several pipe reads. Independent
        // MainActor tasks once reordered these chunks and broke JSON / UTF-8.
        for _ in 1...12 {
            let largeID = service.createTask(workspace: directory)
            await service.send(taskID: largeID, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/large-message\",\"limit\":400}", configuration: configuration)
            let large = service.tasks.first { $0.id == largeID }!
            try check(large.status == .completed && large.webSources.count == 1 && large.tools.first?.status == "完成"
                && large.webSources.first?.lastLine == 400
                && large.webSources.first?.excerpt.hasSuffix("400\t第 400 段：银杏项目预算 73 元，这是用于核对协议传输顺序的合成材料。\n") == true
                && large.messages.last?.text.contains("第 400 段：银杏项目预算 73 元") == true,
                "multi-chunk tool output and model echo must stay ordered and preserve UTF-8: \(large.status), \(large.error ?? ""), \(large.tools.map(\.status))")
        }
        if CommandLine.arguments.contains("--large-only") { print("PASS: twelve large tool results and model echoes preserve ordered UTF-8"); return }
        let escapedKey = #"fixture/quote"slash\end"#
        let privacyConfiguration = ModelConfiguration(endpoint: configuration.endpoint, model: configuration.model, apiKey: escapedKey, isTest: true)
        let privacyID = service.createTask(workspace: directory)
        await service.send(taskID: privacyID, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/privacy\"}", configuration: privacyConfiguration)
        let privacy = service.tasks.first { $0.id == privacyID }!
        try check(privacy.status == .completed && privacy.webSources.first?.title == "[密钥已隐藏]"
            && privacy.webSources.first?.excerpt == "1\t[密钥已隐藏]\n"
            && privacy.messages.last?.text.contains(escapedKey) == false,
            "escaped synthetic credentials must be hidden in source fields and messages")
        if CommandLine.arguments.contains("--privacy-only") { print("PASS: escaped synthetic credentials redacted"); return }
        let cancelID = service.createTask(workspace: directory)
        let cancelling = Task { await service.send(taskID: cancelID, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/slow-cancel\"}", configuration: configuration) }
        var requestStarted = false
        let startDeadline = Date().addingTimeInterval(10)
        while !requestStarted && Date() < startDeadline {
            let (data, _) = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:\(port)/started")!)
            requestStarted = String(decoding: data, as: UTF8.self) == "yes"
            if !requestStarted { try await Task.sleep(nanoseconds: 20_000_000) }
        }
        try check(requestStarted, "cancellation regression must reach the actual HTTP request")
        let stopTime = Date()
        service.stop(taskID: cancelID)
        await cancelling.value
        let cancelled = service.tasks.first { $0.id == cancelID }!
        try check(cancelled.status == .stopped && cancelled.webSources.isEmpty && Date().timeIntervalSince(stopTime) < 2,
            "Stop must cancel pending HTTP promptly without late evidence: \(cancelled.status), sources \(cancelled.webSources.count)")
        if CommandLine.arguments.contains("--cancel-only") { print("PASS: pending HTTP cancelled without late evidence"); return }
        let id = service.createTask(workspace: directory)
        await service.send(taskID: id, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/article\"}", configuration: configuration)
        let task = service.tasks.first { $0.id == id }!
        try check(task.status == .completed && task.tools.count == 1 && task.tools[0].status == "完成",
            "web reading must complete through the task service: \(task.tools.map(\.output))")
        try check(task.messages.last?.text.contains("预算：73 元") == true && task.messages.last?.text.contains("脚本伪造数据") == false,
            "model must receive actual static page content without scripts: \(task.messages.last?.text ?? "")")
        try check(task.webSources.count == 1 && task.sources.isEmpty, "web evidence must be recorded separately from local files")
        let source = task.webSources[0]
        try check(source.title == "银杏 & 预算" && source.url.absoluteString == "http://127.0.0.1:\(port)/article",
            "source must use the actual response title and URL")
        try check(source.firstLine == 1 && source.lastLine == 3 && source.totalLines == 3
            && source.excerpt == "1\t银杏项目\n2\t预算：73 元\n3\t核对码：WEB-731\n", "source must locate the actual read content")
        try check(ISO8601DateFormatter().date(from: source.retrievedAt) != nil
            && task.messages.last?.text.contains(source.reference) == true, "model receives the recorded source reference and access time")
        // Pagination is a fresh HTTP read with its own dated evidence record.
        let page = service.createTask(workspace: directory)
        await service.send(taskID: page, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/article\",\"offset\":2,\"limit\":1}", configuration: configuration)
        let pageSource = service.tasks.first { $0.id == page }?.webSources.first
        try check(pageSource?.firstLine == 2 && pageSource?.lastLine == 2 && pageSource?.totalLines == 3
            && pageSource?.excerpt == "2\t预算：73 元\n" && pageSource?.id != source.id,
            "partial reading must locate only returned lines without claiming the whole page")
        for (path, expected) in [("missing", "HTTP 404"), ("empty", "没有可提取"), ("large", "2 MiB"), ("binary", "内容类型"), ("slow", "超时")] {
            let failed = service.createTask(workspace: directory)
            await service.send(taskID: failed, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/\(path)\"}", configuration: configuration)
            let result = service.tasks.first { $0.id == failed }!
            try check(result.status == .failed && result.webSources.isEmpty && result.tools.first?.output.contains(expected) == true,
                "unreadable responses must fail without evidence: \(path): \(result.tools.map(\.output))")
        }
        observation.cancel()
        let denied = service.createTask(workspace: directory)
        let pending = Task { await service.send(taskID: denied, text: "fetch-fixture:{\"url\":\"http://127.0.0.1:\(port)/article\"}", configuration: configuration) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks.first(where: { $0.id == denied })?.permissions.isEmpty == true && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        guard let permission = service.tasks.first(where: { $0.id == denied })?.permissions.first else { throw NSError(domain: "TaskWebTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "private network read must request authorization"]) }
        service.answerPermission(taskID: denied, requestID: permission.id, allow: false)
        await pending.value
        try check(service.tasks.first { $0.id == denied }?.webSources.isEmpty == true && service.tasks.first { $0.id == denied }?.status == .failed,
            "refused private-network access must not produce a source")
        if CommandLine.arguments.contains("--live-web") {
            let live = service.createTask(workspace: directory)
            await service.send(taskID: live, text: #"fetch-fixture:{"url":"https://docs.searxng.org/dev/search_api.html","limit":400}"#, configuration: configuration)
            let result = service.tasks.first { $0.id == live }!
            try check(result.status == .completed && result.webSources.first?.title?.contains("Search API") == true
                && result.webSources.first?.excerpt.contains("403 Forbidden") == true,
                "real public webpage content must be read and located: \(result.status) / \(result.error ?? "") / \(result.tools.map { $0.status + ":" + $0.output })")
            print("PASS: real SearXNG documentation read and 403 format rule verified")
        }
        service.shutdown()
        let reopened = TaskService(executable: executable, storageDirectory: settings)
        defer { reopened.shutdown() }
        try check(reopened.tasks.first { $0.id == privacyID }?.webSources.first?.excerpt == "1\t[密钥已隐藏]\n",
            "history must preserve redaction of escaped synthetic credentials")
        let restored = reopened.tasks.first { $0.id == id }
        try check(restored?.webSources.first?.id == source.id && restored?.webSources.first?.excerpt == source.excerpt
            && restored?.recoveryWarnings.isEmpty == true, "history preserves web evidence without checking it as a local file")
        print("PASS: located webpage content and history through TaskService")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskWebTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
