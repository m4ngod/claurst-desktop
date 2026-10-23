# Rust 依赖许可依据与对应源码

这些材料用于补充 `rust-notices`，尚不作为版本原件齐全或产品可公开分发的结论。`sources.json` 分别记录实际 crate 的版本/VCS、Cargo.lock 对应归档摘要、归档内来源文件及外部材料的来源与摘要。

- `selectors 0.41.0`：已发布归档的 15 个 Rust 文件均保留 MPL 2.0 文件头通知。此处保存 [Mozilla 官方 MPL 2.0 原文](https://www.mozilla.org/en-US/MPL/2.0/)，原文下载地址与摘要另记；不将它描述为 crate 内的独立 LICENSE 原件。
- `sse-stream 0.2.3`：实际 `Cargo.toml.orig` 声明 `MIT/Apache-2.0`。其独立 LICENSE-MIT、LICENSE-APACHE 是[后续提交 9b95874](https://github.com/4t145/sse-stream/commit/9b95874ca02cc337b9f86b54915ba6c6b27821d0)才加入的，该提交的 Cargo.toml 已为 0.2.4。按原字节保存在 `later-upstream`，不冒充 0.2.3 原件；对旧版本的适用性仍待确认。

运行 `scripts/collect-third-party-notices.py` 时，收集器按 Cargo.lock 校验依赖闭包中所有注册表归档并复制到输出的 `rust-sources`。本目录的两个专项记录复用其中对应归档，再校验实际 crate VCS、许可声明及列出的来源文件。原始文件头和声明随完整归档保留；外部材料另存 `rust-evidence`，不会据此清空“缺独立通知文件”的记录。本地项目子包另记仓库相对路径，须配合匹配 `app_source_revision` 的项目源码 ZIP；此闭包不等于整个产品所有排版/原生组件及工具链运行库的对应源码均已收齐。

来源文件与许可证均按原字节保留。后续升级依赖时必须重新核对，不能沿用旧版本的关联。
