# 自有扫描识别样本

使用 `swift tests/fixtures/scans/make-fixtures.swift tests/fixtures/scans` 重新生成。全部内容由项目构造，不含用户资料。

- `printed.png`：1200×900 像素。预期字段为“银杏”“SCAN-731”“73 元”，表格数字为 13.25 和 7.50。
- `scanned.pdf`：两张仅含位图的页面，没有隐藏文字层。第一页与 printed.png 相同；第二页含“SECOND-418”。
- `low-resolution.png`：80×60 像素，故意降低清晰度，应明确拒绝可靠识别，保留原图。
- `blank-prefix.pdf`：第一页空白，第二页为 printed.png；首次识别不能虚构来源，须返回总页数与 offset=2，续读须得到真实字段。

这些是预期字段，不是识别器的模拟输出。完整任务测试必须读取真实像素、给出页面或区域位置和不确定性提示；识别置信分数不等于准确率，不据此承诺表格结构、手写、公式或原稿完整性已验证。
