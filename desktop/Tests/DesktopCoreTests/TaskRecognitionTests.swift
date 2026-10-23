import Foundation
import Darwin
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskRecognitionTests {
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
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/scans"), to: workspace)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let config = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true)
        if CommandLine.arguments.contains("--active-cancel-only") {
            try await checkActiveCancellation(service: service, workspace: workspace, config: config)
            print("PASS: cancellation during real OCR model initialization; parser and cache removed")
            return
        }
        let task = service.createTask(workspace: workspace)
        await service.send(taskID: task, text: #"ocr-fixture:{"file_path":"printed.png"}"#, configuration: config)
        let result = service.tasks[0]
        try check(result.status == .completed && result.sources.count == 1, "actual local image OCR must produce a source: \(result.tools.map(\.output))")
        let source = result.sources[0]
        try check(["银杏", "SCAN-731", "73", "13.25", "7.50"].allSatisfy { source.excerpt.contains($0) }, "printed words and table numbers must come from the real pixels")
        try check(source.excerpt.contains("区域") && source.excerpt.contains("置信") && source.excerpt.contains("未验证"), "OCR must include region locations and honest uncertainty")
        try check(source.documentLocation?.unit == .image && source.documentLocation?.recognition == true, "image recognition must retain its locator and method")
        let empty = service.createTask(workspace: workspace)
        await service.send(taskID: empty, text: #"ocr-fixture:{"file_path":"blank-prefix.pdf"}"#, configuration: config)
        try check(service.tasks[0].sources.isEmpty && service.tasks[0].tools[0].output.contains("offset=2") && service.tasks[0].tools[0].output.contains("共 2"), "an unreadable first page must retain total and continuation: \(service.tasks[0].tools.map(\.output))")
        await service.send(taskID: empty, text: #"ocr-fixture:{"file_path":"blank-prefix.pdf","offset":2}"#, configuration: config)
        try check(service.tasks[0].sources.first?.documentLocation?.first == 2 && service.tasks[0].sources.first?.excerpt.contains("SCAN-731") == true, "continuation must recognize the actual later page")
        let scanned = service.createTask(workspace: workspace)
        await service.send(taskID: scanned, text: #"ocr-fixture:{"file_path":"scanned.pdf","limit":2}"#, configuration: config)
        let pages = service.tasks[0].sources.first
        try check(pages?.documentLocation?.unit == .page && pages?.documentLocation?.first == 1 && pages?.documentLocation?.last == 2 && pages?.documentLocation?.total == 2 && pages?.documentLocation?.recognition == true, "scanned PDF must retain real page locations")
        try check(["第 1 页", "第 2 页", "SCAN-731", "SECOND-418", "13.25", "7.50"].allSatisfy { pages?.excerpt.contains($0) == true }, "both PDF pages and their actual printed fields must be recognized: \(service.tasks[0].tools.map(\.output))")
        try Data("invalid image".utf8).write(to: workspace.appendingPathComponent("broken.png"))
        for (arguments, expected) in [
            (#"{"file_path":"low-resolution.png"}"#, "分辨率过低"),
            (#"{"file_path":"broken.png"}"#, "损坏"),
            (#"{"file_path":"scanned.pdf","offset":3}"#, "超过 PDF 总页数"),
            (#"{"file_path":"scanned.pdf","limit":6}"#, "最多 5"),
            (#"{"file_path":"printed.png","offset":2}"#, "offset=1")
        ] {
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "ocr-fixture:" + arguments, configuration: config)
            let failed = service.tasks[0]
            try check(failed.sources.isEmpty && failed.tools.count == 1 && failed.tools[0].status == "失败" && failed.tools[0].output.contains(expected), "unreliable or invalid recognition must fail with actionable limits: \(failed.tools.map(\.output))")
        }
        let outside = directory.appendingPathComponent("outside.png")
        try FileManager.default.copyItem(at: workspace.appendingPathComponent("printed.png"), to: outside)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("link.png"), withDestinationURL: outside)
        let restricted = service.createTask(workspace: workspace)
        let pending = Task { await service.send(taskID: restricted, text: #"ocr-fixture:{"file_path":"link.png"}"#, configuration: config) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks[0].permissions.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        guard let permission = service.tasks[0].permissions.first else { throw NSError(domain: "TaskRecognitionTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "An outside image must require permission before recognition"]) }
        service.answerPermission(taskID: restricted, requestID: permission.id, allow: false)
        await pending.value
        try check(service.tasks[0].sources.isEmpty && !service.tasks[0].tools[0].output.contains("SCAN-731"), "refusing an external image must prevent recognition")
        try await checkActiveCancellation(service: service, workspace: workspace, config: config)
        for name in ["printed.png", "scanned.pdf", "low-resolution.png", "blank-prefix.pdf"] {
            let original = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/scans/" + name))
            try check(original == Data(contentsOf: workspace.appendingPathComponent(name)), "recognition must preserve original files")
        }
        service.shutdown()
        let reopened = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        let saved = reopened.tasks.first { $0.id == scanned }?.sources.first
        try check(saved?.documentLocation?.recognition == true && saved?.documentLocation?.last == 2 && saved?.excerpt == pages?.excerpt, "history must preserve OCR method, page locations and actual results")
        print("PASS: recognition through TaskService → ACP → actual image pixels")
    }
    @MainActor static func checkActiveCancellation(service: TaskService, workspace: URL, config: ModelConfiguration) async throws {
        let cancelled = service.createTask(workspace: workspace)
        let existingCaches = try recognitionCaches()
        let running = Task { await service.send(taskID: cancelled, text: #"ocr-fixture:{"file_path":"printed.png"}"#, configuration: config) }
        let started = Date().addingTimeInterval(15)
        var parserPIDs: Set<Int32> = []
        var createdCaches: Set<URL> = []
        var modelFilesCreated = false
        while Date() < started {
            parserPIDs = try ownParserProcesses()
            createdCaches = try recognitionCaches().subtracting(existingCaches)
            modelFilesCreated = createdCaches.contains { directory in
                guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return false }
                return files.contains { item in
                    guard let url = item as? URL else { return false }
                    return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }
            }
            if !parserPIDs.isEmpty && modelFilesCreated { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try check(!parserPIDs.isEmpty && modelFilesCreated, "the real parser must be alive and compiling a model before cancellation (children: \(parserPIDs.count), caches: \(createdCaches.count), model files: \(modelFilesCreated))")
        service.stop(taskID: cancelled)
        await running.value
        try check(service.tasks[0].status == .stopped && service.tasks[0].sources.isEmpty, "cancelling local recognition must not publish late results")
        let cleanupDeadline = Date().addingTimeInterval(5)
        while Date() < cleanupDeadline && (parserPIDs.contains { kill($0, 0) == 0 } || createdCaches.contains { FileManager.default.fileExists(atPath: $0.path) }) {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try check(parserPIDs.allSatisfy { kill($0, 0) == -1 && errno == ESRCH }, "cancelled parser processes must exit")
        try check(createdCaches.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }, "cancelled recognition must remove its disposable model cache")
    }
    static func recognitionCaches() throws -> Set<URL> {
        let roots = Set([URL(fileURLWithPath: "/private/tmp"), FileManager.default.temporaryDirectory.resolvingSymlinksInPath()])
        return Set(try roots.flatMap { try FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            .filter { $0.lastPathComponent.hasPrefix("claurst-ocr-") })
    }
    static func ownParserProcesses() throws -> Set<Int32> {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,comm="]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try check(process.terminationStatus == 0, "the test must observe its own parser process")
        let rows = String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line -> (Int32, Int32, String)? in
            let values = line.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
            guard values.count == 3, let pid = Int32(values[0]), let parent = Int32(values[1]) else { return nil }
            return (pid, parent, String(values[2]))
        }
        var descendants: Set<Int32> = [ProcessInfo.processInfo.processIdentifier]
        while true {
            let previous = descendants
            for row in rows where descendants.contains(row.1) { descendants.insert(row.0) }
            if descendants == previous { break }
        }
        return Set(rows.filter { descendants.contains($0.0) && $0.2.hasSuffix("claurst-document-parser") }.map { $0.0 })
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskRecognitionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
