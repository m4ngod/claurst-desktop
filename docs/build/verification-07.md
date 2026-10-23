# 07 文件整理与恢复验证

日期：2026-10-21。基点：`5651e47`。实现提交：`6b036af`。自动回归、两路审查与最终构建真实窗口验收均通过。

## 实现

Move、Delete 通过真实任务入口执行，使用已有工作区写入授权边界。目录内自动执行，越界逐次授权。操作前保存私有恢复记录；移动使用目录句柄与排他重命名，目标已占用时失败。删除前保存原始字节与权限。操作前后核对已打开文件身份、内容与元数据，不声称能够与所有外部编辑器绝对互斥。

文件修改预览提供本地恢复入口，直接调用 ACP 文件恢复方法，不加载密钥或请求模型。删除恢复独占创建原路径；移动恢复核对移动后字节并拒绝占用的原路径；文本修改恢复核对写入后字节。失败保留当前文件，显示原因和记录路径。历史保存恢复结果；继续对话前重新载入可见历史和读取版本。

支持范围见 README。移动与删除支持至多 32 MiB 的普通文本和二进制文件；父目录须存在，移动须在同一卷。恢复删除不保留扩展属性、ACL、硬链接关系与时间戳。目录、符号链接、外部命令不在恢复范围。

## 自动验证

TaskOrganizeTests 只替换模型 HTTP 边界，TaskService、ACP、工具、文件与历史均真实执行。

已完成逐项红→绿：二进制移动、二进制删除、重开后无需模型配置恢复删除、恢复移动、恢复文本覆盖。对应 `.build-tools/organize-07-*-red.log` 与 `*-green.log`。

`.build-tools/organize-07-conflicts.log` 已通过：后续编辑、移动目标冲突、恢复原路径冲突、删除后的新占用、越界删除拒绝/授权、越界恢复重新授权、等待授权期间新建任务不会串写状态、恢复结果重开后保留、超大文件删除拒绝。

33 MiB 新建写入先在 `.build-tools/organize-07-large-red.log` 复现未拒绝，再加入写入上限；最终完整桌面回归通过。覆盖前的原文件也限制为 32 MiB，避免产生无法自动恢复的改动。

目录重定向在完整任务入口复现：写入后把原目录改名，再以符号链接指向内容相同的另一目录，旧实现会错误覆盖替代文件。`.build-tools/organize-07-parent-red.log` 为红灯。新增记录保存原目录设备与 inode，恢复同时要求规范路径未重定向、已打开目录身份匹配。普通目录同名替换也被拒绝；`.build-tools/organize-07-parent-green.log` 通过。旧无身份记录拒绝自动恢复，仍保留材料。

最终 `scripts/test-desktop.sh` 四个入口全部通过，日志 `.build-tools/desktop-tests-07-final.log`。Rust check、Clippy 全部通过；完整工作区测试合计 2,284 passed、0 failed、1 ignored（上游 fixture），日志 `check-07-final.log`、`clippy-07-final.log`、`tests-07-final.log`。改动 Rust 文件格式检查与差异空白检查通过。独立应用构建与严格签名校验通过，日志 `.build-tools/build-07-final.log`。既有上游格式差异与 BoringSSL 链接目录警告未作无关修改或屏蔽。

## 真实模型与窗口

Computer Use 操作 `build-TVE8Dx/Claurst Desktop.app`，使用已保存的真实 Qwen，在 `/private/tmp/claurst-organize-check-ljrkz_ev/workspace` 读取并将 budget.md 的预算 73→80、Move 将 draft.txt 移至 archive/draft.txt、Delete 删除 obsolete.txt。Read、Write、Move、Delete 均显示完成，三条变化均出现于成果面板，任务完成；目录内未逐次询问授权。

依次打开三条变化并点击「恢复本次修改」，均显示已恢复；实际磁盘核对预算回到 73 元、draft.txt 回到原路径且原始内容不变、obsolete.txt 原字节恢复。记录 `.build-tools/organize-07-ui-initial.log`。退出后打开 `build-g3tpxA`，三条恢复状态及对话仍存在。

上述初次窗口构建早于目录身份审查修复；修复后的最终构建已通过全部自动回归。再次真实模型验收在读取钥匙串时弹出系统授权，应用等待 SecurityAgent；Computer Use 明确禁止操作该系统凭据应用。已请求用户处理系统提示，未读取密钥、修改 ACL 或绕过授权。未将尚未完成的最终构建模型复测记为通过。

随后最终构建 build-g3tpxA 恢复响应，真实 Qwen 完成预算 73→80、移动 draft.txt、删除 obsolete.txt。Computer Use 退出并重开同一构建，保存的三条变更及原始差异仍在；逐项点击恢复，均显示已恢复。Finder 正确选中恢复后的 obsolete.txt，打开文件后 TextEdit 显示“待删除后恢复的测试材料”。再次核对磁盘，budget.md 回到 73 元、draft.txt 回到原路径、obsolete.txt 恢复，三个文件字节与初始样本完全一致，archive/draft.txt 不再存在。最终日志 `.build-tools/organize-07-ui-final.log`，完成了先前待授权的复测。

现有历史缺失文件提示在本次恢复后未即时刷新；不影响恢复操作或磁盘结果，后续可改进提示刷新。

## Standards

发现 P1：耗时内容复核之后未再次检查目录位置。现已在完整内容检查结束后确认源目录和目标目录，再执行重命名或删除；文本替换亦增加最终目录检查。只读复核确认原问题解决，没有新增实质问题。

## Spec

发现 P1：恢复记录中的父目录被替换为符号链接时，可能改动另一目录。新增规范路径与目录身份校验，并通过真实文件红→绿回归；只读复核确认解决，没有新增实质问题。

两轴各 1 项 P1，均已解决。真实窗口验证范围单独记录，不以审查代替验收。
