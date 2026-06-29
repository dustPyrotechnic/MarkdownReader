# 批阅模块（阶段五）

阅读页长按选中正文 → 弹出轻量 HUD 添加文字 / Emoji 评注 → 持久化到 SwiftData；重开文档在原字符偏移恢复高亮，并可在列表查看 / 删除。

## 文件布局

| 文件 | 职责 |
|------|------|
| `Models/Annotation.swift` | `@Model`，字段 `rangeStart/rangeEnd/comment/emoji/createdAt`，`document` 反向关系（`Document.annotations` 级联删除） |
| `Support/SelectionPayload.swift` | JS 选区回传载荷的纯值类型，从 `[String: Any]` 解码，便于单测 |
| `Stores/AnnotationStore.swift` | `@MainActor @Observable` 业务：`add` / `delete`，维护与 `Document` 的关系 |
| `Views/AnnotationHUD.swift` | 选区评注录入 sheet（文字 + Emoji），保存写库 |
| `Views/AnnotationListView.swift` | 批注列表，滑动删除 |
| `Views/ReaderView.swift` | 串联：接选区回调、挂两个 sheet、把批注下发 WebView |
| `WebView/MarkdownWebView.swift` | 注册 `selectionChanged`、解码为 `SelectionPayload`、渲染完成后 `setAnnotations` 下发 |
| `Resources/renderer.html` | JS 侧：`selectionchange` 算字符偏移回传；`restoreAnnotations` / `wrapRange` 按偏移重建高亮 |

## 数据流

```
长按选中
  → JS selectionchange：charOffset(root, node, offset) 算相对 #content 的字符偏移
  → postMessage { text, rangeStart, rangeEnd }
  → Swift SelectionPayload(body:) 解码（空文本/非法区间过滤）
  → ReaderView 弹 AnnotationHUD
  → AnnotationStore.add → context.insert(annotation) → annotation.document = doc → context.save()

重开文档
  → ReaderView.annotationPayloads 把 document.annotations 转纯字典数组
  → MarkdownWebView 渲染成功后 Coordinator.applyAnnotations → callAsyncJavaScript setAnnotations(items)
  → JS restoreAnnotations：按 rangeStart 降序，wrapRange 逐文本节点片段包 span.annotation-highlight

删除
  → AnnotationListView 滑动 → AnnotationStore.delete（先 annotation.document = nil 断开反向关系再 context.delete）→ save
```

## 偏移映射约定

- 偏移基于 `#content` 根下 `TreeWalker(SHOW_TEXT)` 的文本节点长度累加，`[rangeStart, rangeEnd)` 左闭右开。
- 重建高亮按 `rangeStart` **降序**处理，避免插入 span 后的偏移漂移。
- `range.surroundContents` 不能跨元素边界，故按文本节点**逐段**包裹而非整段一次包裹；同一节点内倒序切分。
- 删除批注先把 `annotation.document = nil` 再 `context.delete`，否则反向数组 `document.annotations` 不会即时刷新（删除标记不同步反向关系）。

## 验收

**可自动化（已覆盖）**
- `SelectionPayloadTests`：合法解码 / 缺字段 / 空文本 / 非法区间。
- `AnnotationStoreTests`：新增关联到文档 / 删除后文档不再持有。

**需真机 / 模拟器人工验收（JS 偏移与 DOM 高亮无法单测）**
- [ ] 长按选中 → HUD → 填评注 / 选 Emoji → 保存
- [ ] 选区原位置出现黄色高亮
- [ ] 退出重进文档 → 高亮在原位置恢复
- [ ] 批注列表查看 → 滑动删除 → 高亮消失且重进不再出现
- [ ] 跨格式节点（粗体 / 行内代码）选区高亮覆盖完整
- [ ] 深浅色模式下高亮均可见

## 已知限制

- KaTeX / Mermaid 等改写 DOM 的区块内选区偏移可能不稳定，MVP 接受「公式 / 图表内不支持批注」；必要时在 `charOffset` 跳过 `.katex` / `.mermaid` 容器。
