# 第 13 项：显式配置的联网搜索

日期：2026-10-22。实现、完整自动化回归、签名构建及真实 Qwen 搜索到正文引用的验收已通过；验收中发现的 ACP 长消息保序修复也已通过最终回归与复审。第 13 项验收完成。

## 路径与兼容依据

- 继续使用 Claurst 的工具执行和权限通道、现有 HTTP 依赖。上游默认 DuckDuckGo Instant Answer 不符合完整检索要求，桌面不注册其默认路径。
- 模型设置新增明确的搜索开关，默认关闭；开启后使用所选配置的地址、模型和钥匙串凭据请求 `/responses` 的 `web_search`。不读取环境搜索密钥、不切换服务或模型。旧配置未含开关时保持关闭；同服务修改开关不更换密钥或签名身份。
- 选用此路径的依据是 [阿里云 Token Plan 个人版](https://help.aliyun.com/zh/model-studio/token-plan-personal-overview)公开支持内置搜索，以及 [联网搜索文档](https://help.aliyun.com/zh/model-studio/web-search)说明返回 `web_search_call.action.sources`。用户现有 Token Plan endpoint 与 Qwen 配置无需为此传给其他地址；实际兼容性仍须以真实验收为准。
- 请求采用 `store: false`，并明确请求 `include: ["web_search_call.action.sources"]`，兼容要求显式返回来源的 Responses 服务。阿里云未列出的参数会忽略；不据此承诺每家 OpenAI 兼容聊天接口都支持搜索。来源结构依据 [创建响应](https://help.aliyun.com/zh/model-studio/qwen-api-via-openai-responses)；显式 include 依据 [OpenAI 搜索文档](https://developers.openai.com/api/docs/guides/tools-web-search)。

## 可观察行为

- 只发送检索词，不发送整段任务历史或本地文件。设置页说明检索词接收方及额度消耗，明确连接检查并不验证搜索；搜索不支持、没有实际记录或失败时在任务中报告。
- 搜索响应及调用状态必须完成；只接受 `action.type=search` 的 `sources.type=url`。拒绝非 HTTP(S)、含凭据或过长链接，去重并最多返回 20 项；缺失标题明确显示。模型生成文本、URL 引用注释和计数不能替代搜索记录。
- 记录用户检索词、所选服务与模型、访问时间及候选链接；候选未读正文，不加入已读取网页来源。模型须进一步调用 WebFetch，成功正文才能生成可定位引用。
- 请求不跟随重定向，不使用环境代理；最多 2 MiB、60 秒。HTTP 错误不回显响应体，停止取消正在等待的请求，没有服务回退或迟到结果。
- 开关在下一次开始或继续执行时应用。运行中补充要求会取消当前轮，并用该任务原配置的最新开关续跑；不会因界面选中了另一模型配置而静默切换当前任务的服务或凭据。

## 验证

使用既定 TaskService → ACP → 实际工具入口；仅替换模型/搜索/网页 HTTP 边界。测试凭据是合成数据，独立钥匙串条目在结束时清理，不读取用户真实密钥。

- 注册前先得到 Unknown tool: WebSearch，接入后返回实际搜索记录中的链接，排除生成回答中的虚构 URL。
- 配置保存、重开恢复、空闲任务关闭搜索均有先红后绿验证；完整 profileID 入口还复现并修复了运行中关闭搜索后补充要求仍沿用旧设置的问题。
- 请求未显式 include 时，替身仅返回完成记录而不返回来源，测试先失败；添加 include 后通过。缺失调用完成状态的响应同样先被误接收，严格校验后失败且不生成来源。
- 搜索→候选链接→真实网页工具→正文行号→引用的完整链路读取到“银杏预算：73 元”；搜索候选本身不是正文证据。
- 覆盖无搜索记录、空结果、非法链接、未完成响应、HTTP 401、超大响应、取消及 60 秒超时。错误体中的合成密钥不进入对话；取消先确认请求已到达 HTTP 边界，随后 2 秒内结束，无迟到候选。

日志：`.build-tools/web-13-search-*.log`（未纳入 Git）。入口：`scripts/test-desktop.sh`；独立 `.build-tools/task-search-test --quick` 省略 60 秒超时用例。

完整回归：`cargo check --workspace`、`cargo clippy --workspace --all-targets -- -D warnings` 通过；Rust 共 32 组、2284 项通过、0 项失败、1 项忽略。`scripts/test-desktop.sh` 的 13 套集成测试及单独的 90 秒图像能力超时用例通过，包含搜索 60 秒超时。日志为 `.build-tools/web-13-search-{check,clippy,rust,desktop}-final.log`。

固定审查基点 `06367f168c01aef43ff1865980360e83c752b916`：规范与规格两路审查均已复核，原有运行中撤销开关及来源字段请求问题已解决，没有新的实质问题。审查没有把确定性网络替身算作真实搜索验收。

新构建位于 `.build/desktop-builds/build-ehVUOc/Claurst Desktop.app`；应用标识仍为 `local.claurst.desktop.dev`，指定身份仍绑定叶证书 SHA-1 `cc8130a1b3c342937779101fcd1fed515fcca409`。使用同一证书签名所有内嵌程序，保留不可变构建目录；没有改回临时自签名。

## 真实 Qwen 验收与长消息修复

用户解锁后，Computer Use 在模型设置开启搜索并保存，保持原 Qwen 密钥。首次搜索在 `2026-10-22T05:06:01Z` 返回 17 个实际候选；随后的网页工具出现连接中断。再次读取遇到真实的 30 秒网页超时，界面报告失败且没有生成已读来源，模型没有据此编造答案。

该中断用同一已签名运行时和本地 HTTP 长中文网页复现。诊断发现一条 167357 字节 ACP 消息在第 81920 字节边界混入其他段，破坏 JSON/UTF-8；父进程解析失败后才终止运行时，并非运行时先崩溃。原实现为每个管道数据块独立启动 MainActor Task，执行顺序不受保证。改为 AsyncStream 单一消费者；EOF 也顺序处理，避免另一个进程退出回调抢先丢弃尾部数据。主动停止仍立即关闭连接。

`TaskWebTests` 新增 12 次真实 WebFetch 长消息及模型回传回归：400 段中文经 TaskService → ACP → 工具传回，核对任务、工具、来源总行数、末尾内容与回答。先红后绿日志分别为 `.build-tools/web-13-order-red.log`、`.build-tools/web-13-order-green.log`；诊断仅用合成密钥，未访问用户真实凭据。

修复构建 `build-DfaECc` 复用 `build-ehVUOc` 已验证的运行时和解析器，重新编译桌面 Swift 并用相同证书、标识、指定身份签名；没有混入仍在开发的 LaTeX 工具。实际验收过程如下：

- `2026-10-22T05:24:35Z`，所选 Token Plan endpoint / `qwen3.8-flash` 的 WebSearch 返回 20 个实际候选，第一项为 `https://docs.searxng.org/dev/search_api.html`；未提供标题的候选如实显示缺失。
- `2026-10-22T05:24:41Z`，WebFetch 从该候选读取成功，标题为 `Search API - SearXNG Documentation (2026.10.19+81371861f)`，正文共 239 行，读取范围 1–239。两项执行记录均为完成，任务最终完成。
- 回答给出 `403 Forbidden`，依据为正文第 182–186 行；第 218–219 行说明格式需要启用。Computer Use 打开「素材与成果」来源，逐项核对 URL、访问时间、标题、行号及正文；再点击回答内的来源链接，确认打开同一份正文。
- 全程只执行 WebSearch、WebFetch，没有本地文件读写。此新签名构建使用已有 Qwen 凭据，没有出现新的钥匙串授权提示。

原网页打开与窄窗口操作的实际验证见 `verification-13-web-fetch.md`。本次没有将搜索候选当作已读正文，也没有把失败请求算作通过。

最终 `build-CluCow` 还包含 EOF 收尾调整，同样使用固定签名并通过严格深层验证。Computer Use 关闭上一验收窗口、打开此构建，恢复已完成任务后继续读取同一搜索候选：`2026-10-22T05:28:57Z` 生成新来源，239 行完整读取，工具与任务均完成，一句话回答及第 182–186 行引用正确；原搜索记录、旧来源与新来源同时保留，没有重放旧工具。再次使用原凭据，无钥匙串提示。

修复审查基点 `f9e3fa6`：规范轴无实质问题；规格轴指出原有独立退出回调可能抢先关闭管道，删除后已复核关闭。两轴最终均无未解决项。最终完整桌面回归的 13 套集成测试与单独的 90 秒图像能力超时用例全部通过，包含 12 次长中文消息、60 秒搜索超时；日志为 `.build-tools/web-13-order-desktop-final.log`。本轮修复仅改桌面 Swift 和网络回归用例；运行时搜索代码沿用前述完整 Rust 验证。不将尚未交付的 LaTeX 原型算作已验证能力。
