# 任务管理：本地 Markdown

规格与任务保存在项目的 `.scratch/` 目录，无需外部任务平台。

- 每个功能使用 `.scratch/<feature-slug>/`。
- 规格文件为该目录下的 `spec.md`。
- 每个开发任务单独保存为 `issues/<NN>-<slug>.md`，从 `01` 起按依赖顺序编号。
- 每项任务包含交付行为、验收条件、`Blocked by:` 和 `Status:`。
- `Blocked by:` 列出前置任务的编号与标题，无依赖时写 `None`。
- `Status:` 使用 `docs/agents/triage-labels.md` 中的默认状态。
- 讨论和执行记录追加在任务文件的 `## Comments` 下。
- 完成时记录验收结果、验证证据及完成日期，并勾选通过的验收项；五种分流状态不替代完成记录。

技能要求“发布到任务平台”时，在上述本地目录写入文件；要求“读取任务”时，读取对应文件。

如以后使用 wayfinder，决策地图保存为 `.scratch/<effort>/map.md`，子决策使用该目录的 `issues/NN-<slug>.md`。子决策以 `Type:` 区分类型，以 `claimed` / `resolved` 表示决策处理状态，以 `Blocked by:` 声明前置决策；地图通过本地相对链接引用子决策及结论。
