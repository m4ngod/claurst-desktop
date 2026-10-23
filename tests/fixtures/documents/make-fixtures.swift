import Foundation
import CoreGraphics
import CoreText

// Small, owned input documents for the complete TaskService integration tests.
// Generate with: swift make-fixtures.swift <output-directory>
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var box = CGRect(x: 0, y: 0, width: 480, height: 360)
let file = directory.appendingPathComponent("report.pdf")
guard let pdf = CGContext(file as CFURL, mediaBox: &box, nil) else { fatalError("Cannot create fixture") }
let pages = [["项目：银杏", "预算：73 元"], ["校验码：P2-418", "第二页说明：预算不含税。"]]
for lines in pages {
    pdf.beginPDFPage(nil)
    for (index, text) in lines.enumerated() {
        let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, 18, nil)
        let attributes = [kCTFontAttributeName as NSAttributedString.Key: font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        pdf.textPosition = CGPoint(x: 40, y: 300 - index * 40)
        CTLineDraw(line, pdf)
    }
    pdf.endPDFPage()
}
pdf.closePDF()

// Blank, raster-only and password-protected samples use genuine PDF containers.
let blank = CGContext(directory.appendingPathComponent("blank.pdf") as CFURL, mediaBox: &box, nil)!
blank.beginPDFPage(nil); blank.endPDFPage(); blank.closePDF()
let bitmap = CGContext(data: nil, width: 480, height: 360, bitsPerComponent: 8, bytesPerRow: 480 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
bitmap.setFillColor(CGColor(gray: 1, alpha: 1)); bitmap.fill(box)
let rasterLine = CTLineCreateWithAttributedString(NSAttributedString(string: "扫描图像 SCAN-731", attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("PingFangSC-Regular" as CFString, 24, nil)]))
bitmap.textPosition = CGPoint(x: 30, y: 270); CTLineDraw(rasterLine, bitmap)
let scanned = CGContext(directory.appendingPathComponent("scanned.pdf") as CFURL, mediaBox: &box, nil)!
scanned.beginPDFPage(nil); scanned.draw(bitmap.makeImage()!, in: box); scanned.endPDFPage(); scanned.closePDF()
let encrypted = CGContext(directory.appendingPathComponent("encrypted.pdf") as CFURL, mediaBox: &box, [kCGPDFContextUserPassword: "fixture-only", kCGPDFContextOwnerPassword: "fixture-owner"] as CFDictionary)!
encrypted.beginPDFPage(nil); encrypted.textPosition = CGPoint(x: 30, y: 270); CTLineDraw(rasterLine, encrypted); encrypted.endPDFPage(); encrypted.closePDF()
try Data("not a PDF".utf8).write(to: directory.appendingPathComponent("broken.pdf"))
let blankPrefix = CGContext(directory.appendingPathComponent("blank-prefix.pdf") as CFURL, mediaBox: &box, nil)!
for page in 1...11 {
    blankPrefix.beginPDFPage(nil)
    if page == 11 {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "第十一页：LATE-731", attributes: [kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("PingFangSC-Regular" as CFString, 18, nil)]))
        blankPrefix.textPosition = CGPoint(x: 40, y: 300); CTLineDraw(line, blankPrefix)
    }
    blankPrefix.endPDFPage()
}
blankPrefix.closePDF()
