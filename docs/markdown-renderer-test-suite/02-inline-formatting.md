# Inline Formatting

普通文本中的 *斜体*、**加粗**、***加粗斜体***、~~删除线~~。

下划线形式：_斜体_、__加粗__、___加粗斜体___。

行内代码：`let value = "**not bold**";`

包含反引号的行内代码：``Use `code` inside code``。

链接：[OpenAI](https://openai.com) 和带标题的链接 [Example](https://example.com "Example title")。

自动链接：https://example.com/path?a=1&b=2

邮箱自动链接：hello@example.com

转义字符：\*不是斜体\*，\# 不是标题，\[不是链接\](https://example.com)。

复杂嵌套：**加粗里有 _斜体_ 和 `code`，还有 [link](https://example.com)**。

容易出错的边界：

- a*b*c
- a**b**c
- 中文**加粗**中文
- 中文*斜体*中文
- 5 * 3 = 15，不应被误判为斜体
- snake_case_text 不应被误判为斜体

未闭合标记：**这段加粗没有闭合

下一段不应该全部继续加粗。

混合标点：这是“**中文引号内加粗**”，以及（*括号内斜体*）。
