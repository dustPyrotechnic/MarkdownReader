# 阶段三：SWCharSphere 加载动画 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `ReaderView` 渲染期间的占位 `ProgressView` 替换为 SWCharSphere 字符球加载动画，字符取自当前文档内容。

**Architecture:** MV + @Observable，纯 UI 在 `Views/`。把"字符提取"抽成纯函数 `MarkdownKeywords`（可单测），把加载视图拆成两层：**动画层**（`SWCharSphere`，时间驱动、非确定，靠 Xcode Preview 人工验证）+ **文案层**（`RenderingCaption`，确定性，做快照测试）。`SWCharSphere.swift` 为外部 MIT 单文件，原样纳入并保留来源注释。

**Tech Stack:** Swift 6.2、SwiftUI（`Canvas` / `TimelineView` / `ImageRenderer`）、Swift Testing、SWCharSphere（signerlabs/ShipSwift，MIT）

**测试方法总览：**
- **逻辑单测**（`MarkdownKeywordsTests`）：覆盖字符提取的回退、去重、过滤标点/空白/Markdown 标记、数量上限。
- **快照测试**（`RenderingCaptionSnapshotTests`）：用原生 `ImageRenderer` 把确定性文案层渲染成 PNG，首跑录制参考图到测试文件旁的 `__Snapshots__/`，之后逐像素对比。**不对动画球做快照**（逐帧非确定，会必然 flaky）；动画球仅靠 Preview 人工验证。快照与运行环境（模拟器机型 / OS / 字体）绑定，换环境需重录。

---

## Task 1：纳入 SWCharSphere.swift（外部 MIT 单文件）

**Files:**
- Create: `MarkdownReader/Animations/SWCharSphere.swift`

**Step 1:** 从 `https://raw.githubusercontent.com/signerlabs/ShipSwift/main/ShipSwift/SWPackage/SWAnimation/SWCharSphere.swift` 下载，保存到 `MarkdownReader/Animations/SWCharSphere.swift`。

**Step 2:** 在文件最顶部插入来源注释：
```swift
// Source: github.com/signerlabs/ShipSwift — MIT License
// 原样纳入，未修改算法；仅作为加载动画使用。
```

**Step 3:** 编译验证（`mcp__xcode__BuildProject` 或 ⌘B）。
预期：`SWCharSphere` 在主 target 可见，无编译错误（其依赖 iOS 17+ 的 `Canvas`/`TimelineView`，项目目标 iOS 18 满足）。

**Step 4:** Commit
```bash
git add MarkdownReader/Animations/SWCharSphere.swift
git commit -m "feat: 纳入 SWCharSphere 字符球动画（ShipSwift, MIT）"
```

**API 备忘（决定后续调用方式）：** `SWCharSphere` 是带默认值属性的 `struct`，合成 memberwise init 可只传子集。常用入参：`chars: [String]`、`glyphCount: Int`、`colors: [Color]`、`background: Color`、`rotationSpeed: Double`。每个 sphere 点在 init 时被随机指派一个 `chars` 下标（逐帧稳定），故传入"单字符数组"效果最佳。

---

## Task 2：MarkdownKeywords 纯函数 + 逻辑单测（TDD）

把"从 Markdown 文本提取做字符球用的字形"抽成纯函数，便于单测。

**Files:**
- Create: `MarkdownReader/Support/MarkdownKeywords.swift`
- Test: `MarkdownReaderTests/MarkdownKeywordsTests.swift`

**Step 1: 先写失败测试** —— `MarkdownReaderTests/MarkdownKeywordsTests.swift`
```swift
import Testing
@testable import MarkdownReader

struct MarkdownKeywordsTests {
    @Test func 空文本回退到默认字形() {
        #expect(MarkdownKeywords.glyphs(from: "") == ["M", "D"])
        #expect(MarkdownKeywords.glyphs(from: "   \n\t ") == ["M", "D"])
    }

    @Test func 按出现顺序去重单字符() {
        #expect(MarkdownKeywords.glyphs(from: "abca") == ["a", "b", "c"])
    }

    @Test func 过滤标点空白与Markdown标记() {
        // "# 标题\n**粗**" 去掉 #、空白、换行、*，留下中文字
        #expect(MarkdownKeywords.glyphs(from: "# 标题\n**粗**") == ["标", "题", "粗"])
    }

    @Test func 受数量上限约束() {
        let long = String(repeating: "天地玄黄宇宙洪荒", count: 50)
        #expect(MarkdownKeywords.glyphs(from: long, maxCount: 3).count == 3)
    }
}
```

**Step 2: 运行确认失败**
Run: `mcp__xcode__RunSomeTests`（仅 `MarkdownKeywordsTests`）
预期：编译失败 / FAIL —— `MarkdownKeywords` 未定义。

**Step 3: 写最小实现** —— `MarkdownReader/Support/MarkdownKeywords.swift`
```swift
import Foundation

/// 从 Markdown 文本提取用于加载动画字符球的字形集合。
///
/// 逐字符扫描，剔除空白、标点与符号（覆盖 `# * ` > - [ ]` 等 Markdown 标记），
/// 按首次出现顺序去重，并截断到 `maxCount`。空结果回退到 ``fallback``。
enum MarkdownKeywords {
    /// 文本为空或全是被过滤字符时使用的兜底字形。
    static let fallback = ["M", "D"]

    /// 提取字形数组。
    /// - Parameters:
    ///   - markdown: 原始 Markdown 文本。
    ///   - maxCount: 返回字形数量上限，默认 60。
    /// - Returns: 去重后的单字符字符串数组；为空时返回 ``fallback``。
    static func glyphs(from markdown: String, maxCount: Int = 60) -> [String] {
        var seen = Set<Character>()
        var result: [String] = []
        for character in markdown {
            if character.isWhitespace || character.isPunctuation || character.isSymbol { continue }
            guard seen.insert(character).inserted else { continue }
            result.append(String(character))
            if result.count >= maxCount { break }
        }
        return result.isEmpty ? fallback : result
    }
}
```

**Step 4: 运行确认通过**
Run: `mcp__xcode__RunSomeTests`（`MarkdownKeywordsTests`）
预期：4 个测试全部 PASS。

**Step 5: Commit**
```bash
git add MarkdownReader/Support/MarkdownKeywords.swift MarkdownReaderTests/MarkdownKeywordsTests.swift
git commit -m "feat: MarkdownKeywords 字形提取纯函数 + 单测"
```

---

## Task 3：加载视图（文案层 + 动画层）

**Files:**
- Create: `MarkdownReader/Views/SWCharSphereLoadingView.swift`

**Step 1: 创建文件** —— 拆成确定性文案层（快照目标）与组合视图
```swift
import SwiftUI

/// 渲染期间的确定性文案层。**不含动画**，作为快照测试目标。
struct RenderingCaption: View {
    var text: String = "正在渲染…"

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// 文档渲染加载动画：背景字符球 + 底部文案。
struct SWCharSphereLoadingView: View {
    let glyphs: [String]

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.95)

            SWCharSphere(
                chars: glyphs.isEmpty ? MarkdownKeywords.fallback : glyphs,
                glyphCount: 180,
                colors: [.primary, .secondary, Color.accentColor],
                background: .clear,
                rotationSpeed: 0.4
            )
            .frame(width: 260, height: 260)

            RenderingCaption()
                .offset(y: 150)
        }
        .ignoresSafeArea()
    }
}

#Preview("加载动画") {
    SWCharSphereLoadingView(glyphs: MarkdownKeywords.glyphs(from: "天地玄黄 宇宙洪荒 SwiftUI"))
}

#Preview("文案层") {
    RenderingCaption()
}
```

**Step 2: 编译验证**（`mcp__xcode__BuildProject`）。预期无错误。

**Step 3: 人工验证动画层**：用 `mcp__xcode__RenderPreview` 渲染 "加载动画" Preview，确认字符球旋转、文字可见、深浅色下都正常。（动画为时间驱动，故只人工看，不做快照。）

**Step 4: Commit**
```bash
git add MarkdownReader/Views/SWCharSphereLoadingView.swift
git commit -m "feat: SWCharSphereLoadingView 加载动画视图（文案层可快照）"
```

---

## Task 4：文案层快照测试（原生 ImageRenderer，TDD）

用原生 `ImageRenderer` 实现 record-or-compare 快照，无第三方依赖。

**Files:**
- Create: `MarkdownReaderTests/SnapshotTesting.swift`（快照工具）
- Test: `MarkdownReaderTests/RenderingCaptionSnapshotTests.swift`
- 生成: `MarkdownReaderTests/__Snapshots__/*.png`（首跑录制）

**Step 1: 写快照工具** —— `MarkdownReaderTests/SnapshotTesting.swift`
```swift
import Testing
import SwiftUI
import Foundation

/// 极简原生快照工具：用 `ImageRenderer` 把视图渲染成 PNG。
/// 参考图缺失时录制（测试失败并提示），存在时逐字节比对。
@MainActor
enum SnapshotTesting {
    /// 断言视图与已录制参考图一致；缺参考图则录制并使测试失败。
    static func assertSnapshot(
        of view: some View,
        size: CGSize,
        named name: String,
        filePath: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else {
            Issue.record("无法渲染视图为 PNG", sourceLocation: sourceLocation)
            return
        }

        let dir = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let reference = dir.appendingPathComponent("\(name).png")

        guard FileManager.default.fileExists(atPath: reference.path) else {
            try data.write(to: reference)
            Issue.record(
                "已录制参考快照：\(reference.path)。请确认后重跑测试。",
                sourceLocation: sourceLocation
            )
            return
        }

        let expected = try Data(contentsOf: reference)
        #expect(data == expected, "快照与参考图不一致：\(name)", sourceLocation: sourceLocation)
    }
}
```

**Step 2: 写测试** —— `MarkdownReaderTests/RenderingCaptionSnapshotTests.swift`
```swift
import Testing
import SwiftUI
@testable import MarkdownReader

@MainActor
struct RenderingCaptionSnapshotTests {
    @Test func 文案层快照稳定() throws {
        try SnapshotTesting.assertSnapshot(
            of: RenderingCaption().padding(),
            size: CGSize(width: 200, height: 60),
            named: "RenderingCaption"
        )
    }
}
```

**Step 3: 首跑（录制）**
Run: `mcp__xcode__RunSomeTests`（`RenderingCaptionSnapshotTests`）
预期：FAIL，提示已录制 `__Snapshots__/RenderingCaption.png`。检查该 PNG 是否正确显示"正在渲染…"。

**Step 4: 复跑（对比）**
Run: 同上
预期：PASS（与刚录制的参考图逐字节一致）。

**Step 5: Commit**（含参考图）
```bash
git add MarkdownReaderTests/SnapshotTesting.swift \
        MarkdownReaderTests/RenderingCaptionSnapshotTests.swift \
        MarkdownReaderTests/__Snapshots__/RenderingCaption.png
git commit -m "test: RenderingCaption 文案层原生快照测试"
```

---

## Task 5：接入 ReaderView

**Files:**
- Modify: `MarkdownReader/Views/ReaderView.swift`

**Step 1:** 把 `isLoading` 分支里的 `ProgressView("正在渲染…")` 替换为：
```swift
if isLoading {
    SWCharSphereLoadingView(glyphs: MarkdownKeywords.glyphs(from: markdown))
}
```
（`markdown` 在 `.task` 里加载完成、`isLoading` 仍为 true 时即作为字形来源；首帧 `markdown` 为空时 `MarkdownKeywords` 自动回退 `["M","D"]`。）

**Step 2: 编译验证**（`mcp__xcode__BuildProject`）。

**Step 3: 跑全量测试确保无回归**
Run: `mcp__xcode__RunAllTests`
预期：全部 PASS。

**Step 4: 模拟器/Preview 验证**：打开一篇文档，加载时出现字符球动画，渲染完成后消失显示正文。

**Step 5: Commit**
```bash
git add MarkdownReader/Views/ReaderView.swift
git commit -m "feat: ReaderView 加载态接入 SWCharSphere 字符球动画"
```

---

## 阶段目标总结

| Task | 产出 | 验证方式 |
|------|------|---------|
| 1 | 纳入 SWCharSphere.swift（MIT） | 编译 |
| 2 | MarkdownKeywords 字形提取 | 逻辑单测 ×4 |
| 3 | SWCharSphereLoadingView（拆文案层/动画层） | 编译 + Preview 人工看 |
| 4 | RenderingCaption 原生快照测试 | 快照 record→compare |
| 5 | ReaderView 接入 | 全量测试 + 模拟器 |
</content>
</invoke>
