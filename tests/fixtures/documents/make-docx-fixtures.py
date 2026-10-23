"""Generate owned DOCX inputs; no external documents or user data."""
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
base = {'[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>', '_rels/.rels': '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>', 'word/document.xml': '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>项目：银杏</w:t></w:r></w:p><w:p><w:r><w:t>预算：</w:t></w:r><w:r><w:t>80 元</w:t></w:r></w:p><w:p/><w:tbl><w:tr><w:tc><w:p><w:r><w:t>表格：DOCX-731</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>'}
namespace = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
def document(body):
    return '<w:document xmlns:w="' + namespace + '" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>' + body + '</w:body></w:document>'
def paragraph(text):
    return '<w:p><w:r><w:t>' + text + '</w:t></w:r></w:p>'
variants = {
    'report.docx': base['word/document.xml'],
    'empty.docx': document('<w:p/>'),
    'broken.docx': '<not-closed>',
    'wrong-root.docx': '<unrelated xmlns:w="' + namespace + '"><w:body>' + paragraph('NOT WORD') + '</w:body></unrelated>',
    'imported.docx': document(paragraph('Introduction only') + '<w:altChunk r:id="chunk1"/>'),
    'blank-prefix.docx': document('<w:p/>' * 10 + paragraph('第十一段：LATE-731')),
}
for name, xml in variants.items():
    with zipfile.ZipFile(root / name, 'w', zipfile.ZIP_DEFLATED) as archive:
        for part, contents in base.items():
            archive.writestr(part, xml if part == 'word/document.xml' else contents)
        if name == 'imported.docx':
            archive.writestr('word/_rels/document.xml.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="chunk1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/aFChunk" Target="chunk.html"/></Relationships>')
            archive.writestr('word/chunk.html', '<html><body><p>Imported body must not silently disappear.</p></body></html>')
(root / 'legacy.doc').write_bytes(bytes.fromhex('d0cf11e0a1b11ae1') + b'unsupported-format fixture')
