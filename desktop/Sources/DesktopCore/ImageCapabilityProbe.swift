import Foundation
import CoreGraphics
import ImageIO

/// A generated challenge contains no user material, embedded answer text or metadata.
/// It verifies one image-input round trip; it does not certify arbitrary visual accuracy.
struct ImageCapabilityProbe {
    let png: Data
    let expected: String
    static let prompt = "这是图像能力检查。图中有一排 8 个色块，请从左到右只回复每个色块的颜色，用顿号分隔。颜色仅可能是红、绿、蓝、黄。不要使用工具，不要猜测；看不到图片就回复无法识别。"

    static func make() throws -> ImageCapabilityProbe {
        let palette: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("红", 1, 0, 0), ("绿", 0, 0.7, 0), ("蓝", 0, 0, 1), ("黄", 1, 0.85, 0)
        ]
        guard let context = CGContext(data: nil, width: 800, height: 160, bitsPerComponent: 8,
            bytesPerRow: 3200, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw SettingsFailure("无法生成图像检查样本。") }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 160))
        var names: [String] = []
        for column in 0..<8 {
            let color = palette[Int.random(in: palette.indices)]
            names.append(color.0)
            context.setFillColor(CGColor(red: color.1, green: color.2, blue: color.3, alpha: 1))
            context.fill(CGRect(x: column * 100 + 10, y: 30, width: 80, height: 100))
        }
        let bytes = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil) else { throw SettingsFailure("无法编码图像检查样本。") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SettingsFailure("无法编码图像检查样本。") }
        return ImageCapabilityProbe(png: bytes as Data, expected: names.joined())
    }
    func matches(_ reply: String) -> Bool {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "、，,。.;；`*"))
        return reply.components(separatedBy: separators).joined() == expected
    }
}
