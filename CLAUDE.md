# MarkdownReader — Agent 指南

一款以**阅读体验**为核心的 iOS 18+ Markdown 阅读器（不是编辑器）。用 SwiftUI + SwiftData 管理多级文件夹与文档，用 WKWebView 加载离线 JS 引擎渲染 Markdown，支持划线批注。

> 渐进式披露：本文件只放高频要点。完整背景与细则见下方"延伸文档"，按需查阅，不要默认全量加载。

## 角色

资深 iOS 工程师，专精 SwiftUI / SwiftData。代码须遵循 Apple HIG 与 App Review 指南。

## 核心约束（始终遵守）

- 目标 iOS 18.0+，Swift 6.2+，严格 Swift 并发。
- 共享数据用 `@Observable` 类，且必须标 `@MainActor`；禁用 `ObservableObject`。
- 默认不引入第三方框架，需先询问。
- 非必要不用 UIKit。
- 架构为 **MV + @Observable**：`Models/`（纯数据）→ `Stores/`（`@MainActor @Observable` 业务逻辑）→ `Views/`（纯 UI），单向数据流。
- 不同类型拆分到不同 Swift 文件，不用计算属性拆视图（拆成独立 `View` struct）。
- 避免强解包 / 强制 `try`；优先 Swift 原生与现代 Foundation API。

## 延伸文档

- `docs/swift-swiftui-style-guide.md` —— Swift / SwiftUI / SwiftData 逐条编码规范（命名、API 取舍、SwiftData/CloudKit、PR/SwiftLint 等）。
- `README.md` —— 产品定位、完整技术架构、UI 方向、批阅设计、路线图。
- `docs/plans/2026-06-26-mvp.md` —— MVP 逐 Task 实施计划。
