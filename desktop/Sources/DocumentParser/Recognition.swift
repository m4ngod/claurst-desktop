import Foundation
import CoreGraphics
import ImageIO
import PDFKit
import Vision

extension DocumentParser {
    static func recognizeImage(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        guard first == 1, (1...5).contains(limit) else {
            throw ParseFailure(message: "单张图片请使用 offset=1；识别 limit 须为 1–5")
        }
        let image = try decodedImage(bytes, maxPixelSize: 2400)
        guard let text = try recognize(image) else {
            throw ParseFailure(message: "未识别出可靠文字，可能为空白、低清或复杂内容；请检查原图，不补造文字或数字")
        }
        return ParsedDocument(parts: [Part(index: 1, text: text)], total: 1)
    }

    static func decodedImage(_ bytes: Data, maxPixelSize: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) == 1,
              let type = CGImageSourceGetType(source) as String?, ["public.png", "public.jpeg"].contains(type),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ParseFailure(message: "图片损坏或格式不支持；请提供单张 PNG 或 JPEG 原图")
        }
        try validateImageContainer(bytes, type: type)
        guard CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw ParseFailure(message: "图片数据不完整或损坏，未识别或发送图像；请重新导出完整 PNG/JPEG，原文件未修改")
        }
        guard width >= 200, height >= 200 else {
            throw ParseFailure(message: "图片分辨率过低，无法可靠识别；请提供至少 200×200 像素的清晰原图，原文件未修改")
        }
        guard width <= 20_000, height <= 20_000, width * height <= 20_000_000 else {
            throw ParseFailure(message: "图片展开超过 2000 万像素，未识别；请分区域导出清晰副本")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw ParseFailure(message: "图片无法解码，未识别；请另存为清晰的 PNG 或 JPEG")
        }
        return image
    }

    static func recognizePDF(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        guard (1...5).contains(limit) else { throw ParseFailure(message: "扫描 PDF 每次最多识别 5 页，请缩小 limit") }
        guard let pdf = PDFDocument(data: bytes),
              let provider = CGDataProvider(data: bytes as CFData),
              let document = CGPDFDocument(provider) else {
            throw ParseFailure(message: "扫描 PDF 损坏或格式无效，未识别")
        }
        guard !pdf.isEncrypted, !pdf.isLocked, pdf.allowsCopying else {
            throw ParseFailure(message: "加密或禁止提取的 PDF 不支持识别，请提供可读取的未加密副本")
        }
        guard document.numberOfPages > 0, first <= document.numberOfPages else {
            throw ParseFailure(message: "起始页超过 PDF 总页数；未识别，不推测缺失页面")
        }
        var result = ParsedDocument(total: document.numberOfPages)
        var remaining = 50 * 1024
        var hasText = false
        for number in first...min(document.numberOfPages, first + limit - 1) {
            guard let page = document.page(at: number) else { throw ParseFailure(message: "PDF 页面损坏，未完成本次识别") }
            let image = try pageImage(page, maxPixelSize: 2400)
            let recognized = try recognize(image)
            hasText = hasText || recognized != nil
            let text = recognized ?? "[本页未识别出可靠文字，可能为空白、低清或复杂内容；请检查原图，不补造文字或数字]"
            guard text.utf8.count <= remaining else { throw ParseFailure(message: "识别结果超过 50 KiB，请缩小 limit") }
            remaining -= text.utf8.count
            result.parts.append(Part(index: number, text: text))
        }
        guard hasText else {
            let last = min(document.numberOfPages, first + limit - 1)
            let continuation = last < document.numberOfPages ? "；继续识别请使用 offset=\(last + 1)" : "；已到文档末尾"
            return ParsedDocument(total: document.numberOfPages, error: "所选页面未识别出可靠文字，可能为空白、低清或复杂内容；请核对原图，不补造数据。本次第 \(first)–\(last) 页，共 \(document.numberOfPages) 页\(continuation)")
        }
        return result
    }

    private static func recognize(_ image: CGImage) throws -> String? {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        request.usesCPUOnly = true
        do {
            let supported = try request.supportedRecognitionLanguages()
            guard request.recognitionLanguages.allSatisfy(supported.contains) else {
                throw ParseFailure(message: "系统缺少中文或英文识别支持；请更新 macOS 后重试，或使用已验证具备视觉能力的非 Claude 服务")
            }
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch let failure as ParseFailure { throw failure }
        catch { throw ParseFailure(message: "本地文字识别组件不可用或执行失败；请更新 macOS 并重试，未取得可核对内容") }
        let observations = (request.results ?? []).sorted {
            let firstRow = Int(($0.boundingBox.midY * 100).rounded())
            let secondRow = Int(($1.boundingBox.midY * 100).rounded())
            if firstRow != secondRow { return firstRow > secondRow }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        guard !observations.isEmpty else { return nil }
        guard observations.count <= 1000 else { throw ParseFailure(message: "单页文字区域过多，请裁分副本后重试") }
        var lines = ["本地 OCR；以下均未验证。置信分数不是准确率，数字与名称须逐项对照原图。",
            "未验证原稿是否缺页；手写、公式、表格结构和阅读顺序可能不可靠。仅返回文字区域，不推测单元格关系，不重算公式。",
            "识别图像尺寸 \(image.width)×\(image.height)；区域为按方向校正后的图像像素坐标，左上角为原点（x,y,宽,高），原文件未修改。"]
        for (index, observation) in observations.enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let box = observation.boundingBox
            let x = Int((box.minX * Double(image.width)).rounded())
            let y = Int(((1 - box.maxY) * Double(image.height)).rounded())
            let width = Int((box.width * Double(image.width)).rounded())
            let height = Int((box.height * Double(image.height)).rounded())
            let confidence = Int((candidate.confidence * 100).rounded())
            let warning = candidate.confidence < 0.8 ? "，低置信，需重点核对" : "，仍需核对"
            lines.append("区域 \(index + 1) [\(x),\(y),\(width),\(height)] 置信分数 \(confidence)/100\(warning)：\(candidate.string)")
        }
        let text = lines.joined(separator: "\n")
        guard text.utf8.count <= 50 * 1024 else { throw ParseFailure(message: "单页识别文字超过 50 KiB，请分区域处理") }
        return text
    }
}
