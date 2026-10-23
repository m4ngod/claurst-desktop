# 真实模型编程验收

日期：2026-10-22。用户已明确取消第二家独立服务的验收要求。按更新后的范围，第 16 项完成；两个已配置模型的本机编程样例均有真实通过证据，其他错误与隐私条件保留。

## 环境与输入

实际操作 `build-7hts0W` 的桌面窗口，构建来源为 `cdf78d6`。沿用固定 Apple Development 签名、应用标识及身份要求，本轮没有新增钥匙串授权提示。真实调用均使用应用已保存配置，没有复制或导出 API Key。

| 配置 | 实际模型 | 服务 |
| --- | --- | --- |
| Qwen | `qwen3.8-flash` | 阿里云 Token Plan |
| Deepseek | `deepseek-v4.1-flash-1017` | 阿里云 Token Plan |

两者地址相同：`https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`。用户确认暂无第二家服务；模型名称不同不等于服务独立。记录的是请求所用模型标识，未独立验证服务端权重版本。

分别复制 `tests/fixtures/search-project` 到独立临时工作区，并加入合成 `user-notes.txt`。任务要求修复切换状态丢失搜索条件，保留排序、检查、目录结构和用户文件；使用 README 指定的 Python 运行真实检查，不安装依赖、不联网。两份输入一致，修改前 SHA-256 保存在本地 `.build-tools/live-16-17-workspaces.json`。

## 实际结果

两者均实际读取 README、源码和检查，运行基线得到 3 项检查中 2 项失败；将 `set_status` 的新建 `SearchState` 改为 `replace(self, status=status)` 后，真实进程返回 0，3 项检查全部通过。又分别执行一次不修改文件的最终复核，仍为 3 项通过，界面任务状态为完成。此前失败保留在检查历史中，没有用追加 echo 掩盖退出码。

磁盘哈希核对显示，原有文件中只有 `app/state.py` 改变，README、检查、`user-notes.txt` 和包初始化文件不变。两个任务的文件修改预览都显示上述实际差异；Deepseek 同时去掉末尾换行，Qwen 保留末尾换行。没有将模型的“其余不变”说明当作字节级证明。

Qwen 首次 Bash 调用携带未知 `description` 参数，工具实际拒绝并显示错误；后续使用有效参数继续完成。记录一次已观察到的参数失败，不采用模型最终回复中对失败次数的描述。界面已展开其失败详情及后续真实检查输出。

## 验收范围与错误、隐私检查

当前仍是同一服务上的两个模型，第二家服务已不再是完成条件。本轮重新运行两份工作区的 `python3 -m unittest discover -s checks -v`，各 3 项通过；按初始 SHA-256 再次核对，仍只有 `app/state.py` 改变。

完整任务边界的认证失败、配置变化拒绝发送、流式密钥分片隐藏、普通配置文件不保存密钥，见 TaskServiceTests 与 [02–03 证据](verification-02-03.md)。图片拒绝/错误回答保持能力未知，见 [图像能力检查](verification-12-capability.md)；真实搜索超时与不支持网页内容如实失败，见 [搜索验收](verification-13-search.md)。这些故障注入和合成密钥检查验证产品错误行为，不冒充另一家真实服务或将本轮参数错误当成服务故障。

当前桌面源码只注册用户配置的 OpenAI 兼容 provider，查询所需的兼容 Anthropic 对象指向无凭据的 `127.0.0.1:0/disabled`；子进程环境不继承模型凭据与 provider 覆盖。WebFetch 不使用模型语义提取，WebSearch 绑定当前配置，失败不切换服务。源码与回归未发现预期外 Claude 请求路径或所测合成密钥泄露；没有做独立全流量抓包，不将这些检查描述为全流量审计。具体已验证型号、能力和限制统一记录在 [兼容记录](model-compatibility.md)。
