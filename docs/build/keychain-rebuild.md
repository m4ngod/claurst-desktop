# 开发构建覆盖运行应用导致身份失配

日期：2026-10-21。环境：Apple 芯片 Mac、macOS 27.0.1。用户重新输入 Qwen API Key 后仍收到钥匙串错误；此记录不包含真实密钥。

## 证据与判断

旧构建脚本反复替换 `.build/Claurst Desktop.app`。两个仍运行的应用进程对该路径执行动态签名验证时，均报告 `the code on disk does not match what is running`。隔离验收包的进程没有该动态身份失配。

使用独立测试服务名、固定无价值测试数据的 Swift Security 探针验证真实钥匙串：先启动程序并保存、读取成功，再原子替换其磁盘可执行文件。替换后新建测试凭据返回成功，但随后读取新凭据超过 8 秒仍未返回；对照组只把新构建写到另一个路径，原进程保存和读取新凭据均立即成功。测试项已按专用服务名清理，不改动用户模型凭据。

复现记录位于本地调试目录 `.build-tools/keychain-rebuild/new-entry-result.log` 与 `isolated-new-entry-result.log`。先前仅读取旧凭据的探针仍能成功，不能覆盖用户“重新保存后读取”的触发条件。因此回归判断以新建凭据为准。

这些证据确认了开发流程中的运行身份失配及对应的钥匙串阻塞。用户实际服务在新包中的保存、读取和连接仍须验收，不能据此宣称所有钥匙串错误均已消失。共用 API Key 不是该本地身份问题的触发条件。

## 修复与验证

- 每次开发构建使用新的应用目录，保留旧运行包的文件身份。
- 完成编译后对新包作本地 ad-hoc 签名并严格验证，成功后才原子发布最新构建路径。
- `scripts/open-desktop.sh` 打开最新构建的新实例。用户应先结束旧开发应用，避免继续操作旧进程。
- `scripts/test-build-isolation.sh` 连续构建两次，断言路径不同、首个可执行文件校验和未变、两个包签名均有效。修复前因缺少最新独立构建路径而失败，修复后通过；记录见 `.build-tools/build-isolation-red.log` 与 `build-isolation-green.log`。

本次没有放宽钥匙串访问控制、导出真实密钥或改用明文存储。本地 ad-hoc 签名不是正式发布签名；跨构建读取旧凭据及正式分发仍需相应验收。已有 05 代码完整检查结果见 `verification-05.md`，本修复只变更开发构建与启动脚本。

## Standards

对三个脚本、相对 `e4ee9a4` 的修改独立审查：未发现规范违反、实质正确性问题或需单列的代码气味。独立目录避免覆盖，签名失败不更新最新路径，指针原子发布，启动脚本明确打开新实例。构建回归不直接验证真实钥匙串，需要结合上述真实探针对照及用户连接验收。

## Spec

独立审查未发现明确规格缺陷或范围扩张。用户“重新保存 Qwen 密钥仍报错”尚未完成验收，仍需新包中的保存、读取及真实连接成功；不得将本次修复描述为钥匙串问题全部解决或正式签名分发完成。

两个审查轴各 0 项代码缺陷；共同保留真实服务验收缺口。

## 新包实际验收

2026-10-21：用户在本修复构建的新窗口重新输入 Qwen 密钥并执行「保存并检查连接」，回复「连接成功」。该操作覆盖新包中的保存、读取及真实连接，本次报告的故障已恢复。以上审查时的待验收项据此补齐；这不扩大为所有系统钥匙串情形或跨版本分发均已验证的承诺。


## 2026-10-22：固定证书、标识及身份要求

用户要求后续构建持续使用同一证书、应用标识和兼容身份要求。新增一次性 `setup-dev-signing.sh` 和构建共用的 `signing-identity.sh`：证书指纹保存在忽略的本地配置；私钥留在钥匙串；普通构建不自动生成、切换或降级签名。主应用仍使用 `local.claurst.desktop.dev`，各运行组件使用固定子标识。身份要求为应用标识加签名证书指纹，不包含单次代码哈希。

本机初始没有代码签名身份，已生成一份仅供本地开发的自签证书。重复设置复用同一证书；可以用 `setup-dev-signing.sh --identity <SHA-1>` 显式选择已安装且有效的 Apple 签名身份，例行构建不会替换。没有修改旧模型凭据的 ACL、系统信任设置或凭据存储方式。

静态回归：旧的两个 ad-hoc 包运行 `test-signing-continuity.sh` 报告不同身份要求（`.build-tools/signing-continuity-red.log`）。新版本 `test-build-isolation.sh` 连续构建两个完整应用通过：旧包字节不变、两包签名有效，互相满足相同身份要求（`.build-tools/stable-signing-app-builds.log`）。

### 真实钥匙串验证仍未通过

仅比较签名不足以证明免授权。`test-keychain-signing.sh` 编译两个代码不同、证书和标识相同的原生测试包，另加临时签名的负例。通过 Computer Use 分别启动、运行并退出，使用独立服务名和无价值测试凭据，调用真实 TaskService。测试进程显式 `SecKeychainSetUserInteractionAllowed(false)`；仅设置 `LAContext.interactionNotAllowed` 不能可靠阻止传统钥匙串 ACL 交互，早期测试结果因此不计作通过。

最终对照：首次保存通过；错误签名读取被拒绝；同证书的新代码读取也被拒绝。因此本次不能宣称重复授权已解决。只读检查该测试条目发现 `ACLAuthorizationPartitionID` 仍记录 `cdhash:<首次构建哈希>`。这与 [Apple securityd 实现](https://github.com/apple-oss-distributions/Security/blob/main/securityd/src/clientid.cpp#L176-L274)一致：认可的 Apple 开发/分发证书使用团队身份分区，其他签名退回代码哈希。固定自签证书及 DR 无法单独消除这个额外条件。

测试结果保存在本机 `.build-tools/signing/keychain-test-9kgcX1/*.result`；两轮临时测试凭据均已按唯一服务名删除，未接触真实模型密钥。需要 Apple Development 或 Developer ID Application 签名身份后，重新跑同一原生正负例验证。旧身份凭据迁移时仍可能需要用户首次系统授权，不可承诺所有系统锁定或授权情形都免交互。

关于 DR 的依据：[TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)。签名脚本及表格变更经过 Standards、Spec 两轴静态复审，均无新增实质问题；上述真实兼容性缺口明确保留。

## Apple Development 跨构建对照通过（2026-10-22）

用户创建 Apple Development 证书后，已确认对应私钥存在。最初 `security find-identity -v -p codesigning` 返回零有效身份，证书验证报告缺少中间证书。按 [Apple 官方证书目录](https://www.apple.com/certificateauthority/)补齐 WWDR G3，验证其链到系统已有 Apple 根证书后，身份成为有效签名身份；没有新增根信任或放宽现有密钥 ACL。构建配置已显式固定到这份 Apple 证书，用户完成首次 codesign 私钥授权。

首次原生测试将数据放在 Documents 下，错误签名构建卡在配置文件的 `open`，尚未触及钥匙串，因此不能算作负例通过。采样见 `.build-tools/apple-signing-negative.sample`。测试脚本现把三个应用和无价值配置放在 `/private/tmp` 下，避开与本项无关的 Documents 隐私权限。

通过 Computer Use 独立启动三个应用并逐一运行、退出，结果全部通过：首次构建保存成功；临时签名的错误身份被拒绝；同一 Apple 证书、同一标识、代码不同的新构建成功读取已有测试凭据。测试进程禁止钥匙串交互，因此正例覆盖了“不需重复授权”。验证命令为 `scripts/test-keychain-signing.sh verify /private/tmp/claurst-keychain-test-Qp3RlR`，日志见 `.build-tools/apple-keychain-signing-build-2.log` 及 `apple-keychain-results/`；专用测试凭据已删除。

完整应用的 `test-build-isolation.sh` 同样通过：连续两个构建均使用固定身份，互相满足相同身份要求，旧包字节和签名未变。见 `.build-tools/apple-signing-app-builds.log`。此结果证明新 Apple 身份下的构建连续性，不代表旧自签身份保存的真实配置已经迁移；首次读取旧凭据仍可能要求用户授权。证书到期或更换时必须显式处理，普通构建不会自动轮换。

随后用户在 `build-eSn9eF` 中完成旧 Qwen 凭据首次授权，真实模型调用成功。通过 Computer Use 退出该实例、启动另一份 Apple 签名 `build-jhzTFK`，新建任务发送“只回复：跨构建连接正常。不要调用任何工具。”；应用直接进入运行并完成，Qwen 回复“跨构建连接正常。”，无需再次处理钥匙串提示。这补齐了本机已有 Qwen 配置跨两份构建复用的实际证据，仍不扩大为其他凭据或证书续期的保证。
