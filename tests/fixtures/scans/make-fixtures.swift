import Foundation
import CoreGraphics
import CoreText
import ImageIO

// Owned raster fixtures. No hidden PDF text layer and no external images.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func page(_ lines: [String]) -> CGImage {
    let context = CGContext(data: nil, width: 1200, height: 900, bitsPerComponent: 8, bytesPerRow: 4800, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
    for (index, text) in lines.enumerated() {
        let attributes: [NSAttributedString.Key: Any] = [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("PingFangSC-Regular" as CFString, 45, nil), kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0, alpha: 1)]
        context.textPosition = CGPoint(x: 70, y: 780 - index * 110)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
    }
    return context.makeImage()!
}
let first = page(["项目：银杏 SCAN-731", "预算：73 元", "区域       金额", "华东       13.25", "华西       7.50"])
let image = CGImageDestinationCreateWithURL(directory.appendingPathComponent("printed.png") as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(image, first, nil); precondition(CGImageDestinationFinalize(image))
var bounds = CGRect(x: 0, y: 0, width: 600, height: 450)
let pdf = CGContext(directory.appendingPathComponent("scanned.pdf") as CFURL, mediaBox: &bounds, nil)!
for bitmap in [first, page(["第二页 SECOND-418", "原稿缺页须对照原件核查"])] {
    pdf.beginPDFPage(nil); pdf.draw(bitmap, in: bounds); pdf.endPDFPage()
}
pdf.closePDF()
let low = CGContext(data: nil, width: 80, height: 60, bitsPerComponent: 8, bytesPerRow: 320, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
low.draw(first, in: CGRect(x: 0, y: 0, width: 80, height: 60))
let lowFile = CGImageDestinationCreateWithURL(directory.appendingPathComponent("low-resolution.png") as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(lowFile, low.makeImage()!, nil); precondition(CGImageDestinationFinalize(lowFile))

let blankPDF = CGContext(directory.appendingPathComponent("blank-prefix.pdf") as CFURL, mediaBox: &bounds, nil)!
for bitmap in [page([]), first] {
    blankPDF.beginPDFPage(nil); blankPDF.draw(bitmap, in: bounds); blankPDF.endPDFPage()
}
blankPDF.closePDF()
