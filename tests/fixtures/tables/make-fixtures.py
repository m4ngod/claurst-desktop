"""Owned, minimal OOXML workbooks with independently specified expected cells."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).parent
fixtures = {
    'sales.csv': '区域,金额,备注\n华东,10.25,"含,逗号"\n华西,7,普通\n华东,2.75,"跨\n行"\n华西,,缺失\n',
    'unclosed.csv': '区域,金额\n华东,"12\n',
    'ragged.csv': '区域,金额\n华东,12,多一列\n',
    'non-numeric.csv': '区域,金额\n华东,not-a-number\n',
    'missing-group.csv': '区域,金额\n,12\n',
}
for name, contents in fixtures.items():
    (root / name).write_text(contents, encoding='utf-8')
(root / 'invalid-utf8.csv').write_bytes(b'group,amount\n\xff,12\n')
(root / 'broken.xlsx').write_bytes(b'not-a-workbook')
content_types = '''<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>'''
rels = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">{}</Relationships>'
workbook = '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="交易" sheetId="1" r:id="rId1"/><sheet name="说明" sheetId="2" r:id="rId2"/></sheets></workbook>'
def text_cell(ref, text):
    return f'<c r="{ref}" t="inlineStr"><is><t>{text}</t></is></c>'
def sheet(rows):
    return '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + rows + '</sheetData></worksheet>'
rows = [
    '<row r="1">' + text_cell('A1', '区域') + text_cell('B1', '金额') + text_cell('C1', '备注') + text_cell('D1', '公式') + '</row>',
    '<row r="2">' + text_cell('A2', '华东') + '<c r="B2"><v>10.25</v></c>' + text_cell('C2', 'EXCEL-731') + '<c r="D2"><f>B2*2</f><v>20.5</v></c></row>',
    '<row r="3">' + text_cell('A3', '华西') + '<c r="B3"><v>7</v></c><c r="D3"><f>UNSUPPORTED(B3)</f><v/></c></row>',
    '<row r="4">' + text_cell('A4', '华东') + '<c r="B4"><v>2.75</v></c></row>',
    '<row r="5">' + text_cell('A5', '华西') + text_cell('C5', '缺失') + '</row>',
]
with ZipFile(root / 'sales.xlsx', 'w', ZIP_DEFLATED) as archive:
    archive.writestr('[Content_Types].xml', content_types)
    archive.writestr('_rels/.rels', rels.format('<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'))
    archive.writestr('xl/workbook.xml', workbook)
    archive.writestr('xl/_rels/workbook.xml.rels', rels.format(''.join(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>' for i in [1, 2])))
    archive.writestr('xl/worksheets/sheet1.xml', sheet(''.join(rows)))
    archive.writestr('xl/worksheets/sheet2.xml', sheet('<row r="3">' + text_cell('B3', '第二表：SHEET-418') + '</row>'))
