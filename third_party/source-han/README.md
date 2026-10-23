# 思源中文字体

`sources.json` 固定 Adobe 官方仓库的思源宋体 2.003R、思源黑体 2.005R 简体中文子集 Regular/Bold OTF。构建下载时核对大小与 SHA-256；原始字节不修改。仓库只保存来源目录和两份原始许可，字体二进制进入应用的离线排版资源包。

`serif/LICENSE.txt`、`sans/LICENSE.txt` 保留各自版权与 SIL Open Font License 1.1 全文。构建将两份文件复制到应用 `Contents/Resources/latex/notices/source-han/`。字体未单独售卖，未重命名或修改字体本身。项目的 `ctex-fontset-claurst.def` 是另外编写的 LaTeX 配置，合成倾斜仅影响排版渲染。

该替换解决中文字体的具体分发材料问题，不替代 Tectonic、TeX 宏包、西文字体或整个应用的许可核对。旧 `fontset=fandol` 项目需要显式迁移并重新检查 PDF 版面。
