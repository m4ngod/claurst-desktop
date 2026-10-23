import Foundation
#if SWIFT_PACKAGE
import DesktopCore
#endif

@main struct TaskImageReadTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = Process()
        fixture.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        fixture.arguments = [root.appendingPathComponent("tests/model_server.py").path]
        let output = Pipe(); fixture.standardOutput = output; fixture.standardError = FileHandle.nullDevice
        try fixture.run()
        defer { fixture.terminate() }
        let port = String(decoding: output.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let workspace = directory.appendingPathComponent("workspace")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/vision/colors.png"))
        try original.write(to: workspace.appendingPathComponent("colors.png"))
        let service = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { service.shutdown() }
        let configuration = ModelConfiguration(endpoint: "http://127.0.0.1:\(port)/v1", model: "fixture-model", apiKey: "test-only", isTest: true, imageInputEnabled: true)
        let task = service.createTask(workspace: workspace)
        await service.send(taskID: task, text: #"view-image-fixture:{"file_path":"colors.png"}"#, configuration: configuration)
        let result = service.tasks[0]
        try check(result.status == .completed && result.sources.count == 1, "ReadImage must produce a located source: \(result.tools.map(\.output))")
        try check(result.messages.last?.text == "图像颜色：红、蓝、绿、黄、蓝、红、黄、绿", "actual image pixels must reach the configured model: \(result.messages.last?.text ?? "")")
        try check(result.sources[0].documentLocation?.unit == .image && result.sources[0].file.lastPathComponent == "colors.png", "visual source must locate the actual image")
        try check(original == Data(contentsOf: workspace.appendingPathComponent("colors.png")), "visual reading must preserve the original")
        let sourceJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.sources[0])) as! [String: Any]
        try check((sourceJSON["documentLocation"] as? [String: Any])?["visual"] as? Bool == true,
            "source must distinguish model image preparation from OCR and text extraction")
        let pdf = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/vision/colors.pdf"))
        try pdf.write(to: workspace.appendingPathComponent("colors.pdf"))
        let pageTask = service.createTask(workspace: workspace)
        await service.send(taskID: pageTask, text: #"view-image-fixture:{"file_path":"colors.pdf","offset":2}"#, configuration: configuration)
        let pageResult = service.tasks.first { $0.id == pageTask }!
        try check(pageResult.status == .completed && pageResult.sources.count == 1, "PDF page must produce a visual source: \(pageResult.tools.map(\.output))")
        try check(pageResult.messages.last?.text == "图像颜色：红、蓝、绿、黄、蓝、红、黄、绿", "requested page pixels must reach model: \(pageResult.messages.last?.text ?? "")")
        let location = pageResult.sources[0].documentLocation
        try check(location?.unit == .page && location?.first == 2 && location?.last == 2 && location?.total == 2, "PDF visual source must locate just the selected page")
        try check(pdf == Data(contentsOf: workspace.appendingPathComponent("colors.pdf")), "PDF visual reading must preserve original")
        for (name, offset) in [("rotated.jpg", 1), ("rotated.pdf", 2)] {
            let original = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/vision/" + name))
            try original.write(to: workspace.appendingPathComponent(name))
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "view-image-fixture:{\"file_path\":\"" + name + "\",\"offset\":\(offset)}", configuration: configuration)
            let rotated = service.tasks.first { $0.id == id }!
            try check(rotated.status == .completed && rotated.messages.last?.text == "图像颜色：绿、黄、红、蓝、黄、绿、蓝、红",
                "JPEG orientation/PDF rotation must be visible in actual pixels: \(rotated.messages.last?.text ?? "")")
            try check(original == Data(contentsOf: workspace.appendingPathComponent(name)), "normalization must not change original orientation metadata")
        }
        var damagedPDF = pdf
        let objectStart = damagedPDF.range(of: Data("7 0 obj".utf8))!.upperBound
        let streamStart = damagedPDF.range(of: Data("stream\n".utf8), in: objectStart..<damagedPDF.count)!.upperBound
        damagedPDF.replaceSubrange(streamStart..<(streamStart + 2), with: Data("ZZ".utf8))
        try damagedPDF.write(to: workspace.appendingPathComponent("damaged.pdf"))
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/documents/blank.pdf"), to: workspace.appendingPathComponent("blank.pdf"))
        for name in ["damaged.pdf", "blank.pdf"] {
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "view-image-fixture:{\"file_path\":\"" + name + "\",\"offset\":" + (name == "damaged.pdf" ? "2" : "1") + "}", configuration: configuration)
            let failed = service.tasks.first { $0.id == id }!
            try check(failed.sources.isEmpty && failed.tools.first?.status == "失败" && failed.tools.first?.output.contains("可核对图像") == true,
                "blank or failed PDF rendering must not create a reliable source: \(failed.tools.map(\.output))")
        }
        let batch = service.createTask(workspace: workspace)
        await service.send(taskID: batch, text: "view-batch-fixture", configuration: configuration)
        let batchResult = service.tasks.first { $0.id == batch }!
        try check(batchResult.status == .completed && batchResult.sources.count == 2 && batchResult.messages.last?.text ==
            "图像颜色：红、蓝、绿、黄、蓝、红、黄、绿；绿、黄、红、蓝、黄、绿、蓝、红", "batched images must retain each image and complete all tool replies before forwarding pixels: \(batchResult.messages.last?.text ?? "")")
        let unverified = ModelConfiguration(endpoint: configuration.endpoint, model: configuration.model, apiKey: "test-only", isTest: true)
        let disabled = service.createTask(workspace: workspace)
        await service.send(taskID: disabled, text: #"view-image-fixture:{"file_path":"colors.png"}"#, configuration: unverified)
        let disabledResult = service.tasks.first { $0.id == disabled }!
        try check(disabledResult.sources.isEmpty && disabledResult.tools.first?.status == "失败" && disabledResult.tools.first?.output.contains("图像输入未验证") == true, "an unverified service must not receive image pixels")
        try Data("not an image".utf8).write(to: workspace.appendingPathComponent("broken.png"))
        try original.prefix(original.count / 2).write(to: workspace.appendingPathComponent("truncated.png"))
        try FileManager.default.copyItem(at: root.appendingPathComponent("tests/fixtures/scans/low-resolution.png"), to: workspace.appendingPathComponent("low.png"))
        for (arguments, expected) in [
            (#"{"file_path":"broken.png"}"#, "损坏"),
            (#"{"file_path":"truncated.png"}"#, "不完整"),
            (#"{"file_path":"low.png"}"#, "分辨率过低"),
            (#"{"file_path":"colors.pdf","offset":3}"#, "超过 PDF 总页数"),
            (#"{"file_path":"colors.pdf","limit":2}"#, "每次 1"),
            (#"{"file_path":"colors.png","offset":2}"#, "offset=1")
        ] {
            let id = service.createTask(workspace: workspace)
            await service.send(taskID: id, text: "view-image-fixture:" + arguments, configuration: configuration)
            let failed = service.tasks.first { $0.id == id }!
            try check(failed.sources.isEmpty && failed.tools.first?.status == "失败" && failed.tools.first?.output.contains(expected) == true,
                "invalid images must fail without a source: \(failed.tools.map(\.output))")
        }
        let outside = directory.appendingPathComponent("outside.png")
        try original.write(to: outside)
        try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("link.png"), withDestinationURL: outside)
        let denied = service.createTask(workspace: workspace)
        let pending = Task { await service.send(taskID: denied, text: #"view-image-fixture:{"file_path":"link.png"}"#, configuration: configuration) }
        let deadline = Date().addingTimeInterval(10)
        while service.tasks.first(where: { $0.id == denied })?.permissions.isEmpty == true && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        guard let permission = service.tasks.first(where: { $0.id == denied })?.permissions.first else {
            throw NSError(domain: "TaskImageReadTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "outside image must require permission"])
        }
        service.answerPermission(taskID: denied, requestID: permission.id, allow: false)
        await pending.value
        let deniedResult = service.tasks.first { $0.id == denied }!
        try check(deniedResult.sources.isEmpty && deniedResult.tools.first?.status == "失败", "refusing an outside image must prevent reading and transmission")
        let rejecting = ModelConfiguration(endpoint: configuration.endpoint, model: "fixture-reject-image", apiKey: "test-only", isTest: true, imageInputEnabled: true)
        let rejected = service.createTask(workspace: workspace)
        await service.send(taskID: rejected, text: #"view-image-fixture:{"file_path":"colors.png"}"#, configuration: rejecting)
        let rejectedResult = service.tasks.first { $0.id == rejected }!
        try check(rejectedResult.status == .failed && rejectedResult.sources.count == 1 && rejectedResult.sources[0].documentLocation?.visual == true,
            "provider failure must not report image understanding as completed")
        service.shutdown()
        let reopened = TaskService(executable: root.appendingPathComponent("vendor/claurst/src-rust/target/debug/claurst-desktop-runtime"), storageDirectory: directory.appendingPathComponent("settings"))
        defer { reopened.shutdown() }
        let saved = reopened.tasks.first { $0.id == pageTask }?.sources.first
        try check(saved?.documentLocation?.visual == true && saved?.documentLocation?.first == 2 && saved?.excerpt == pageResult.sources[0].excerpt,
            "history must retain visual method, selected page and unverified receipt")
        print("PASS: image/PDF pixels, batch ordering, capability gating, failures, permissions, originals and history through TaskService")
    }
    static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "TaskImageReadTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}
