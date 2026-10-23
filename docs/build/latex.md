# 桌面 LaTeX 编译组件

开发目标：Apple 芯片 Mac。任务使用应用内置的 Tectonic 0.17.0 和固定基础资源离线编译；不要求用户安装系统 TeX，也不上传项目到在线排版服务。

## 构建准备

`scripts/build-desktop.sh` 和 `scripts/test-desktop.sh` 都调用 `scripts/prepare-latex.py`。首次准备可能联网下载官方编译器及固定仓库样本需要的排版资源；缓存保存在 `.build-tools/`。后续先离线验证样本，仅在构建缓存缺失时补齐公开资源。这个脚本不接受用户主文件作为输入。

官方编译器来源：[Tectonic 0.17.0 Release](https://github.com/tectonic-typesetting/tectonic/releases/tag/tectonic%400.17.0)。Apple 芯片压缩包 SHA-256 固定为 `a3f1cac7c5678f01661a92212f58480ae3b0634115d880dbc59e2953ded45667`；校验后只提取普通文件 `tectonic`，不展开任意归档路径。

TeX/西文字体的基础来源为 `default_bundle_v33.tar`，上游资源标识固定为 `6ffe055852f8faf66c0acbe1a7fb27f87b869a90bad1204f3bf4d9683f597c7c`。构建时用固定样本填充上游缓存，再按来源目录逐文件核验并只选择已登记的资源。Fandol 字体不进入应用；中文改用 Adobe 官方的思源宋体 2.003R、黑体 2.005R 简体中文 Regular/Bold OTF，保留未修改字体和两份原始 OFL 许可。版本、下载地址和校验值见 `third_party/source-han/sources.json`。

应用采用本地 `directory-v1` 资源目录：`bundle/` 内的成员表排序后计算独立标识，写入 `SHA256SUM` 和构建清单；不借用上游标识表示修改后的资源。`cache/` 只保存本地资源生成的格式缓存。`scripts/latex-resources.py` 检查完整成员集合、每个文件的摘要和资源标识，包检查与来源收集也调用同一校验。编译器继续由项目固定证书签名，标识为 `local.claurst.desktop.dev.latex-compiler`。

固定样本位于 `tests/fixtures/latex-support/`，包括中文、公式、表格、PNG、章节、BibTeX 和交叉引用。基础模板为 `ctexart`、`fontset=claurst`，含 geometry、amsmath、amssymb、booktabs、longtable、array、graphicx、xcolor、hyperref。支持 `\songti`、`\heiti`、粗体与合成倾斜的中文强调；不包含楷体、仿宋。旧项目若指定 `fontset=fandol`，需明确修改字体设置并重新检查版面，应用不静默替换源文件。并非完整 TeX Live，未包含的宏包或字体会明确失败，不在任务期间下载。

真实研究暴露常用字号和字形缺失后，固定准备样本增加 10pt、11pt、12pt 字体矩阵，覆盖正文大小、粗体、斜体、衬线/无衬线/等宽等常见组合，并由实际离线 TaskService 回归核对输出。矩阵仍会报告 Latin Modern 等宽粗斜体替代和最大字号的约 0.86pt 行溢出；不能称为所有字形无警告。另有中文 Regular/Bold/Sans/强调样本。矩阵只验证资源覆盖，不替代每份成果的页面检查。

## 执行与成果

- `CompileLaTeX` 只接受已选工作文件夹内的主文件；源文件与支持资源只读。每次编译建立独立 `claurst-latex-*` 输出目录，不覆盖旧 PDF。
- 编译器清空继承环境，仅保留必要参数；真实系统主目录仅供平台目录定位。沙盒将 Tectonic 全局配置隐藏为不存在，缓存固定到内置目录；不读取用户的全局排版设置。
- 使用 `--untrusted`、`--only-cached`、固定 bundle 和 OS 沙盒；网络、shell-escape 和范围外读取被拒绝，只能写本次输出目录。参数依据 [官方命令行文档](https://tectonic-typesetting.github.io/book/latest/v2cli/compile.html)。
- 编译最多 120 秒；停止或应用退出时结束编译进程并清理未交付目录。成功退出还须有不超过 32 MiB 的 PDF，并通过隔离 PDFKit 解析器打开及页数检查。
- 成果记录保存主文件、PDF、日志、实际页数、访问时间与 PDF 摘要。预览、导出核对摘要；文件被替换时提示重新编译。重复编译保留先前版本。
- 最终 TeX 日志中的未定义引用、溢出、字体等警告进入成果记录。编译成功不等于内容和页面布局已核对；助手须继续 Read / ReadImage，不能检查或未解决时明确说明。
- 「素材与成果」可查看 PDF、当前 LaTeX 主文件和日志，打开项目文件夹、源文件、Finder，并导出编译时的 PDF。缺少组件时有「排版组件说明」。

## 验证与公开发布边界

自动化沿用 TaskService → ACP → 真实编译器、文件和 OS，只替换模型 HTTP。日志在 `.build-tools/latex-14-*.log`。涵盖中文实际输出、页数、重复编译、历史、引用和溢出警告、编译错误、范围外读取、shell-escape、运行中停止、成果被替换与组件缺失。

退出回归还检查编译进程、未交付目录和权限等待运行时的清理。实际模型与图形界面证据见 [验收记录](verification-14-latex.md)。

这些是开发构建；公开安装包还须在第 18、19 项完成依赖清单、各编译器依赖及字体/宏包的许可证与分发材料核对，不能把 Tectonic 主项目的 MIT 许可当作所有资源的统一许可。来源分别保留在官方编译器、固定 bundle 和 CTAN 对应包中；尚未因此宣称公开发布就绪。
