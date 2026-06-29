# 阶段四交付记录

对应计划：`docs/plans/2026-06-29-phase4-internship-plan.md`。
本文档沉淀第 1、2、4 天的产出；第 3 天真机验收表留空，由验收人现场填写。

## 第 1 天：模块走读

### 模块说明（300 字以内）

阶段四把外部文件接入统一收敛到一条链路。三条入口——系统 Open In / 文件 App、自定义 URL Scheme（`markdownreader://import`）、Share Extension——最终都汇到主 App 的 `RootView.onOpenURL`。`ImportURLRouter` 把传入 URL 解析为 `openInPlace`（本地 file URL）或 `shareImport`（自定义 scheme，经 `ShareURLScheme.fileURL` 还原文件 URL）两种意图，无法识别返回 `nil`。Share Extension 自身不写 SwiftData，只用 `ShareURLScheme.makeImportURL` 编码文件 URL 后唤起主 App，保证导入逻辑单点。拿到文件 URL 后，`RootView` 取「未分类」文件夹，调用 `DocumentImporter.importSecurityScopedFile`：包裹安全作用域权限、校验扩展名、按 `name-1.ext` 去重、拷贝进 `Documents/<文件夹>/`、登记 `Document(fileName, relativePath)`。成功后保存并把文件夹与文档压入 `NavigationPath` 跳转阅读页；失败写入 `lastError` 且不落盘。外部文件一律拷入沙盒而非原地打开（`LSSupportsOpeningDocumentsInPlace = false`）。

### 链路图

```
外部 URL（Open In / Scheme / Share Extension）
    → ImportURLRouter.intent  → openInPlace / shareImport
    → folderStore.ensureDefaultFolder（未分类）
    → DocumentImporter.importSecurityScopedFile
        → 扩展名校验 → 安全作用域 → 去重 → 拷贝沙盒 → SwiftData Document
    → context.save → NavigationPath 跳转 ReaderView
```

### 失败点

1. **不支持扩展名**：非 `.md/.markdown/.txt` → `ImportError.unsupportedType`，不落盘。
2. **来源文件不存在 / 不可读**：路径无效或无权限 → `ImportError.unreadableSource`。
3. **重名文件**：同名导入不覆盖，递增为 `a-1.md`、`a-2.md`。
4. **拷贝失败**：建目录或 `copyItem` 失败 → `ImportError.copyFailed`。
5. **URL 无法识别**：既非 file URL 又非本 scheme，`ImportURLRouter.intent` 返回 `nil`，静默忽略。
6. **Share Extension 取不到附件**：无符合类型的 `attachment` 时直接 `completeRequest`，不唤起主 App。

## 第 2 天：测试覆盖说明

可自动化（纯函数 / 可注入根目录与 `FileManager` + 内存 SwiftData 容器）：

| 测试套件 | 覆盖点 |
|----------|--------|
| `DocumentImporterTests` | 扩展名校验（含大小写）、空目录原样返回、重名递增、导入落沙盒并生成 `Document`、同名去重不覆盖、不支持类型抛错且不落盘 |
| `ImportURLRouterTests` | 本地 file URL → `openInPlace`、自定义 scheme → `shareImport`、无法识别 → `nil` |
| `ShareURLSchemeTests` | 构造再解析往返一致（含中文 / 空格文件名）、非本 scheme → `nil` |

本次补充的失败路径单测（计划第 2 天「补 1 到 2 个小型单测」）：

- `来源文件不存在时抛unreadableSource()`：覆盖计划点名的「文件不存在」失败点。
- `安全作用域导入失败时返回nil并写入lastError()`：覆盖主 App 实际入口 `importSecurityScopedFile` 的失败分支与状态位（`lastError` 写入、`isImporting` 复位）。

只能真机验证（依赖系统能力，无法在单测内伪造）：

- 系统 Open In / 文件 App 的真实 UTI 关联与回调。
- Share Extension 在第三方 App（微信 / QQ）内的出现与附件类型解析。
- 自定义 scheme 真正唤起主 App 的跨进程跳转。
- `startAccessingSecurityScopedResource()` 在真实安全作用域 URL 上的权限申请。

运行命令：

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:MarkdownReaderTests/DocumentImporterTests \
  -only-testing:MarkdownReaderTests/ImportURLRouterTests \
  -only-testing:MarkdownReaderTests/ShareURLSchemeTests
```

结果：**TEST SUCCEEDED**，14 个用例全部通过（2026-06-29，iPhone 17 / iOS 26.5 模拟器）。

## 第 3 天：真机验收记录（待填写）

| 设备型号 | 系统版本 | 测试场景 | 测试文件名 | 结果 |
|----------|----------|----------|-----------|------|
|  |  | 文件 App 打开 `.md` |  |  |
|  |  | 第三方 App 分享 `.md` |  |  |
|  |  | 重复导入同名文件（不覆盖，应得 `-1`） |  |  |
|  |  | 导入不支持类型（不生成空记录） |  |  |
|  |  | 导入成功跳转阅读页 |  |  |

> 关键路径截图：留存到 PR 描述或本地验收目录。

## 第 4 天：文档一致性核对

- `docs/modules/file-import.md` 文件布局、数据流、导入规则、测试章节与当前实现一致，无冲突描述。
- 风险提醒（Info.plist 位置、Share Extension 不直写 SwiftData、单测不写真实 Documents 目录、不扩大类型白名单、`ShareURLScheme.swift` 双 target 编译）均与当前代码约束一致。
