"""Adversarial regression cases derived only from the owned sample workbook."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).parent
with ZipFile(root / 'sales.xlsx') as archive:
    base = {name: archive.read(name) for name in archive.namelist()}

def variant(name, update):
    with ZipFile(root / name, 'w', ZIP_DEFLATED) as archive:
        for key, value in base.items():
            archive.writestr(key, update(value.decode()) if key == 'xl/worksheets/sheet1.xml' else value)

variant('precision.xlsx', lambda text: text.replace('<v>10.25</v>', '<v>9007199254740993</v>'))
variant('array-formula.xlsx', lambda text: text.replace('<c r="B2"><v>10.25</v></c>', '<c r="B2"><f t="array" ref="B2:C2">{1,99}</f><v>1</v></c>').replace('<c r="C2" t="inlineStr"><is><t>EXCEL-731</t></is></c>', '<c r="C2"><v>99</v></c>'))
with ZipFile(root / 'shared-expansion.xlsx', 'w', ZIP_DEFLATED) as archive:
    for key, value in base.items():
        if key == 'xl/worksheets/sheet1.xml':
            value = '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + ''.join(f'<row r="{row}"><c r="A{row}" t="s"><v>0</v></c></row>' for row in range(1, 1801)) + '</sheetData></worksheet>'
        elif key == '[Content_Types].xml':
            value = value.decode().replace('</Types>', '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>')
        elif key == 'xl/_rels/workbook.xml.rels':
            value = value.decode().replace('</Relationships>', '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/></Relationships>')
        archive.writestr(key, value)
    archive.writestr('xl/sharedStrings.xml', '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="1800" uniqueCount="1"><si><t>' + 'x' * 10240 + '</t></si></sst>')
