# 09 · 修复代码与真实检查

日期：2026-10-21。基点：bbacd8b。实现、完整回归、两路审查修复及真实 Qwen 原生窗口验收完成。

## 实现

`tests/fixtures/search-project` 是明确标注的故意含缺陷项目。`set_status` 创建新状态时丢失搜索词；已有排序、目录结构和检查文件须保留。测试将它复制到临时工作区，另加随机用户备注。先用真实 Python 复现失败，再通过 TaskService → ACP → Read/Write/Bash 修复，最后执行 3 项实际 unittest。

Write 可携带修改原因，持久化到实际修改记录并在侧栏与差异预览显示，标为助手说明；没有理由不自行补造。Bash 的 `check_name` 将命令标为项目检查，回执由工具根据真实退出结果生成。`skip_reason` 仅记录主动跳过与原因，绝不执行该命令；前置拒绝标为未运行，缺少结果回执标为未确认。侧栏说明检查只代表当时命令结果，任务结束不等于所有问题已经验证解决。

修复 Command Line Tools Python 启动所需的父路径元数据权限；既有只读工具链目录范围、工作区写入及禁止网络的边界不变。

## 验证证据

- `.build-tools/coding-09-red.log`：实际 Python 启动被 `realpath` 元数据限制拒绝；补齐已有工具链父路径元数据后 `coding-09-green.log` 通过。
- `coding-reason-red.log` → `coding-reason-green.log`：实际文件差异保留助手修改原因。
- `coding-check-red.log` → `coding-check-green.log`：命名检查获得真实通过回执。
- `coding-skip-red.log` → `coding-skip-green.log`：跳过保留原因且标记文件未创建。
- `coding-outcomes-green.log`：无检查时模型文案不创建回执；未解决缺陷的真实检查失败，即使模型声称「已验证完成」，状态仍失败；修改与用户备注保留，继续修复可通过，重开历史仍有真实失败及成功记录。

## Standards

Standards 首轮 1 项 P2：断线后旧检查会随任务继续而重新显示运行中。以真实 ACP 进程中断复现（`coding-disconnect-red.log`），按回合标识固化未返回工具与检查为未确认，并处理关闭；`coding-disconnect-green.log` 通过。复核未发现新问题。

## Spec

Spec 首轮 1 项 P2：带有效检查名但参数无效时漏发未运行回执。`coding-invalid-red.log` 复现，解析失败保持合法检查名并返回 NotRun；`coding-invalid-green.log` 通过且未创建命令标记文件。复核未发现新问题。一次复核服务容量失败后重试成功。

## 原生窗口

`build-z2Bln7` 构建及严格签名检查通过。Computer Use 选择 `/private/tmp/claurst-coding-check-vxbhxf14/workspace`，确认项目检查初始显示「未运行 · 尚无项目检查记录」，发送真实 Qwen 编程任务。凭据读取随后正常返回，真实 Qwen 完成 Read/Write/Bash 流程。差异只将 set_status 的构造替换为 replace，模型理由实际显示；CLT Python 命令真实输出 3 个用例 ok、Ran 3 tests、OK，退出码 0。

模型首个检查追加了 `echo EXIT=$?`，导致系统 python3 垫片失败被包装命令最终的退出码 0 掩盖。模型说明了此问题并改用 README 的 CLT 绝对路径重跑成功；首次记录仍完整保留。窗口验收据此将侧栏「通过 · 退出码 0」改为事实性的「命令退出码 0」，并提示退出码仅反映整条命令、须核对输出，不从任意 shell 命令推断全部检查通过。此为显示文案修正，不改变执行或回执判定。

## 完整检查

首次六组桌面套件 `desktop-tests-09.log` 全部通过。审查修复后的并行运行 `desktop-tests-09-final.log` 在既有大文件外部编辑样本超过 20 秒时限（TaskServiceTests:275），没有放宽断言；其它 Rust 检查结束后单独重跑，`desktop-tests-09-recheck.log` 六组全部通过；未修改时限或冲突断言。Rust `check-09-final.log`、`clippy-09-final.log` 和 `tests-09-final.log` 已通过：31 组，2284 通过、0 失败、1 忽略。

修改的 Rust 文件已 rustfmt。全工作区格式检查 `fmt-09-baseline.log` 仍报告未触及的上游既有格式差异，未批量改写。开发构建存在 btls-sys 缓存的两个缺失链接搜索目录警告（实际 libssl.a/libcrypto.a 在 build 根目录且链接成功）；工作区 check 与 Clippy 没有警告。本项没有修改依赖构建逻辑。

Computer Use 另建状态验收任务：实际命令路径不存在，保留退出码 127 与错误，显示失败；带 skip_reason 的调用显示已跳过且解释没有执行；空命令被启动前校验拒绝，显示未运行。整体任务仍失败。`build-Yj3KMA` 重开后来源、原因、检查记录完整，命令退出码标签已更新；宽、窄布局均可滚动操作。检查文件与固定样本逐字节一致，磁盘用户备注仍保留。

最终 `build-T8hNw2` 构建及严格签名校验通过；Computer Use 重开历史并放大窗口，截图确认项目检查标签和完整说明可读，无截断。最后仅调整显示文案与换行，未改变经过完整套件验证的执行逻辑。
