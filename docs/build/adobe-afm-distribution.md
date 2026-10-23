# Adobe `pzdr.afm`：有限核对与最小移除路径

核对日期：2026-10-23。范围只包括当前 Adobe AFM 原件的分发证据和源码材料选择；不修改应用、catalog、收集器或全局 goal，不将 URW PFB/GPL、PSNFSS 的许可扩大到该 AFM。

## 结果

**本轮没有找到可明确关联到当前 AFM 原字节的 Adobe 第一方分发授权。建议从拟公开材料中排除这一个非运行时来源文件，继续保留已另有 PSNFSS 授权依据的 `pzdr.tfm`。** 这是材料范围收缩方案，不是认定 AFM 在法律上禁止分发；“All rights reserved”、历史入口断链和本轮未找到授权都不能单独证明禁止。

目标文件是 `third_party/tex-notices/texlive-2022/texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm`：9,467 字节，SHA-256 **`3328cb027cca61175005fa1fd56de4fe17f7d0cbea3a4a8bfff1b6da6439c70c`**，内部版本 001.004、创建时间 1989-12-01，版权为 Adobe 1985/1987/1988/1989，并有 ITC 商标说明。[固定 TeX Live 原件](https://git.texlive.info/texlive/plain/Master/texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm?id=082081a375be008c2e049cd7cf1137314f888b18)

当前 catalog 把它作为 `notice_files` 收集，但它是字体度量数据而非授权书；366 个 `matches` 中没有 `pzdr.afm`，相关运行时条目是 `pzdr.tfm`。`pzdr.tfm` 与 PSNFSS 完整作品内对应文件相同的证据见 [字体分发路径](font-distribution-path.md)。这一证据不需要附带、也不授权另一个作品中的 Adobe AFM。

## 核对的直接第一方入口

| 入口 | 实际结果 | 能证明和不能证明的范围 |
| --- | --- | --- |
| [Adobe 官方社区：Core font afm licensing，2017-11-10](https://community.adobe.com/questions-94/core-font-afm-licensing-1503371) | 提问引用随 14 个 PostScript AFM 发布的条款，允许免费使用、复制、分发和修改；当时 Adobe Principal Scientist Dov Isaacs 回应，讨论了 AFM 收费限制及将度量信息放入应用。 | 这是直接相关的历史说明，但不是当前包的完整许可证原件；没有当前 `pzdr.afm` 的版本/摘要或它属于那 14 个随附文件的证明。不能把提问中的摘引或对嵌入度量的评论扩大成所有 Adobe AFM 的无条件授权。 |
| [Adobe Core14_AFMs.zip 历史入口](https://partners.adobe.com/public/developer/en/pdf/Core14_AFMs.zip) | 独立 curl 请求 HTTP 404；未取得归档、README 或可比较的 ZapfDingbats AFM。 | 不能完成随附许可—具体文件关联；不表示 Adobe 撤销了过去授权。未从第三方镜像取得材料后冒称第一方取证。 |
| [Adobe AFM FTP 历史目录的 HTTPS ReadMe 入口](https://ftp.adobe.com/pub/adobe/type/win/all/afmfiles/ReadMe) | TLS 证书主机名不匹配，curl 退出 60；未关闭证书验证，未取得内容。 | 此次传输失败，不推断 README 不存在或内容为何；不继续枚举路径。 |
| [Adobe AFDKO 固定许可修订 `780164a43d86a782be479ad1e54cc44363ca082b`](https://github.com/adobe-type-tools/afdko/commit/780164a43d86a782be479ad1e54cc44363ca082b) | 2018-04-24 提交只修改/删除 `t1write_{flex,gc,hint,procset}others` 的 `.h/.txt` 文件，为这些 OtherSubrs 代码补 Apache 2.0 声明。 | 该提交不含 `pzdr.afm`，不能据此把当前 AFM 重新标为 Apache-2.0。当前 AFDKO 总许可同样不是所有 Adobe 历史字体数据的通用授权。 |

另查 Adobe `font-tech-notes` 官方树，仅发现 AFM 格式规范 `5004.AFM_Spec.pdf`；格式文档不建立这份度量文件的授权关联。AFDKO 当前递归树请求出现 transport closed，本轮未重试或扩大搜索。至此停止网络补证。

研究状态保存在 ignored 目录 `.build-tools/third-party-inputs/adobe-afm-review/`：`http-results.json` 为两次传输结果，`afdko-commit-scope.json` 为固定提交的文件范围，`local-scope.json` 为当前本地文件与选择范围。未把错误页存为许可原件，也没有新增大包下载。

## 最小调整：两条收集路径必须同时处理

**路径 A：直接通知复制。** 从 `third_party/tex-notices/sources.json` 的 `notice_files` 删除唯一 `source_path = texmf-dist/fonts/afm/adobe/zapfding/pzdr.afm` 条目，并从拟公开源码树删除上述 `third_party/.../pzdr.afm` 文件。通知条目 **22 → 21**；`matches` **366 不变**，`pzdr.tfm` 条目和 PSNFSS 完整包保持不变。只改这一层仍不能阻止路径 B 再次带入 AFM。[直接复制代码](../../scripts/collect-third-party-notices.py)

**路径 B：TeX Live 包材料。** `scripts/fetch-tex-package-sources.py::make_plan` 从固定 tlpdb 的 `zapfding` 包选取全部 runfiles，包含该 AFM。当前包共 9 个路径，AFM 的唯一 owner 为 `zapfding/runfiles`；只从 catalog 的通知列表移除它，不会改变按 `matches` 选出的 `zapfding` 包。[计划生成代码](../../scripts/fetch-tex-package-sources.py)

最小可审查实现应当：

1. 在固定选择规则中加入**精确文件路径排除**，记录路径、已知 SHA-256 和原因“非运行时附加 AFM，独立授权未核实”；不要按 `adobe/` 通配排除，也不要删除整个 `zapfding` 包。将该排除规则写进生成的计划，明确其 scope 是有记录排除项的选定包文件，不能继续声称 `zapfding` 完整无删减。
2. 新计划的 `files` 以及 `packages[zapfding].paths` 均移除该路径：**114 包不变、3,754 → 3,753 个文件**；`zapfding` 的选定路径 **9 → 8**。原始 `package-records.json` 的 tlpdb block、其摘要、固定 tlpdb 文件及 `TLPDB_SHA256` 保留原样；原始数据库仍列 AFM 是正常的来源记录，不能篡改上游数据库来隐藏排除。
3. catalog 改动会改变 `tex_catalog_sha256`，排除又会改变 plan，因此必须生成**新的 plan 和新的 results 收据**。在新输出目录中，复用旧目录里通过 URL/owner/size/SHA 校验的 3,753 个文件及其成功收据，重算 `plan_sha256`，经完整校验后才写 `complete=true`。不需要重新下载全部文件；不应只手改旧收据的总数或保留 AFM 的多余收据。
4. `collect_tex_packages` 目前严格比较 `make_plan` 的预期计划、原始 package-records，以及“收据路径集合 = 计划路径集合”。保留这些检查；让它从相同的新选择规则计算预期结果。它会拒绝旧 3,754 条收据用于新计划，这种拒绝应保留，不得改成忽略 extra paths。现有运行时 `matches` 校验仍验证 `pzdr.tfm`，不需要跳过该验证。[collector 代码](../../scripts/collect-third-party-notices.py)
5. 从新目录重新生成正式第三方输出，更新 `tex-package-sources/{plan,results,manifest}.json`、总 inventory/SHA256SUMS 和输出说明。不得把旧输出原地覆写后留下 `files/.../pzdr.afm`：旧的 `.build/third-party/inspection-*` 多处已经包含该原件或收据，应当作为内部旧材料留存或清理，不能误选成发布资产。原始 ignored 研究副本可以保留以支持审计。

该调整不改变 TFM 的字节、LaTeX 缓存或产品代码；若产品打包以后新增 AFM 实际依赖，应重新审查，不能依赖本次“当前 matches 中不存在”的结论。

## 公开源码树与验收

本地 `git log -- <AFM路径>` 已确认该原文件由 **`dfdb82f`** 引入。因此删掉当前树只解决新的源码快照/发布包：**如果把包含该提交的完整 Git 历史推到公开仓库，旧 AFM blob 仍可取得。** 本轮未核实此历史是否已公开，也未做历史改写。首次公开可采用经过排除检查的干净源码快照/起始历史；若必须保留既有历史，需要另行决定并授权有范围的历史过滤，不能在普通移除中悄悄重写历史。

建议验收聚焦这一个变化：新 catalog 无 AFM 通知项；新计划和收据各 3,753 条且严格一致；全部保留文件摘要与旧固定来源一致；发布目录和源码归档不含该 AFM 文件/相同摘要的副本；`pzdr.tfm` SHA-256 仍为 `6b4254217851e285d1d5c6dfe677284396eeffc59f709ad775404b76dc99d513`，PSNFSS 许可与完整作品仍在。原始 tlpdb、审计文档或排除清单**可以继续出现文件名和摘要**，不应通过全局删除字符串来破坏来源记录。

这是父任务可执行的最小方案。本轮仅新增本文和 ignored 研究收据，没有执行删除、调整计划、复制发布材料、修改 Git 历史或联系 Adobe。

## 本地实施与验证（2026-10-23）

上述最小排除已落实到当前源码树和收集计划，未改写 Git 历史。新的固定包材料位于 `.build-tools/third-party-inputs/tex-package-sources-with-exclusions`；复用前逐项核对原 URL、owner、size、SHA-256，复制后再次核对，保留原始 package-records。新计划为 114 包、3,753 文件、148,015,449 字节；`plan.json` SHA-256 为 `0952b565ddb7d7611e94e9db2b86bf91e945d82d2018b8b7b69886015de1ad91`。

完整 collector 已对签名候选 `candidate-a3vT0N` 通过，输出到 `.build/third-party/candidate-a3vT0N-sources`。旧未排除计划、额外 AFM 收据、缺失收据及重复收据四类输入均被拒绝；没有放宽路径集合检查。输出扫描未发现被排除 AFM 的原字节摘要。当前运行资源仍为 416 项直接来源、3 项变换关联和 1 项项目字体配置，0 项未关联数据。

这些输出仍在本机，尚未作为公开资产提供；旧候选的源码 ZIP 和历史提交仍包含旧材料，不得直接选作首个公开源码资产。
