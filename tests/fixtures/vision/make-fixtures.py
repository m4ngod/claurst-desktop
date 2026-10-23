"""Owned image fixture: eight colored patches, no answer text or metadata."""
from pathlib import Path
import struct
import zlib

folder = Path(__file__).parent
colors = [(255, 0, 0), (0, 0, 255), (0, 179, 0), (255, 217, 0),
          (0, 0, 255), (255, 0, 0), (255, 217, 0), (0, 179, 0)]


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


rows = bytearray()
for y in range(240):
    rows.append(0)
    for x in range(800):
        rows.extend(colors[x // 100] if 30 <= y < 210 and 10 <= x % 100 < 90 else (255, 255, 255))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 800, 240, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
(folder / 'colors.png').write_bytes(png)

# Image-only PDF, with different first and second pages. No text layer.
objects = [b'<< /Type /Catalog /Pages 2 0 R >>',
           b'<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>']
for index, palette in enumerate((list(reversed(colors)), colors)):
    image_id, stream_id = 4 + index * 3, 5 + index * 3
    objects.append(f'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 800 240] /Resources << /XObject << /Im {image_id} 0 R >> >> /Contents {stream_id} 0 R >>'.encode())
    rgb = bytes(channel for y in range(240) for x in range(800)
                for channel in (palette[x // 100] if 30 <= y < 210 and 10 <= x % 100 < 90 else (255, 255, 255)))
    compressed = zlib.compress(rgb)
    objects.append(f'<< /Type /XObject /Subtype /Image /Width 800 /Height 240 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length {len(compressed)} >>\nstream\n'.encode() + compressed + b'\nendstream')
    command = b'q 800 0 0 240 0 0 cm /Im Do Q'
    objects.append(f'<< /Length {len(command)} >>\nstream\n'.encode() + command + b'\nendstream')
pdf = bytearray(b'%PDF-1.4\n')
offsets = [0]
for index, value in enumerate(objects, 1):
    offsets.append(len(pdf))
    pdf.extend(f'{index} 0 obj\n'.encode() + value + b'\nendobj\n')
xref = len(pdf)
pdf.extend(f'xref\n0 {len(offsets)}\n0000000000 65535 f \n'.encode())
for offset in offsets[1:]:
    pdf.extend(f'{offset:010d} 00000 n \n'.encode())
pdf.extend(f'trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n'.encode())
(folder / 'colors.pdf').write_bytes(pdf)
