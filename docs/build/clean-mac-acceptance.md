# 干净 Mac 验收记录

状态：本地候选的无开发环境功能验收已完成（2026-10-23），保留本地 OCR 在此虚拟机失败及一次模型结论人工纠正的限制。首次配置、目录选择、文档与计算来源、视觉扫描识别、PDF 预览、退出重开、继续修改、七份原件摘要、停止及草稿恢复均取得客体实际证据。公开下载、Developer ID、公证及最终分发材料归第 19 项继续，不将共享卷启动称为公开分发验收。

2026-10-22 环境准备：用户没有第二台 Mac，已在本机用 Apple Virtualization 安装全新 macOS 27.0.1（26A434）来进行无开发工具验收。虚拟机分配 4 vCPU、6 GiB 内存、80 GiB 稀疏磁盘；没有从宿主迁移账户、钥匙串或开发工具。官方恢复镜像由 `VZMacOSRestoreImage.latestSupported` 选择，26,637,307,067 字节，SHA-256 `2f016638293c3e641b8b25391a76fbc16563b3711915a5551cf8aa0f5598a5c1` 与 Apple CDN 摘要一致。

2026-10-23 用户完成本地账户与首次设置，已跳过 Apple 账户登录并进入桌面。通过 Finder 将候选应用 ZIP 和合成素材 ZIP 从只读共享卷复制到虚拟机 Downloads；应用解压后成功打开，无需开发工具。当前停在首次模型配置，用户尚需在虚拟机独立钥匙串保存模型凭据；素材任务尚未执行。本地测试宿主在 `.build-tools/clean-mac/`，只读共享目录仅含候选应用 ZIP、合成素材 ZIP 及说明。虚拟机宿主是独立测试程序，不改变 Claurst Desktop 固定签名身份。虚拟机结果须标明环境，不扩张为所有实体 Mac 或其它 macOS 版本均通过。

开发方运行 `python3 scripts/package-acceptance-fixtures.py` 可生成独立素材 ZIP。接收方只需应用候选 ZIP 和素材 ZIP，在 Finder 解压即可；此流程不要求安装 Xcode、Python、Rust 或系统 TeX。合成数据不代表真实研究，素材包与应用分开提供。

## 环境记录

记录候选目录名、应用 ZIP 的 SHA-256、Mac 芯片型号、完整 macOS 版本、是否已有开发工具或 TeX、模型服务及模型标识。不要记录 API Key、系统密码或证书私钥。当前构建目标为 macOS 13，实际开发机验证版本为 27.0.1；其它系统仍待实测。

## 操作与结果

1. 解压应用并打开。记录 macOS 的实际启动结果；若被系统阻止，保留提示，不能把静态签名检查记为启动通过。
2. 在「模型设置」自行填写可用的非 Claude 服务，保存并检查连接。记录文本、工具与图像检查的实际结果。已有配置或开发机钥匙串不能代替首次配置验证。
3. 选择素材包中的 `workspace` 文件夹，发送：

   > 读取 notes.md、report.pdf、report.docx、sales.xlsx 和 sales.csv。核对扫描 PDF 的两页与 printed.png；按区域汇总金额，指出缺失值和素材冲突。保留七份原件，生成一页中文说明 main.tex 并编译为 PDF，检查实际页面，不推断未知事实。

4. 在「素材与成果」逐一打开来源、计算、识别和 PDF 记录。PDF 预算为 73 元、Word 为 80 元；扫描第二页标记 SECOND-418，不能推断原件总页数。表格汇总华东 13（2 个有效值），华西 7（1 个有效值、1 个缺失）；图像金额为 13.25 和 7.50，不能代替表格数据。检查中文是否可见、段落或表格是否裁切，并试用打开文件和「在 Finder 中显示」。
5. 退出并重新打开应用，确认任务、来源和 PDF 成果仍可查看；继续发送「读取 notes.md 并新建 result.txt，写入验收继续成功」。核对实际新文件和修改记录。
6. 运行中点击停止，确认状态结束、输入可继续使用；切换任务再返回，确认历史和草稿。停止不撤销已经发生的修改。

每项记录通过、失败或未执行，并附实际现象。缺少模型能力、网络失败、系统提示和来源不一致都必须保留，不能用开发机或模型替身结果替换。可用素材 ZIP 内的 `manifest.json` 核对七份原件是否保持不变。

## 验收结果

2026-10-23，Codex 使用 Computer Use 操作 Apple Virtualization 全新 macOS 27.0.1（26A434）；未迁移宿主数据，未安装 Xcode、Rust 或 TeX。候选 `candidate-a3vT0N`（源码 `9f1f01c`）的应用 ZIP 为 96,715,368 字节，SHA-256 `5f85b9ade9a4c6ce8892f992f0b8846a6bb990c7da7b7457e7cecd0530cbd60f`。共享卷副本在宿主已逐字节核对。

- 第 1 步：Finder 解压与启动通过，显示空任务和首次配置界面。此次传输来自本地共享卷，不代表浏览器下载后带 quarantine 属性的 Gatekeeper 路径通过；公开下载仍须另验。
- 第 2 步：待用户输入独立虚拟机的 API Key。自动输入服务地址时虚拟键盘漏了冒号，已明确请用户补为 `https://`；没有将失败输入当作连接结果。
- 第 3–6 步：未执行。

以上为首次安装时的历史状态，后续完成结果见本文末尾；公开分发条件另在第 19 项追踪。

## 验收虚拟机剪贴板（2026-10-23）

用户报告宿主复制的密钥不能粘贴到虚拟机，随后明确选择先补好共享。当前测试宿主没有配置 SPICE console，干净 guest 也没有相应组件；这与模型密钥有效性无关。已为独立 VMHost 增加官方 `VZSpiceAgentPortAttachment` 和菜单开关，每次启动 `sharesClipboard=false`，开启前说明两侧剪贴板可能含敏感数据。没有加入宿主剪贴板读取、按键注入或凭据转存代码。该测试宿主继续独立签名，不改变产品固定签名身份。

虚拟机已正常关机并用新宿主启动，目前停在本地账户登录页。只读共享卷另增加 [UTM 官方 macOS guest tools 0.22.1-2](https://github.com/utmapp/vd_agent/releases/tag/v0.22.1-2) 安装包 `spice-vdagent-0.22.1-2.pkg`：5,352,291 字节，SHA-256 `b9b9ac590738d26f1d734ed9c9b082e1bcdaab109189d1c04803fef97cf59714`，与官方发布摘要相符。允许系统信任服务访问后，`pkgutil --check-signature` 确认 Developer ID Installer 为 Turing Software, LLC（WDNLXAD4W8），具有受信任时间戳及 Apple 公证；沙箱内先前返回的 invalid signature 没有被当作最终验证结果。安装内容为两个 SPICE 程序、对应 LaunchAgent/LaunchDaemon 和启动脚本；尚未在 guest 安装或验证粘贴。

之前下载的 Tart Guest Agent 因源码要求专用 Tart 宿主而未采用，没有伪造宿主标识绕过该检查。所有组件只用于验收虚拟机，不作为 Claurst Desktop 运行依赖；无需给 guest 安装编译工具。用户登录后仍须完成组件安装、共享开启和普通文字的双向复制验证，再继续密钥配置与第 2–6 步验收。


### 安装与实际同步排查

用户随后完成 guest 登录、官方组件安装，并在宿主确认开启共享。Computer Use 核对菜单为“已开启”，用两侧 TextEdit 进行普通文本测试：宿主 `clipboard-check-731` 未到达 guest，guest `Guest-copy-842` 未到达宿主，不能据开关状态记录成功。没有读取原始剪贴板，也未复制密钥。

通过 guest Terminal 只读检查确认 spice-vdagentd 和用户 spice-vdagent 都在运行，daemon 日志显示打开 `/dev/tty.com.redhat.spice.0`；使用 `launchctl kickstart -k gui/501/com.redhat.spice.vdagent` 重新连接已有用户服务后仍失败。官方安装包已运行，不适用“尚未安装”这一旧状态。

本地 SDK 的 `VZVirtioConsolePort.h` 明确说明运行中可以更换 `attachment`。测试宿主原开关仅修改配置 attachment 的 `sharesClipboard`；已改为从 `machine.consoleDevices` 取得实际端口，开启时连接新建且 enabled 的 SPICE attachment，关闭时将运行端口 attachment 设为 nil。正常关机后替换测试宿主，复用原虚拟磁盘与已安装组件重新启动，目前等待用户在登录页输入本地密码。此修复尚待双向粘贴复测，不宣称已解决，也不改变产品签名身份或 guest 权限。

用户完成登录后，以普通文本 `clipboard-check-953` 重试上述方案，启用动作导致测试宿主退出 139。系统崩溃报告显示主线程在 `VZVirtioConsolePort.setAttachment` 调用 `VZSpiceAgentPortAttachment._attachment` 时发生 `EXC_BAD_ACCESS`；没有将此次超时解释为客体密码或 API Key 问题。运行中替换方案因此撤回。

下一版测试宿主仅在启动参数明确包含 `--share-clipboard` 时，在创建虚拟机之前将 `sharesClipboard` 设为 true；普通启动保持关闭。复测沿用用户已明确开启共享的授权，未扩大共享对象或权限。共享期间可通过菜单请求正常关机，客体停止后释放连接；不再提供未经验证的运行中开关。该宿主已重新构建、独立签名并启动原虚拟磁盘，目前再次到本地账户登录页，等待用户登录后检验双向复制。此时不能记录剪贴板通过。

### 启动时配置后的双向验证通过

用户再次登录后，宿主 TextEdit 复制 `clipboard-check-964`，客体 Claurst Desktop 的输入框通过 Edit → Paste 显示完全相同文字；随后仅在客体输入 `guest-copy-975a`，通过 Edit → Select All / Copy 复制，宿主 TextEdit 粘贴后 AX 返回同一文字。两方向均通过，没有读取原始剪贴板或使用密钥作为测试内容。先前失败、崩溃及撤回方案保留在上文，不能将仅安装组件或菜单状态称为通过。

已清除未发送的测试输入，并通过本机普通文字复制与客体菜单粘贴补全服务地址 `https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`，模型保持 `qwen3.8-flash`。密钥栏为空，已交给用户自行粘贴和保存检查；提醒保存后复制普通文字替换剪贴板密钥。API Key 与系统密码均未进入日志或聊天，模型连接及素材任务结果仍待实际验证。

## 更新候选与真实素材任务（2026-10-23）

用户随后回复“连接结果都正常”。通过 Finder 安装更新候选 `candidate-mpGA4v`，对应源码 `278fd7fdd942215c5d84ac06930375a5e4e9e6fb`；应用 ZIP 为 96,715,370 字节，SHA-256 `744c7febefd374148a7c03dddc72a2367552b565c231994cb2ddb0fa8c922877`。只读共享卷副本摘要已核对；客体解压路径为 `~/Downloads/Claurst Desktop 2.app`，旧应用保留但已正常退出。合成素材解压到 `~/Downloads/claurst-acceptance/workspace`。

Computer Use 选择该文件夹，粘贴并核对上文第 3 步的完整中文任务后发送。新候选直接进入运行状态，没有再次要求钥匙串授权。任务最终显示失败；助手回复称已生成 `materials-check/main.tex`、编译出 `claurst-latex-JsXp4/main.pdf`（一页、86 KiB、无编译警告），并报告表格与图像数值冲突及原件摘要未变。这些是模型报告；独立页面核对、七份原件摘要核对尚未完成，不能直接记为通过。

任务明确报告 `scanned.pdf` 与 `printed.png` 的本地 OCR 失败；模型通过图像看到数字不能代替本地 OCR 验收。来源面板可见 `main.pdf` 入口，其余来源、计算记录及成果操作继续待验。

### 客体 OCR 最小复现

在客体 Terminal 直接执行包内组件（不安装编译工具、不经过模型）：

```sh
"$HOME/Downloads/Claurst Desktop 2.app/Contents/Resources/claurst-document-parser" ocr-image 1 1 < "$HOME/Downloads/claurst-acceptance/workspace/printed.png"
```

返回 JSON 的 `error` 为“本地文字识别组件不可用或执行失败；请更新 macOS 并重试，未取得可核对内容”，`parts` 为空；不能只据进程退出码判通过。独立诊断副本保留相同解码、语言、revision 与 CPU 配置，仅输出 NSError 的域和编号，在客体取得 `TextRecognition.CRImageReaderError / 9`。同一诊断组件和同一图片在宿主允许系统框架访问的执行环境中成功识别出银杏、SCAN-731、73 元及两个金额。宿主沙箱内另有 Foundation 错误，已与客体 error 9 分开记录。

诊断程序和源码放在忽略的 `.build-tools/clean-mac/ocr-diagnostic`、`ocr-device-probe` 中，未修改产品或替换候选组件。最初因客体自身锁屏暂停对照；用户登录后取得以下结果。

### OCR 设备与输入对照

同一客体、同一 `printed.png` 的诊断结果：旧 SDK 的 `usesCPUOnly=true` 和默认设备选择均为 `TextRecognition.CRImageReaderError / 9`；新 SDK 构建保留旧 CPU 设置或逐计算阶段显式选 CPU 也均为 error 9。后者列出的设备包括 Apple Paravirtual GPU 和 CPU，不能把“已选择 CPU”当作系统模型实际避开所有 GPU 路径的证据。

另一个仅用于诊断的 `ocr-input-probe` 比较原双语输入、仅英语、英语 revision 2 和 RGB 重绘。双语与 RGB 重绘仍为 error 9；两种英语路径返回 `Foundation._GenericObjCError / 0`。四种配置均通过 supported languages 检查后在 perform 阶段失败，没有识别出预期标记。诊断脚本按 JSON 内容检查，不能按组件退出码判断成功。

客体统一日志显示 `ocr-input-probe` 在初始化方向校正模型时出现 `E5RT Error: e5rt_e5_compiler_compile call failed (Code: 11)`，随后 `Could not initialize orientation corrector!`，内层错误为 `TextRecognition.CRImageReaderError Code=1`。日志中被系统隐藏的内容保持 `<private>`，没有开启敏感日志。这把失败缩小到系统识别模型初始化/编译路径，但尚不能确定是虚拟设备限制、操作系统回归还是其它资源条件。没有采用未经验证的生产修复，也没有把图像目视转写冒充本地 OCR。

### 精确与快速模式的后续对照

2026-10-23 检索到另一项目维护者的[独立复现与修复记录](https://github.com/LorcanChinnock/shot/pull/818)：其 macOS 27 虚拟机同样出现 `e5rt_e5_compiler_compile` 失败，精确模式在 GPU、CPU 及不同 revision 下都失败，快速模式可运行；相同代码在实体 Mac 可运行。对应[诊断程序及结果说明](https://github.com/LorcanChinnock/shot/pull/817)可检查。此为开发者的一手报告，不是 Apple 的根因确认，也不能代替本项目客体实测。该项目另有并发请求死锁，本项目当前最小复现是单进程内单次同步请求，没有据此引入并发方面的改动。

新诊断副本 `ocr-fast-probe` 保留当前组件的图像解码、revision 3、CPU 配置与语言校正设置，比较 `accurate-english`、`fast-english`、`fast-bilingual`。前两项仅改变识别模式，后两项仅改变请求语言；启动前检查模式的实际支持语言，缺少中文时拒绝继续。诊断源码、组件与脚本仅存放在忽略的 `.build-tools/clean-mac/`，没有替换产品组件或修改签名身份。

宿主实际运行 `bash .build-tools/clean-mac/shared/ocr-fast-compare.sh .build-tools/clean-mac/ocr-diagnostic/printed.png`：精确英语与快速英语均识别出 `SCAN-731` 和 `73` 标记，但中文被误读。快速模式的支持语言为 `en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR`，不含中文；双语模式因此返回空 `parts` 和明确错误。脚本因一项未通过返回 1，不能将两个英文标记通过等同于中文 OCR 验收。输出 JSON、文字与 stderr 保存在 `.build-tools/clean-mac/ocr-fast-host-results/`。

组件 SHA-256 为 `f46b5d30d98d33784c6e100b099a19e070258ddb6b62db146edf3bf33e62074f`，合成图片 SHA-256 为 `bb4f037485b9d8e3fc668b291016990c287bc7ee2ddf3ded3939509dd7274884`。同一组件的客体对照待本机解锁后执行。现有证据不支持把快速模式作为本项目中文识别的修复，干净环境 OCR 仍未通过。

### 后续扫描验收的适用路径

复核第 12 项和首版规格，要求是优先本地识别，并允许使用用户配置且已验证具备图像能力的非 Claude 服务；没有要求每种受测环境的系统 Vision 都必须成功。下一步在同一干净客体、同一候选与已配置 Qwen 下，实际通过 `ReadImage` 核对 `scanned.pdf` 两页和 `printed.png`，检查关键文字、数字、页码和来源窗口，再保存真实结果。本地 OCR 失败继续列为该 macOS 27 虚拟机的限制，不能记为已修复；视觉路径只有实际通过后才可计入扫描识别验收。此路径沿用已确认规格，未新增服务或扩大数据范围，当前尚未补验通过。

### 实际页面、来源与重开检查

通过客体「素材与成果」打开并放大 `main.pdf`，实际看到一页中文说明、区域对照表、缺失值与素材冲突说明，以及本地 OCR 失败的保留说明；未见明显裁切或溢出。成果操作的「在 Finder 中显示」定位到 `claurst-latex-JsXp4` 并选中 `main.pdf`，同目录可见 `compilation.txt`、`main.aux` 和 `main.log`。

来源预览实际打开 `notes.md`，显示完整路径及第 1–4 行；打开 `sales.xlsx`，显示「交易」工作表第 1–5 行、第 1–4 列、具体单元格、公式缓存值和缺失值说明。其余来源和汇总记录尚未逐项核对。虚拟机滚动方向与宿主相反，列表通过滚动条和滚动操作可继续访问；点击文件标题可打开来源预览。

通过应用菜单正常退出，再从 Finder 打开同一 `Claurst Desktop 2.app`：原任务、回复、工作范围和模型名恢复；重新打开 PDF 成果显示第 1/1 页，日志标签也能读取已保存编译日志。随后发送继续验收指令：读取 `notes.md` 并创建内容为“验收继续成功”的 `result.txt`，不修改其它文件；任务成功。文件修改预览显示新建差异 `@@ -0,0 +1 @@` 与 `+验收继续成功`；「打开文件」在系统 TextEdit 中显示同一内容，「在 Finder 中显示」选中工作目录中的 `result.txt`。

### 原件保护、停止与草稿恢复

在客体 Terminal 使用系统 `shasum -a 256 -c`，对照只读共享卷中从原始合成素材归档生成的 `originals.SHA256SUMS`，七份原件 `notes.md`、`scanned.pdf`、`report.docx`、`sales.xlsx`、`report.pdf`、`sales.csv`、`printed.png` 全部返回 OK。另用 `wc -c` 和 `cat` 核对 `result.txt` 为 19 字节、内容“验收继续成功”。这是独立文件检查，不再仅依赖模型报告。

发送只在对话输出不少于 3000 字说明、不得调用工具或修改文件的测试请求；界面进入“运行中”后点击停止，状态变为“已停止”，显示本次执行没有返回文本。输入 `draft-check-731` 后新建任务、再切回原任务，草稿逐字恢复，发送按钮可用，历史与停止说明仍在。不将界面停止扩大解释为服务端计费或推理已终止的证明。

CSV 来源预览显示 `sales.csv` 第 1–6 行，保留带逗号字段、跨行字段和华西缺失金额；它是原始文本读取记录，不能替代表格计算记录。PDF 来源预览显示 `report.pdf` 第 1–2 页：第一页项目银杏、预算 73 元；第二页校验码 P2-418、预算不含税，且注明仅提取文字层、未做 OCR。

PDF 来源的「打开原文件」成功调用客体系统预览，显示 `report.pdf` 第 1/2 页与两页缩略图，第一页银杏、73 元可见。继续核对 Word 与计算记录时，本机再次锁屏；这两项尚未据界面确认，不以已有模型回复代替。

### 解锁后的来源补验

用户再次解锁本机后，实际打开 `report.docx` 来源窗口：完整路径为 `/Users/a123/Downloads/claurst-acceptance/workspace/report.docx`，第 1–4 段/共 4 段依次为项目银杏、预算 80 元、空段落/图片未进行 OCR、表格标记 DOCX-731。窗口保留正文按 XML 顺序计段、不提供固定页码，以及页眉页脚等未读范围的说明。Word 来源检查通过。

原任务的 `scanned.pdf` 第 2–2 页/共 2 页来源实际打开，明确标为“供模型查看的图像记录”，生成尺寸为 1600×1200，保留图像生成不证明服务接收或理解的说明。此窗口本身不计为文字识别通过。另建无先前答案的新任务，提交只读视觉核对与表格分组汇总要求，沿用同一工作区与 Qwen 配置；进入运行状态，无新增钥匙串授权。该任务随后完成，实际结果如下。

### 视觉扫描与真实计算补验通过

新任务要求用 `ReadImage` 分别查看两页扫描 PDF 和图片，再以 `AnalyzeTable` 分别汇总 XLSX「交易」表及 CSV；提示没有提供预期数字或校验码。任务显示“完成”。实际回复的第一页与 `printed.png` 均为项目银杏、预算 73 元、华东 13.25、华西 7.50、SCAN-731；第二页为“第二页 SECOND-418”和“原稿缺页须对照原件核查”，没有据该文字推断原稿真的缺页。通过来源的「打开原文件」在客体系统预览中逐页查看 `scanned.pdf`（1/2、2/2）及 `printed.png`，以上关键文字和数字逐项相同。

新任务来源列表保留扫描 PDF 第 1–1 页、第 2–2 页及图片第 1–1 张的独立记录。实际打开第二页和图片记录，完整路径、归一化尺寸（分别 1600×1200、1200×900）、原文件未改及识别仍需核对的说明均存在。任务工具记录有完成的 `ReadImage`，不是仅凭来源生成就断言识别成功。

实际展开两条 `AnalyzeTable` 工具记录核对：按 A 列区域分组、B 列金额十进制精确相加，范围 A2:A5 与 B2:B5，共 4 条数据；缺失跳过并计数，不填零，不执行公式、不使用公式缓存。两份文件均得到华东 13（2 有效、0 缺失）和华西 7（1 有效、1 缺失，B5）；来源单元格分别为 A2/B2、A4/B4 和 A3/B3、A5/B5。回复与工具结果一致，并明确 XLSX 其它工作表不参加计算。

初答仍出现未经证明的推断：将 SCAN-731 与 EXCEL-731、SECOND-418 与 SHEET-418 称为“对应”，并从区域标签相同扩大为口径一致。验收者明确要求只修正结论、不调用工具或改文件后，模型撤回这些推断及缺失格导致差额的暗示，说明是否同源、同口径和差额原因均无法确定。本次记录为关键识别与计算通过、结论经一次人工纠正；不宣称整个初答无需复核。

补验后在客体 Terminal 再次运行系统 `shasum -a 256 -c` 对照同一只读原件摘要清单，七份原件全部 OK。产品主流程无需用户运行开发命令；此命令仅为验收者独立检查文件保护。

### 第 18 项完成边界

候选仍为 `candidate-mpGA4v` / 源码 `278fd7f`，本轮没有修改生产代码、替换二进制、改变签名身份或原地重写候选归档。包内真实组件回归、部署目标/系统动态依赖/固定身份和源码关联检查保留在候选回执；客体补齐了上述 1–6 步的用户可观察证据。完整运行依赖随包提供，验收期间未安装 Xcode、Rust 或 TeX。

据第 18 项第四条，明确列出未满足的公开分发条件并保留可检查本地候选，不把开发签名当作 Developer ID：正式身份、公证、浏览器下载后的 Gatekeeper 启动、产品级通知和最终许可证选择继续在第 19 项完成。最低实际验证版本是 macOS 27.0.1（此 Apple Virtualization 客体及开发宿主）；macOS 13 仅为编译目标，未实测。系统本地 OCR 在此客体仍失败，本次扫描识别依赖用户已配置并验证的 Qwen 视觉能力；不可推广为离线 OCR 或所有 Mac 通过。
