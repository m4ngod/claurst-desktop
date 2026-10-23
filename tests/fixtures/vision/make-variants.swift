import Foundation
import ImageIO
import PDFKit

// Run after make-fixtures.py. These are owned test pixels, not user images.
let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let png = try Data(contentsOf: folder.appendingPathComponent("colors.png"))
let source = CGImageSourceCreateWithData(png as CFData, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let jpeg = CGImageDestinationCreateWithURL(folder.appendingPathComponent("rotated.jpg") as CFURL, "public.jpeg" as CFString, 1, nil)!
let properties: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFOrientation: 3], kCGImageDestinationLossyCompressionQuality: 0.9]
CGImageDestinationAddImage(jpeg, image, properties as CFDictionary)
precondition(CGImageDestinationFinalize(jpeg))
let document = PDFDocument(url: folder.appendingPathComponent("colors.pdf"))!
document.page(at: 1)!.rotation = 180
precondition(document.write(to: folder.appendingPathComponent("rotated.pdf")))
