# 阶段五：批阅 HUD + 持久化 实施计划

> **For Claude:** REQUIRED SUB-SKILL: 用 superpowers:executing-plans 逐 Task 实施本计划。

**Goal:** 让用户在阅读页长按选中文字后弹出轻量 HUD，添加文字 / Emoji 评注并持久化到 SwiftData，重新打开文档时在原位置恢复高亮，并可查看 / 删除批注。

**Architecture:** 复用已有 WKWebView 桥接（`selectionChanged` message + `onSelectionChanged` 回调）与 `Annotation` 模型。JS 侧在 `selectionchange` 计算选区相对 `#content` 根的字符偏移（基于 TreeWalker 遍历文本节点），回传 `{text, rangeStart, rangeEnd}`；Swift 侧把 payload 解码为可单测的 `SelectionPayload` 值类型，经 `AnnotationStore` 写入 SwiftData。重开文档渲染完成后，Swift 把该文档的批注下发给 JS，`restoreAnnotations` 按偏移逐文本节点包裹 `span.annotation-highlight` 重建高亮。

**Tech Stack:** SwiftUI、SwiftData（`@MainActor @Observable` Store）、WebKit（`WKScriptMessageHandler` / `callAsyncJavaScript`）、Swift Testing。

**前置事实（已存在，勿重复造）：**
- `Models/Annotation.swift`：`@Model`，字段 `rangeStart/rangeEnd/comment/emoji/createdAt`，`document` 反向关系。
- `Models/Document.swift:17`：`@Relationship(deleteRule: .cascade, inverse: \Annotation.document) var annotations: [Annotation]?`。
- `WebView/MarkdownWebView.swift`：已注册 `selectionChanged` handler，`onSelectionChanged: ((String) -> Void)?`（本计划改签名为 `SelectionPayload`）。
- `Views/ReaderView.swift:7-24`：已有 `selectedText` / `showAnnotationHUD` 状态并在选区回调里置位，但**无 `.sheet`**。
- `Resources/renderer.html`：已有 `.annotation-highlight` 样式、`setAnnotations` / `restoreAnnotations`（**仅清高亮未重建**）、`selectionchange`（**仅回传 text 无偏移**）。

**约束（来自 CLAUDE.md，必须遵守）：**
- 共享数据用 `@MainActor @Observable`，禁 `ObservableObject`；不同类型拆独立 Swift 文件；不用计算属性拆视图，拆独立 `View` struct。
- 避免强解包 / 强制 `try`；单测不写真实 `URL.documentsDirectory`，用内存 SwiftData 容器（`TestModelContainer.make()`）。
- 测试机型固定：iPhone 17 / iOS 26.5 模拟器。

---

## Task 1：`SelectionPayload` 选区载荷值类型（纯函数，可单测）

把 JS 回传的 `[String: Any]` 解码逻辑从 `Coordinator` 抽成纯值类型，便于单测，避免在闭包里散落解析。

**Files:**
- Create: `MarkdownReader/Support/SelectionPayload.swift`
- Test: `MarkdownReaderTests/SelectionPayloadTests.swift`

**Step 1: 写失败测试**

```swift
import Testing
import Foundation
@testable import MarkdownReader

struct SelectionPayloadTests {
    @Test func 合法body解码成功() {
        let body: [String: Any] = ["text": "选中文字", "rangeStart": 3, "rangeEnd": 7]
        let payload = SelectionPayload(body: body)
        #expect(payload == SelectionPayload(text: "选中文字", rangeStart: 3, rangeEnd: 7))
    }

    @Test func 缺字段返回nil() {
        #expect(SelectionPayload(body: ["text": "x"]) == nil)
        #expect(SelectionPayload(body: ["rangeStart": 0, "rangeEnd": 1]) == nil)
    }

    @Test func 空文字或非法区间返回nil() {
        #expect(SelectionPayload(body: ["text": "", "rangeStart": 0, "rangeEnd": 0]) == nil)
        #expect(SelectionPayload(body: ["text": "x", "rangeStart": 5, "rangeEnd": 5]) == nil)
        #expect(SelectionPayload(body: ["text": "x", "rangeStart": 7, "rangeEnd": 3]) == nil)
    }
}
```

**Step 2: 运行确认失败**

Run: `xcodebuild test -scheme MarkdownReader -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:MarkdownReaderTests/SelectionPayloadTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'SelectionPayload'`。

**Step 3: 最小实现**

```swift
import Foundation

/// JS `selectionChanged` 回传的选区载荷（纯值类型，便于单测）。
struct SelectionPayload: Equatable {
    /// 选中的可见文本。
    let text: String
    /// 选区起始字符偏移（相对内容根）。
    let rangeStart: Int
    /// 选区结束字符偏移（相对内容根，开区间上界）。
    let rangeEnd: Int

    /// 从 `WKScriptMessage.body` 字典解码；字段缺失、文本为空或区间非法返回 `nil`。
    /// - Parameter body: message body 字典。
    init?(body: [String: Any]) {
        guard let text = body["text"] as? String, !text.isEmpty,
              let start = body["rangeStart"] as? Int,
              let end = body["rangeEnd"] as? Int,
              start < end
        else { return nil }
        self.text = text
        self.rangeStart = start
        self.rangeEnd = end
    }

    /// 直接构造（测试用）。
    init(text: String, rangeStart: Int, rangeEnd: Int) {
        self.text = text
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}
```

**Step 4: 运行确认通过**

Run: 同 Step 2。Expected: 4 用例全部 PASS。

**Step 5: Commit**

```bash
git add MarkdownReader/Support/SelectionPayload.swift MarkdownReaderTests/SelectionPayloadTests.swift
git commit -m "feat: SelectionPayload 选区载荷值类型 + 单测"
```

---

## Task 2：`AnnotationStore` 批注业务（TDD）

**Files:**
- Create: `MarkdownReader/Stores/AnnotationStore.swift`
- Test: `MarkdownReaderTests/AnnotationStoreTests.swift`

**Step 1: 写失败测试**

```swift
import Testing
import Foundation
import SwiftData
@testable import MarkdownReader

@MainActor
struct AnnotationStoreTests {
    @Test func 添加批注关联到文档() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let doc = Document(fileName: "a.md", relativePath: "未分类/a.md")
        context.insert(doc)
        let store = AnnotationStore()

        let annotation = store.add(
            selection: SelectionPayload(text: "重点", rangeStart: 4, rangeEnd: 6),
            comment: "记一笔", emoji: "⭐️", to: doc, context: context
        )

        #expect(annotation.comment == "记一笔")
        #expect(annotation.emoji == "⭐️")
        #expect(annotation.rangeStart == 4)
        #expect(annotation.rangeEnd == 6)
        #expect(annotation.document?.id == doc.id)
        #expect(doc.annotations?.count == 1)
    }

    @Test func 删除批注后文档不再持有() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let doc = Document(fileName: "a.md", relativePath: "未分类/a.md")
        context.insert(doc)
        let store = AnnotationStore()
        let annotation = store.add(
            selection: SelectionPayload(text: "x", rangeStart: 0, rangeEnd: 1),
            comment: "c", emoji: nil, to: doc, context: context
        )

        store.delete(annotation, context: context)

        #expect((doc.annotations ?? []).isEmpty)
    }
}
```

**Step 2: 运行确认失败**

Run: `xcodebuild test -scheme MarkdownReader -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:MarkdownReaderTests/AnnotationStoreTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'AnnotationStore'`。

**Step 3: 最小实现**

```swift
import Foundation
import SwiftData
import Observation

/// 批注业务：把选区评注写入 SwiftData 并维护与 `Document` 的关系。
@MainActor
@Observable
final class AnnotationStore {
    /// 新增批注并关联到文档。
    /// - Parameters:
    ///   - selection: 选区载荷（提供字符偏移）。
    ///   - comment: 文字评注，可为空。
    ///   - emoji: 可选 Emoji。
    ///   - document: 目标文档。
    ///   - context: SwiftData 上下文。
    /// - Returns: 新建的 `Annotation`。
    @discardableResult
    func add(
        selection: SelectionPayload,
        comment: String,
        emoji: String?,
        to document: Document,
        context: ModelContext
    ) -> Annotation {
        let annotation = Annotation(
            rangeStart: selection.rangeStart,
            rangeEnd: selection.rangeEnd,
            comment: comment,
            emoji: emoji
        )
        context.insert(annotation)
        annotation.document = document
        return annotation
    }

    /// 删除批注。
    /// - Parameters:
    ///   - annotation: 待删除批注。
    ///   - context: SwiftData 上下文。
    func delete(_ annotation: Annotation, context: ModelContext) {
        context.delete(annotation)
    }
}
```

**Step 4: 运行确认通过** — Expected: 2 用例 PASS。

**Step 5: 注册 Store 到环境**

Modify: `MarkdownReader/MarkdownReaderApp.swift` —— 在已注入 `FolderStore` / `DocumentImporter` 处追加 `.environment(AnnotationStore())`（参照现有 `.environment(...)` 写法；先 `grep -n "environment(" MarkdownReader/MarkdownReaderApp.swift` 确认位置）。

**Step 6: Commit**

```bash
git add MarkdownReader/Stores/AnnotationStore.swift MarkdownReaderTests/AnnotationStoreTests.swift MarkdownReader/MarkdownReaderApp.swift
git commit -m "feat: AnnotationStore 批注增删 + 注入环境"
```

---

## Task 3：JS 选区偏移 + Swift 回调改用 `SelectionPayload`

让 `selectionchange` 计算相对 `#content` 根的字符偏移并回传，Swift 侧把 `onSelectionChanged` 签名从 `(String)` 改为 `(SelectionPayload)`。

> 注：JS 偏移映射依赖真实 DOM，无法在 Swift 单测内伪造，本 Task 的 JS 部分靠真机 / 模拟器人工验证（见 Task 7）；Swift 解码已由 Task 1 覆盖。

**Files:**
- Modify: `MarkdownReader/Resources/renderer.html`（`selectionchange` 监听 + 新增 `charOffset` 工具）
- Modify: `MarkdownReader/WebView/MarkdownWebView.swift`（回调签名与解码）
- Modify: `MarkdownReader/Views/ReaderView.swift`（接收新签名）

**Step 1: renderer.html —— 计算并回传偏移**

先确认内容根元素 id：`grep -n 'id="content"\|getElementById\|<body' MarkdownReader/Resources/renderer.html`。下文以 `#content` 为内容根（若实际不同，替换为真实 id）。

把 `selectionchange` 监听替换为：

```js
  // 计算 node 内 offset 相对 root 文本的绝对字符偏移
  function charOffset(root, node, offset) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let count = 0;
    let n;
    while ((n = walker.nextNode())) {
      if (n === node) return count + offset;
      count += n.textContent.length;
    }
    return count;
  }

  document.addEventListener('selectionchange', () => {
    const sel = window.getSelection();
    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return;
    const root = document.getElementById('content');
    if (!root) return;
    const range = sel.getRangeAt(0);
    if (!root.contains(range.startContainer) || !root.contains(range.endContainer)) return;
    const text = sel.toString();
    if (text.length < 1) return;
    const rangeStart = charOffset(root, range.startContainer, range.startOffset);
    const rangeEnd = charOffset(root, range.endContainer, range.endOffset);
    if (rangeEnd <= rangeStart) return;
    window.webkit.messageHandlers.selectionChanged.postMessage({ text, rangeStart, rangeEnd });
  });
```

**Step 2: MarkdownWebView.swift —— 回调签名 + 解码**

- 把 `var onSelectionChanged: ((String) -> Void)?` 改为 `((SelectionPayload) -> Void)?`（结构体属性、`Coordinator` 属性、`init`、`makeCoordinator` 同步改）。
- `userContentController` 的 `case "selectionChanged"` 改为：

```swift
            case "selectionChanged":
                guard let body = message.body as? [String: Any],
                      let payload = SelectionPayload(body: body) else { return }
                Task { @MainActor in self.onSelectionChanged?(payload) }
```

**Step 3: ReaderView.swift —— 接新签名**

把闭包 `{ text in selectedText = text; showAnnotationHUD = true }` 改为：

```swift
            ) { payload in
                currentSelection = payload
                showAnnotationHUD = true
            }
```

并把 `@State private var selectedText = ""` 替换为 `@State private var currentSelection: SelectionPayload?`。

**Step 4: 编译验证**

Run: `xcodebuild build -scheme MarkdownReader -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`。

**Step 5: Commit**

```bash
git add MarkdownReader/Resources/renderer.html MarkdownReader/WebView/MarkdownWebView.swift MarkdownReader/Views/ReaderView.swift
git commit -m "feat: 选区回传字符偏移，onSelectionChanged 改用 SelectionPayload"
```

---

## Task 4：`AnnotationHUD` 视图 + `ReaderView` `.sheet` 保存

**Files:**
- Create: `MarkdownReader/Views/AnnotationHUD.swift`
- Modify: `MarkdownReader/Views/ReaderView.swift`

**Step 1: AnnotationHUD.swift**

```swift
import SwiftUI
import SwiftData

/// 选区批注录入 HUD：文字 + Emoji，保存写入 SwiftData。
struct AnnotationHUD: View {
    let selection: SelectionPayload
    let document: Document
    @Environment(AnnotationStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var selectedEmoji: String?

    private let emojis = ["⭐️", "❓", "💡", "⚠️", "❤️", "👍", "📌", "🔥"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("批注").font(.headline)

            Text("“\(selection.text.prefix(60))”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField("添加评注…", text: $comment, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            EmojiPickerRow(emojis: emojis, selection: $selectedEmoji)

            Button("保存批注") { save() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isEmpty)
        }
        .padding()
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private var isEmpty: Bool {
        comment.trimmingCharacters(in: .whitespaces).isEmpty && selectedEmoji == nil
    }

    private func save() {
        store.add(selection: selection, comment: comment, emoji: selectedEmoji, to: document, context: context)
        try? context.save()
        dismiss()
    }
}

/// Emoji 选择行（独立 View，不用计算属性拆视图）。
private struct EmojiPickerRow: View {
    let emojis: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { selection = selection == emoji ? nil : emoji }
                        .font(.title2)
                        .padding(6)
                        .background(selection == emoji ? Color.accentColor.opacity(0.2) : .clear)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }
}
```

**Step 2: ReaderView.swift —— 挂 `.sheet`**

在 `ZStack { ... }` 之后、`.navigationTitle` 之前追加：

```swift
        .sheet(isPresented: $showAnnotationHUD) {
            if let currentSelection {
                AnnotationHUD(selection: currentSelection, document: document)
            }
        }
```

**Step 3: 编译验证**

Run: `xcodebuild build -scheme MarkdownReader -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `BUILD SUCCEEDED`。

**Step 4: Commit**

```bash
git add MarkdownReader/Views/AnnotationHUD.swift MarkdownReader/Views/ReaderView.swift
git commit -m "feat: AnnotationHUD 批注录入 + ReaderView sheet 保存"
```

---

## Task 5：重开文档恢复高亮（JS `restoreAnnotations` 真实重建 + Swift 下发）

**Files:**
- Modify: `MarkdownReader/Resources/renderer.html`（`restoreAnnotations` 真正包裹高亮）
- Modify: `MarkdownReader/WebView/MarkdownWebView.swift`（渲染完成后调用 `setAnnotations`）
- Modify: `MarkdownReader/Views/ReaderView.swift`（把 `document.annotations` 传入 WebView）

**Step 1: renderer.html —— 按偏移重建高亮**

替换 `restoreAnnotations`：

```js
  function restoreAnnotations() {
    const root = document.getElementById('content');
    if (!root) return;
    // 先清除旧高亮
    root.querySelectorAll('.annotation-highlight').forEach(el => {
      const parent = el.parentNode;
      el.replaceWith(...el.childNodes);
      parent.normalize();
    });
    // 按起点降序处理，避免包裹后偏移漂移
    [...annotations]
      .filter(a => a.rangeEnd > a.rangeStart)
      .sort((a, b) => b.rangeStart - a.rangeStart)
      .forEach(a => wrapRange(root, a));
  }

  // 把 [start, end) 字符区间内的每个文本节点片段包进高亮 span
  function wrapRange(root, annotation) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let count = 0;
    let node;
    const segments = [];
    while ((node = walker.nextNode())) {
      const len = node.textContent.length;
      const nodeStart = count;
      const nodeEnd = count + len;
      count = nodeEnd;
      const from = Math.max(annotation.rangeStart, nodeStart);
      const to = Math.min(annotation.rangeEnd, nodeEnd);
      if (to > from) segments.push({ node, from: from - nodeStart, to: to - nodeStart });
    }
    // 倒序切分同一节点不影响其它节点
    segments.reverse().forEach(seg => {
      const range = document.createRange();
      range.setStart(seg.node, seg.from);
      range.setEnd(seg.node, seg.to);
      const span = document.createElement('span');
      span.className = 'annotation-highlight';
      if (annotation.emoji) span.dataset.emoji = annotation.emoji;
      if (annotation.comment) span.title = annotation.comment;
      range.surroundContents(span);
    });
  }
```

可选样式（如需让 Emoji 角标可见，追加到 `<style>`）：

```css
  .annotation-highlight[data-emoji]::after { content: attr(data-emoji); font-size: 0.8em; margin-left: 2px; }
```

**Step 2: MarkdownWebView.swift —— 渲染完成后下发批注**

- 给 `MarkdownWebView` 增加输入：`var annotations: [[String: Any]] = []`（已是主线程构造的纯字典数组）。
- 在两处 `finishRender(.success(()))` 之前（即 `renderMarkdown` 与 `didFinish` 的成功分支）调用：

```swift
                    coordinator.applyAnnotations(in: webView)
```

- 在 `Coordinator` 增加：

```swift
        var annotationsJSON: [[String: Any]] = []

        func applyAnnotations(in webView: WKWebView) {
            guard !annotationsJSON.isEmpty else { return }
            webView.callAsyncJavaScript(
                "return setAnnotations(items)",
                arguments: ["items": annotationsJSON],
                in: nil, in: .page, completionHandler: nil
            )
        }
```

- `updateUIView` 内同步 `coordinator.annotationsJSON = annotations`。

**Step 3: ReaderView.swift —— 传入批注字典**

```swift
            MarkdownWebView(
                markdown: markdown,
                baseURL: documentURL.deletingLastPathComponent(),
                annotations: annotationPayloads,
                onRenderFinished: { ... },
                ...
```

并加私有计算属性（数据转换，非拆视图，允许）：

```swift
    private var annotationPayloads: [[String: Any]] {
        (document.annotations ?? []).map { [
            "rangeStart": $0.rangeStart,
            "rangeEnd": $0.rangeEnd,
            "comment": $0.comment,
            "emoji": $0.emoji ?? ""
        ] }
    }
```

**Step 4: 编译验证** — Expected: `BUILD SUCCEEDED`。

**Step 5: Commit**

```bash
git add MarkdownReader/Resources/renderer.html MarkdownReader/WebView/MarkdownWebView.swift MarkdownReader/Views/ReaderView.swift
git commit -m "feat: 重开文档按字符偏移恢复批注高亮"
```

---

## Task 6：批注列表查看与删除

**Files:**
- Create: `MarkdownReader/Views/AnnotationListView.swift`
- Modify: `MarkdownReader/Views/ReaderView.swift`（工具栏入口 + sheet）

**Step 1: AnnotationListView.swift**

```swift
import SwiftUI
import SwiftData

/// 文档批注列表：查看与滑动删除。
struct AnnotationListView: View {
    let document: Document
    @Environment(AnnotationStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var annotations: [Annotation] {
        (document.annotations ?? []).sorted { $0.rangeStart < $1.rangeStart }
    }

    var body: some View {
        NavigationStack {
            List {
                if annotations.isEmpty {
                    ContentUnavailableView("暂无批注", systemImage: "highlighter")
                } else {
                    ForEach(annotations) { annotation in
                        AnnotationRow(annotation: annotation)
                    }
                    .onDelete(perform: deleteAt)
                }
            }
            .navigationTitle("批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets { store.delete(annotations[index], context: context) }
        try? context.save()
    }
}

/// 单条批注行。
private struct AnnotationRow: View {
    let annotation: Annotation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let emoji = annotation.emoji { Text(emoji) }
                Text(annotation.comment.isEmpty ? "（无评注）" : annotation.comment)
                    .font(.body)
            }
            Text("区间 \(annotation.rangeStart)–\(annotation.rangeEnd)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 2: ReaderView.swift —— 工具栏入口**

新增 `@State private var showAnnotationList = false`，并加：

```swift
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAnnotationList = true } label: { Image(systemName: "list.bullet.rectangle") }
            }
        }
        .sheet(isPresented: $showAnnotationList) {
            AnnotationListView(document: document)
        }
```

**Step 3: 编译验证** — Expected: `BUILD SUCCEEDED`。

**Step 4: Commit**

```bash
git add MarkdownReader/Views/AnnotationListView.swift MarkdownReader/Views/ReaderView.swift
git commit -m "feat: 批注列表查看与滑动删除"
```

---

## Task 7：回归测试 + 真机验收 + 文档收尾

**Step 1: 跑阶段五自动化测试**

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:MarkdownReaderTests/SelectionPayloadTests \
  -only-testing:MarkdownReaderTests/AnnotationStoreTests
```
Expected: `TEST SUCCEEDED`。

**Step 2: 全量回归**

```bash
xcodebuild test -scheme MarkdownReader -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -20
```
Expected: `TEST SUCCEEDED`。

**Step 3: 真机 / 模拟器人工验收（JS 偏移与高亮无法单测）**

- [ ] 长按选中正文 → 弹出 HUD → 填评注 / 选 Emoji → 保存
- [ ] 选区原位置出现黄色高亮
- [ ] 退出重进文档 → 高亮在原位置恢复
- [ ] 工具栏批注列表能看到该条 → 滑动删除 → 高亮消失（重进文档不再出现）
- [ ] 选中含格式（粗体 / 行内代码）的跨节点文字 → 高亮覆盖完整选区
- [ ] 深浅色模式下高亮均可见

**Step 4: 文档收尾**

- 新建 `docs/modules/annotation.md`：文件布局、数据流（选区→偏移→SwiftData→恢复高亮）、偏移映射约定、可自动化 vs 真机验收项。
- 更新 `README.md` 路线图：`批阅功能` 勾选为 `[x]`。
- 更新 `CLAUDE.md` 当前模块要点：追加批阅模块一行；延伸文档列入 `docs/modules/annotation.md`。
- 更新记忆 `mvp-progress.md`：阶段五完成。

**Step 5: Commit**

```bash
git add docs/modules/annotation.md README.md CLAUDE.md
git commit -m "docs: 阶段五批阅模块文档与路线图收尾"
```

---

## 验收标准

- `SelectionPayload`、`AnnotationStore` 有单测且全绿；全量回归通过。
- 长按选中 → HUD → 保存 → 高亮 → 重开恢复 → 列表删除，闭环可在真机走通。
- 跨格式节点选区高亮完整、深浅色可见。
- 未引入第三方框架；未破坏 MV + `@Observable` 单向数据流；`renderer.html` 仅增量改动不回归既有渲染。

## 风险提醒

- **DOM 偏移 vs 纯文本偏移**：偏移基于 `#content` 文本节点累加；KaTeX / Mermaid 等会改写 DOM 的区块内选区可能不稳定，MVP 接受「公式 / 图表内不支持批注」，必要时在 `charOffset` 跳过 `.katex` / `.mermaid` 容器。
- **`range.surroundContents` 限制**：仅能包裹不跨元素边界的范围，故 Task 5 按文本节点逐段包裹而非整段 `surroundContents` 单次调用。
- **偏移漂移**：包裹高亮会插入新节点，必须按 `rangeStart` 降序处理多条批注（已在 `restoreAnnotations` 实现）。
- **`@Relationship` 反向赋值**：先 `context.insert(annotation)` 再设 `annotation.document`，与阶段四 `DocumentImporter` 一致，避免未注册对象触发关系异常。
- `Annotation` 模型注释当前误写「阶段四启用 UI」，文档收尾时一并改为阶段五。
```
