# 阶段四：文件导入实习计划

## 目标

通过阶段四文件导入模块，让实习同学理解 MarkdownReader 的外部文件接入链路，并能独立完成一次从需求拆解、单测补齐、真机验收到文档沉淀的完整工程闭环。

阶段四已实现的三条入口：

- 系统 Open In / 文件 App 打开 `.md` / `.markdown` / `.txt`
- App 自定义 URL Scheme：`markdownreader://import`
- Share Extension 从微信、QQ、文件 App 等外部应用转交文件

相关实施细节见 `docs/plans/2026-06-28-task8-10-file-import.md`，当前模块说明见 `docs/modules/file-import.md`。

## 学习前置

实习同学开始前需要先阅读：

- `CLAUDE.md`：项目约束、架构边界、SwiftUI / SwiftData 规则
- `README.md`：产品定位与 MVP 范围
- `docs/modules/file-import.md`：文件导入模块当前设计
- `docs/plans/2026-06-28-task8-10-file-import.md`：阶段四原始实施计划

需要重点理解：

- MV + `@Observable` 的单向数据流
- SwiftData `Document` / `Folder` 的关系
- 外部文件为什么必须拷贝进 App 沙盒
- Share Extension 与主 App 之间为什么通过 URL Scheme 串联
- 单测为什么不能写真实 `URL.documentsDirectory`

## 实习任务安排

### 第 1 天：模块走读

目标：能用自己的话描述阶段四完整链路。

任务：

- 阅读 `DocumentImporter`、`ImportURLRouter`、`ShareURLScheme`
- 阅读 `RootView.onOpenURL` 的导入跳转逻辑
- 阅读 `MarkdownReaderShare/ShareViewController.swift`
- 画出链路：外部 URL → 路由解析 → 沙盒拷贝 → SwiftData 记录 → 阅读页跳转

产出：

- 一段 300 字以内的模块说明
- 标出至少 3 个可能失败点，例如不支持扩展名、文件不存在、重名文件、Share Extension 回调失败

### 第 2 天：测试理解与补充

目标：能理解阶段四哪些逻辑可自动测试，哪些必须真机验证。

任务：

- 运行阶段四相关测试：

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:MarkdownReaderTests/DocumentImporterTests \
  -only-testing:MarkdownReaderTests/ImportURLRouterTests \
  -only-testing:MarkdownReaderTests/ShareURLSchemeTests
```

- 阅读失败路径测试，确认是否覆盖：
  - 不支持扩展名
  - 同名文件去重
  - URL Scheme 构造与解析
  - 导入后 `Document.relativePath` 正确

产出：

- 一份测试覆盖说明
- 如发现缺口，补 1 到 2 个小型单测

### 第 3 天：真机验收

目标：完成阶段四必须依赖系统能力的人工验收。

任务：

- 从文件 App 打开 `.md`
- 从第三方 App 分享 `.md`
- 重复导入同名文件，确认不会覆盖
- 导入不支持的文件类型，确认不会生成空记录
- 验证导入成功后跳转阅读页

产出：

- 真机验收记录，包含设备型号、系统版本、测试文件名、结果
- 至少 1 张关键路径截图，存放到本地验收记录目录或附在 PR 描述中

### 第 4 天：问题修复或文档收尾

目标：根据测试和真机验收结果完成闭环。

任务：

- 若发现缺陷，按最小改动修复
- 若无缺陷，整理阶段四模块文档
- 确认 `docs/modules/file-import.md` 与当前实现一致
- 在 PR 或提交说明里写清楚测试命令与真机验收结果

产出：

- 修复 PR 或文档更新 PR
- 清晰的验收结论

## 验收标准

实习同学完成阶段四学习与实践后，应满足：

- 能解释 `DocumentImporter` 为什么是阶段四核心
- 能说明 Open In、URL Scheme、Share Extension 三条入口的差异
- 能独立运行并定位阶段四相关单测
- 能完成一次真机导入验收
- 能在不破坏既有架构的前提下补充小型失败路径测试
- 文档中没有与当前实现冲突的描述

## 风险提醒

- 不要把 Info.plist 放进 file-system-synchronized target 目录，避免被重复复制进 Bundle。
- 不要让 Share Extension 直接写主 App SwiftData；当前设计是通过 URL Scheme 唤起主 App，由主 App 统一导入。
- 不要在单测里写真实 Documents 目录；必须使用临时目录和内存 SwiftData 容器。
- 不要扩大导入类型白名单，除非产品范围明确变更。
- `ShareURLScheme.swift` 同时编入主 App 与 Share Extension，修改后必须确认两个 target 都能编译。

