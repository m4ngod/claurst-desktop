"""Model-boundary pixel reader for the generated color challenge, not application OCR."""
import base64
import struct
import zlib


def image_probe_reply(blocks, expected_size=(800, 160)):
    images = [part['image_url']['url'] for part in blocks
              if part.get('type') == 'image_url'] if isinstance(blocks, list) else []
    if len(images) != 1 or not images[0].startswith('data:image/png;base64,'):
        return '未收到图像'
    try:
        data = base64.b64decode(images[0].split(',', 1)[1], validate=True)
        if data[:8] != b'\x89PNG\r\n\x1a\n':
            return '无效图像'
        compressed = bytearray()
        pos = 8
        header = None
        while pos < len(data):
            size = struct.unpack('>I', data[pos:pos + 4])[0]
            kind = data[pos + 4:pos + 8]
            payload = data[pos + 8:pos + 8 + size]
            if kind == b'IHDR':
                header = struct.unpack('>IIBBBBB', payload)
            elif kind == b'IDAT':
                compressed.extend(payload)
            pos += size + 12
        width, height, depth, color, compression, filtering, interlace = header
        if (width, height) not in (expected_size if isinstance(expected_size[0], tuple) else (expected_size,)) or (depth, compression, filtering, interlace) != (8, 0, 0, 0) or color not in (2, 6):
            return '不支持的测试图像'
        channels = 3 if color == 2 else 4
        stride = width * channels
        raw = zlib.decompress(compressed)
        if len(raw) != (stride + 1) * height:
            return '测试图像长度错误'
        previous = bytearray(stride)
        colors = []
        for y in range(height):
            start = y * (stride + 1)
            method = raw[start]
            row = bytearray(raw[start + 1:start + 1 + stride])
            for x in range(stride):
                left = row[x - channels] if x >= channels else 0
                above = previous[x]
                corner = previous[x - channels] if x >= channels else 0
                if method == 0:
                    predictor = 0
                elif method == 1:
                    predictor = left
                elif method == 2:
                    predictor = above
                elif method == 3:
                    predictor = (left + above) // 2
                elif method == 4:
                    estimate = left + above - corner
                    distances = [abs(estimate - value) for value in (left, above, corner)]
                    predictor = (left, above, corner)[distances.index(min(distances))]
                else:
                    return '不支持的 PNG 过滤器'
                row[x] = (row[x] + predictor) & 255
            if y == height // 2:
                for column in range(8):
                    i = (column * width // 8 + width // 16) * channels
                    r, g, b = row[i:i + 3]
                    if r > 180 and g > 150 and b < 80:
                        colors.append('黄')
                    elif r > 180 and g < 80 and b < 80:
                        colors.append('红')
                    elif g > 100 and r < 80 and b < 80:
                        colors.append('绿')
                    elif b > 180 and r < 80 and g < 80:
                        colors.append('蓝')
                    else:
                        return '无法辨别色块'
                break
            previous = row
        return '、'.join(colors)
    except (ValueError, TypeError, IndexError, struct.error, zlib.error):
        return '无法读取图像'
