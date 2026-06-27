# Markdown Renderer Test Suite

这组文件用于手动验证 Markdown 渲染器的常见问题。建议逐个打开，观察：

- 块级结构是否正确分段。
- 行内样式是否能正确嵌套、闭合和转义。
- 列表、引用、代码块、表格等复杂结构是否保持层级。
- 链接、图片、HTML、脚注、任务列表等扩展语法是否符合你的预期。
- 恶意 HTML、长文本、Unicode、特殊空白字符是否导致崩溃、错位或样式污染。

文件说明：

- `01-basic-blocks.md`：标题、段落、分隔线、软换行、硬换行。
- `02-inline-formatting.md`：加粗、斜体、删除线、代码、链接、转义、复杂嵌套。
- `03-lists-quotes.md`：有序/无序列表、任务列表、嵌套列表、引用嵌套。
- `04-code-fences.md`：缩进代码、围栏代码、反引号边界、未知语言。
- `05-tables.md`：表格对齐、空单元格、行内样式、管道转义。
- `06-links-images.md`：普通链接、引用链接、自动链接、图片、坏链接。
- `07-html-security.md`：内联 HTML、块级 HTML、脚本和事件属性安全测试。
- `08-edge-unicode.md`：中文、emoji、RTL、组合字符、超长行、特殊空白。
- `09-frontmatter-toc-footnotes.md`：Front matter、目录标记、脚注、定义列表。
- `10-combined-stress.md`：综合压力文档，混合多种语法。

这些测试文档不假设你的渲染器支持所有 Markdown 扩展。若某个扩展不在设计范围内，合理结果可以是原样显示，但不应崩溃、不应吞掉后续内容、不应污染整个页面样式。
