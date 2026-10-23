import Foundation
import CoreGraphics
import ImageIO
import PDFKit

struct RenderedImage: Codable {
    let width: Int
    let height: Int
    let mime_type: String
    let data: String
}

extension DocumentParser {
    static func renderImage(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        guard first == 1, limit == 1 else { throw ParseFailure(message: "单张图片请使用 offset=1、limit=1") }
        let image = try decodedImage(bytes, maxPixelSize: 1600)
        return try rendered(image, index: 1, total: 1)
    }

    static func renderPDFPage(_ bytes: Data, first: Int, limit: Int) throws -> ParsedDocument {
        guard limit == 1 else { throw ParseFailure(message: "PDF 视觉读取每次限 1 页，请使用 offset 选择页码") }
        guard let pdf = PDFDocument(data: bytes), let provider = CGDataProvider(data: bytes as CFData),
              let document = CGPDFDocument(provider) else { throw ParseFailure(message: "PDF 损坏或格式无效，未生成图像") }
        guard !pdf.isEncrypted, !pdf.isLocked, pdf.allowsCopying else {
            throw ParseFailure(message: "加密或禁止提取的 PDF 不支持视觉读取，请提供可读取的未加密副本")
        }
        guard document.numberOfPages > 0, first <= document.numberOfPages else {
            throw ParseFailure(message: "起始页超过 PDF 总页数；未读取，不推测缺失页面")
        }
        guard let page = document.page(at: first) else { throw ParseFailure(message: "PDF 页面损坏，未生成图像") }
        let image = try pageImage(page, maxPixelSize: 1600)
        guard let pixels = image.dataProvider?.data, (pixels as Data).contains(where: { $0 != 255 }) else {
            let continuation = first < document.numberOfPages ? "；继续查看请使用 offset=\(first + 1)" : "；已到文档末尾"
            throw ParseFailure(message: "第 \(first) 页未得到可核对图像，可能为空白、内容损坏或绘制失败；请检查原稿，不推测缺失内容。共 \(document.numberOfPages) 页\(continuation)")
        }
        return try rendered(image, index: first, total: document.numberOfPages)
    }

    static func pageImage(_ page: CGPDFPage, maxPixelSize: Int) throws -> CGImage {
        let bounds = page.getBoxRect(.cropBox).intersection(page.getBoxRect(.mediaBox))
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
            throw ParseFailure(message: "PDF 页面尺寸无效，未生成图像")
        }
        let rotated = abs(page.rotationAngle % 180) == 90
        let rawWidth = rotated ? bounds.height : bounds.width
        let rawHeight = rotated ? bounds.width : bounds.height
        let scale = min(3, CGFloat(maxPixelSize) / max(rawWidth, rawHeight))
        let width = max(1, Int(ceil(rawWidth * scale)))
        let height = max(1, Int(ceil(rawHeight * scale)))
        guard width >= 200, height >= 200,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ParseFailure(message: "PDF 页面过小或缩放后过窄，请分区域导出清晰副本后重试")
        }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(canvas)
        // Core Graphics fits down but does not enlarge a smaller page.
        // Apply the resolution scale explicitly, then map crop/rotation at 1:1.
        context.scaleBy(x: CGFloat(width) / rawWidth, y: CGFloat(height) / rawHeight)
        context.concatenate(page.getDrawingTransform(.cropBox,
            rect: CGRect(x: 0, y: 0, width: rawWidth, height: rawHeight), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        guard let image = context.makeImage() else { throw ParseFailure(message: "PDF 页面无法成像，未读取") }
        return image
    }

    private static func rendered(_ image: CGImage, index: Int, total: Int) throws -> ParsedDocument {
        guard image.width >= 200, image.height >= 200 else {
            throw ParseFailure(message: "图片缩放后过窄，无法可靠查看；请分区域导出清晰副本后重试，原文件未修改")
        }
        var encoded = try encode(image, type: "public.png", properties: [:])
        var mimeType = "image/png"
        if encoded.count > 4 * 1024 * 1024 {
            encoded = try encode(image, type: "public.jpeg", properties: [kCGImageDestinationLossyCompressionQuality: 0.85])
            mimeType = "image/jpeg"
        }
        guard encoded.count <= 4 * 1024 * 1024 else { throw ParseFailure(message: "渲染图像超过 4 MiB，请裁分清晰副本后重试；原文件未修改") }
        let note = "已生成供当前模型查看的图像，尺寸 \(image.width)×\(image.height)，最长边最多 1600 像素，已校正方向并去除原文件元数据；原文件未修改。\n这是图像读取记录，不是已验证的识别结论。图像生成不能验证原稿及所有页面元素完整；PDF 个别元素可能无法绘制，缺失内容须对照原稿，不推测为空白。请依据附带像素回答，无法辨认时明确说明；数字、手写、公式、表格结构和原稿完整性须对照原图核验。"
        return ParsedDocument(parts: [Part(index: index, text: note)], total: total,
            image: RenderedImage(width: image.width, height: image.height, mime_type: mimeType, data: encoded.base64EncodedString()))
    }

    private static func encode(_ image: CGImage, type: String, properties: [CFString: Any]) throws -> Data {
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, type as CFString, 1, nil) else { throw ParseFailure(message: "无法编码待查看的图像") }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ParseFailure(message: "无法编码待查看的图像") }
        return bytes as Data
    }
}
