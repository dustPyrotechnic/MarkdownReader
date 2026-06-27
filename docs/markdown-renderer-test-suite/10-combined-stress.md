# Combined Stress Document

> 这是一个综合测试文档，混合多种 Markdown 结构。
>
> - 引用里的列表
> - 包含 **bold**、*italic*、`code`
>
> | In Quote | Value |
> | --- | ---: |
> | rows | 2 |

## Section With Many Elements

1. 第一项包含段落。

   第二段仍属于第一项。

   ```swift
   enum State {
       case loading
       case ready(String)
       case failed(Error)
   }
   ```

2. 第二项包含引用：

   > Nested quote inside list.
   >
   > > Deeper quote.

3. 第三项包含表格：

   | Key | Value |
   | --- | --- |
   | `id` | 123 |
   | name | **MarkdownReader** |

## Inline Stress

This paragraph has **bold with [a link](https://example.com) and `inline code`**, then _italic with **nested bold**_, then escaped characters \* \_ \[ \] \( \).

中文 English العربية emoji 😀 code `a < b && b > c` link <https://example.com>.

## HTML Mixed With Markdown

<details>
<summary>HTML summary</summary>

Markdown inside details may or may not be parsed:

- item
- **bold**

</details>

## Layout Stress

| Column One | Column Two | Column Three | Column Four |
| --- | --- | --- | --- |
| Very long text that should wrap in a table cell without destroying the page layout. | `code code code code code code code` | [link](https://example.com/very/long/url/that/might/not/wrap/well) | 中文中文中文中文中文中文中文中文中文 |

## Security Regression Block

<script>window.__markdown_reader_test_script_executed = true;</script>

[bad scheme](javascript:window.__markdown_reader_test_link_executed=true)

<img src="bad-src" onerror="window.__markdown_reader_test_onerror_executed=true">

## End

如果上面的未支持语法能安全降级，且最后这个段落仍然正常显示，说明基础容错较好。
