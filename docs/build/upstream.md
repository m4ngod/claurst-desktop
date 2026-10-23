# Claurst 来源

导入用户提供的 `claurst-0.2.0.tar` 中 Claurst 0.2.0 源码到 `vendor/claurst`。
原始包 SHA-256：`b0341776112a9e64ae4d74d6b2aa2c24852913677e718101e25b495e59e5fefe`。
仅排除原包附带的 Python `__pycache__` 编译缓存；原包文件校验清单仍完整保存在 `upstream-sha256.json`。
上游 `LICENSE.md` 和 Rust workspace 均标注 GPL-3.0，原文和版权信息完整保留。
导入时未使用官方 Claude Code 程序。最终产品名称、发布仓库与分发身份待提供。

## 构建验证进行中

宿主：Apple 芯片，macOS 14.2.1；系统 Swift 5.8.1 / macOS 13.3 SDK。
Rust 安装到项目 `.build-tools`；不更改用户全局工具链。
桌面采用 SwiftUI / AppKit，进程边界使用 Claurst 的 ACP JSON-RPC。
现有三布局原型仅用于外观参考，正式桌面重新实现 A 布局。

上游默认加载本地设置、凭据和工具。因此桌面入口需显式指定唯一模型服务，
并拒绝未经配置的工作目录；不得直接把上游默认 ACP 入口当作已满足产品权限约束。
