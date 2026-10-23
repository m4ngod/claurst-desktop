import Foundation
import zlib

extension DocumentParser {
    // ImageIO can return a thumbnail and statusComplete for truncated data.
    // Check the encoded container too; never treat a partial decode as complete.
    static func validateImageContainer(_ bytes: Data, type: String) throws {
        let failure = ParseFailure(message: "图片数据不完整或损坏，未识别或发送图像；请重新导出完整 PNG/JPEG，原文件未修改")
        if type == "public.jpeg" {
            guard bytes.starts(with: [0xff, 0xd8]), bytes.suffix(2).elementsEqual([0xff, 0xd9]) else { throw failure }
            return
        }
        guard bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else { throw failure }
        var cursor = 8
        var hasImageData = false
        while cursor <= bytes.count - 12 {
            let length = Int(bytes[cursor]) << 24 | Int(bytes[cursor + 1]) << 16 | Int(bytes[cursor + 2]) << 8 | Int(bytes[cursor + 3])
            guard length <= bytes.count - cursor - 12 else { throw failure }
            let end = cursor + 8 + length
            let expected = UInt32(bytes[end]) << 24 | UInt32(bytes[end + 1]) << 16 | UInt32(bytes[end + 2]) << 8 | UInt32(bytes[end + 3])
            let actual = bytes[(cursor + 4)..<end].withUnsafeBytes { buffer in
                // The bounded, contiguous slice lives throughout this C call.
                crc32(0, buffer.baseAddress?.assumingMemoryBound(to: Bytef.self), uInt(buffer.count))
            }
            guard actual == expected else { throw failure }
            let kind = bytes[(cursor + 4)..<(cursor + 8)]
            if kind.elementsEqual([73, 68, 65, 84]) { hasImageData = true }
            if kind.elementsEqual([73, 69, 78, 68]) {
                guard length == 0, hasImageData, end + 4 == bytes.count else { throw failure }
                return
            }
            cursor = end + 4
        }
        throw failure
    }
}
