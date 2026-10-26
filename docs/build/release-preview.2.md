# Claurst Desktop 0.1.0-preview.2

2026-10-26。面向 Apple 芯片 Mac 的未公证预览版，应用内部版本为 0.1.0（构建 2）。使用固定 Apple Development 证书签名，尚无 Developer ID 公证。

## 本次更新

- 设置增加自定义指令和 Soul，支持显式保存及 SOUL.md 导入、导出。
- 默认关闭的自动记忆支持个人偏好和工作区项目事实，可查看、编辑、删除及按范围清空。开启后使用当前所选模型整理，可能增加调用用量。
- 新增临时会话：保留个性化设定，不读写记忆，不保存可恢复聊天历史；实际创建、修改的项目文件仍保留。
- 更新桌面布局、成果区域及键盘交互。

记忆和设定保存在本机，相关内容会发送到所选模型；临时会话不能控制模型提供方的数据保留。升级沿用现有模型配置、历史与钥匙串身份，建议先正常退出旧应用，再解压并打开新版本。使用步骤见[说明](../product/personalization-memory.md)。

## 验证范围

个性化与记忆的 7 项任务已验收，包括真实 TaskService → ACP → Claurst 运行时检查、正常退出和 SIGKILL 后的临时记录排除、实际桌面操作，以及 Qwen（qwen3.8-flash）的真实个性化、两类记忆提取、新会话召回和临时隔离。完整桌面回归、Swift 类型检查、Rust workspace check、严格 clippy 与受影响的 435 个库测试均通过。详情见[功能验收记录](verification-personalization-memory.md)。

模型可能不准确地描述记忆是否保存；以桌面整理提示和设置中的实际记录为准。记忆作为参考，不代表已重新核实的外部事实。

本版重新构建并检查包内签名、架构、部署目标、动态依赖、离线许可原文和源码对应，发布前执行解压包内组件的混合研究回归。实际宿主为 macOS 27.0.1；macOS 13 是编译目标，Intel Mac 与 Windows 不在此版本范围。本版未重复进行干净虚拟机首次下载和人工允许启动验收，不将[上一版记录](public-download-verification.md)作为本版已通过的证明。此前虚拟机本地 Vision OCR 失败的限制仍保留，扫描输入可使用已验证的 Qwen 图像能力。

## 下载与对应源码

在 [GitHub Release](https://github.com/m4ngod/claurst-desktop/releases/tag/v0.1.0-preview.2) 下载应用 ZIP，并核对同页的 SHA256SUMS。首次打开可能被 Gatekeeper 阻止；核对来源后按系统提示在「系统设置 → 隐私与安全性」中手动允许。不要关闭 Gatekeeper 或移除隔离属性。

同一 Release 提供匹配项目源码、第三方对应源码与重建材料、GPLv3 原文、构建清单、包检查报告、功能回归日志和文件摘要。公开源码延续现有清洁历史，未上传本地旧开发历史。精确提交和附件摘要见随包的 candidate-association.json。

项目新增代码采用 GPL-3.0-only；第三方保留各自条款。Tectonic 组合按 GPLv3、TECkit 按 LGPL 2.1-or-later、Graphite 按 GPLv3、FreeType 按 FTL 交付。应用内提供 1,364 份离线原文；详见根目录 THIRD_PARTY_NOTICES.md 和材料包。
