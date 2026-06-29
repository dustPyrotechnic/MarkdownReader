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

## 当前模块要点

- 文件导入已完成：`DocumentImporter` 负责校验、去重、沙盒拷贝与 `Document` 登记；Open In、文件 App、Share Extension 最终都导入到「未分类」。
- 导入只支持 `.md` / `.markdown` / `.txt`；重名追加 `-1/-2`；当前是拷贝入沙盒，不原地打开外部文件。
- 主 App Info 与 Share Extension Info 放在 `Config/`，不要放进 file-system-synchronized target 目录，避免被当作 Bundle Resource 重复复制。
- `ShareURLScheme.swift` 同时编入主 App 与 `MarkdownReaderShare`，修改时必须确保两个 target 都能编译。

## 延伸文档

- `docs/swift-swiftui-style-guide.md` —— Swift / SwiftUI / SwiftData 逐条编码规范（命名、API 取舍、SwiftData/CloudKit、PR/SwiftLint 等）。
- `docs/modules/file-import.md` —— 文件导入模块设计、文件布局、测试和真机验收项。
- `README.md` —— 产品定位、完整技术架构、UI 方向、批阅设计、路线图。
- `docs/plans/2026-06-26-mvp.md` —— MVP 逐 Task 实施计划。
- `docs/plans/2026-06-29-phase4-deliverables.md` —— 阶段四文件导入交付记录（模块走读、测试覆盖、真机验收表）。
- `docs/plans/2026-06-29-phase5-annotation.md` —— 阶段五批阅 HUD + 持久化逐 Task 实施计划。
