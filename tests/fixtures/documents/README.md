# 自有文档验收样本

这些小文件由本目录脚本生成，不含用户资料。固定样本由 TaskService → ACP → Read → 实际解析器读取；测试仅替换模型 HTTP。

| 样本 | 独立预期 |
| --- | --- |
| report.pdf | 第 1 页：项目银杏、预算 73 元；第 2 页：P2-418、预算不含税 |
| report.docx | 第 1 段：项目银杏；第 2 段：预算 80 元；第 3 段空白；表格单元格为第 4 段：DOCX-731 |
| blank-prefix.pdf / .docx | 前 10 页/段空白，第 11 页/段含 LATE-731，首次须给续读位置 |
| blank.pdf / empty.docx | 无可提取文字，不产生已读取来源 |
| scanned.pdf | 图像上有 SCAN-731，但无文字层；本任务不得声称 OCR 成功 |
| encrypted.pdf | 真正受密码保护的 PDF，测试密码 fixture-only，不是任何服务凭据 |
| broken.pdf / broken.docx | 损坏输入明确报错 |
| wrong-root.docx | XML 可解析但不是 Word 正文结构，必须拒绝 |
| imported.docx | 含 w:altChunk 嵌入正文，明确不支持，不能悄悄只读引言 |
| legacy.doc | 旧容器签名的格式拒绝样本，不用于证明旧 Word 解析能力 |

在仓库根目录重新生成：

```sh
swiftc -module-cache-path .build-tools/swift-cache tests/fixtures/documents/make-fixtures.swift -o .build-tools/make-document-fixtures
.build-tools/make-document-fixtures tests/fixtures/documents
python3 tests/fixtures/documents/make-docx-fixtures.py tests/fixtures/documents
```

PDF 时间戳与加密随机值可变化；测试核对可观察内容及定位，不比较二进制快照。请复制样本到临时目录进行模型窗口验收，保持固定输入不被修改。
