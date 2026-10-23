# 搜索状态示例

这是故意包含缺陷的开发验收样例：搜索后切换状态，搜索条件丢失。
从仓库复制一份到临时工作区再修改；保留 app/ 与 checks/ 的结构。
使用 Python 3 执行 `python3 -B -m unittest discover -s checks -v`。
这里的 sort_order 表示已有的用户行为，修复搜索时应保留。

macOS Command Line Tools 环境可使用 `/Library/Developer/CommandLineTools/usr/bin/python3 -B -m unittest discover -s checks -v`，无需下载额外依赖。
