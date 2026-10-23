# 自有视觉读取样本

先运行 `python3 tests/fixtures/vision/make-fixtures.py`，再运行 `swift -module-cache-path .build-tools/swift-cache tests/fixtures/vision/make-variants.swift`。所有像素均为自有生成数据，不含用户资料。

| 样本 | 独立预期 |
| --- | --- |
| colors.png | 800×240，不含答案文字或元数据；八个色块依次红、蓝、绿、黄、蓝、红、黄、绿 |
| colors.pdf | 两页纯扫描图像，无文字层；第一页为绿、黄、红、蓝、黄、绿、蓝、红，第二页与 PNG 相同 |
| rotated.jpg | 与 PNG 相同的像素，TIFF Orientation=3；正确应用方向后应为绿、黄、红、蓝、黄、绿、蓝、红 |
| rotated.pdf | 第二页设置 Rotate=180；正确应用旋转后与 rotated.jpg 的可见顺序相同 |

模型边界替身必须从实际收到的图像像素判断颜色，不能依据路径或请求文字直接返回预设结果。应用负责真实授权、文件读取、独立解析、图像传输与来源记录。PDF 归一化图像为 1600×480，PNG/JPEG 为 800×240。

`TaskImageReadTests` 从上述样本派生截断 PNG（前半字节）和损坏 PDF（第 2 页内嵌图像流的 zlib 头替换为 `ZZ`），验证错误不生成成功来源。空白、低清样本分别复用 documents 和 scans 目录的自有材料。旋转前后的原件字节必须不变。
