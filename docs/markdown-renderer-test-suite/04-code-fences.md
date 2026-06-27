# Code Fences

缩进代码块：

    let indented = true
    print(indented)

围栏代码块：

```swift
struct User {
    let id: UUID
    let name: String
}
```

未知语言：

```unknown-language
<not parsed as html>
**not bold**
```

没有语言：

```
plain text
line 2
```

代码中包含三个反引号时使用四个反引号包裹：

````
```markdown
# Inside code
```
````

波浪线围栏：

~~~json
{
  "name": "MarkdownReader",
  "enabled": true
}
~~~

未闭合代码块，从这里开始：

```text
如果你的解析器采用容错策略，这里可能一直到文件结尾都是代码。
这用于验证不会崩溃，也不会把后续文档结构错误污染到别的文件。
