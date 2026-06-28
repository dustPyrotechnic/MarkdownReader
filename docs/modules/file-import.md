# 文件导入模块

阶段四已实现三条导入入口：系统 Open In / 文件 App、本 App 自定义 URL Scheme、Share Extension。所有入口最终都走 `DocumentImporter`，把外部文件拷贝到 App 沙盒并写入 SwiftData `Document` 记录。

## 文件布局

| 文件 | 职责 |
|------|------|
| `MarkdownReader/Stores/DocumentImporter.swift` | 导入业务核心：扩展名校验、文件名去重、拷贝、SwiftData 登记、安全作用域包装 |
| `MarkdownReader/Support/ShareURLScheme.swift` | 主 App 与 Share Extension 之间的 `markdownreader://import?path=...` 编解码 |
| `MarkdownReader/Support/ImportURLRouter.swift` | `onOpenURL` URL 到导入意图的纯函数路由 |
| `MarkdownReader/Views/RootView.swift` | 接收 URL，导入到「未分类」，保存并跳转阅读页 |
| `MarkdownReaderShare/ShareViewController.swift` | Share Extension 接收分享文件并唤起主 App |
| `Config/MarkdownReader-Info.plist` | Document Types、Markdown UTI、URL Scheme |
| `Config/MarkdownReaderShare-Info.plist` | Share Extension 声明 |

## 数据流

```
系统回调 / Share Extension
    ↓
ImportURLRouter 或 ShareURLScheme
    ↓
DocumentImporter.importSecurityScopedFile
    ↓
Documents/<文件夹名>/<文件名>
    ↓
SwiftData Document(fileName, relativePath)
    ↓
RootView NavigationPath 跳转 ReaderView
```

## 导入规则

- 支持扩展名：`.md`、`.markdown`、`.txt`，大小写不敏感。
- 文件总是拷贝进 `URL.documentsDirectory`，不原地编辑外部文件；`LSSupportsOpeningDocumentsInPlace = false`。
- 默认目标文件夹是 `FolderStore.defaultFolderName`（「未分类」）。
- 重名文件不覆盖，按 `name-1.ext`、`name-2.ext` 递增。
- `relativePath` 始终相对 `Documents/`，格式为 `<文件夹名>/<文件名>`。
- 外部文件 URL 通过 `startAccessingSecurityScopedResource()` 包裹；核心 `importFile` 保持可注入根目录和 `FileManager`，便于单测。

## 测试

自动化测试：

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:MarkdownReaderTests/DocumentImporterTests \
  -only-testing:MarkdownReaderTests/ShareURLSchemeTests \
  -only-testing:MarkdownReaderTests/ImportURLRouterTests
```

完整回归：

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

真机验收项：

- 文件 App 通过「共享 / 打开方式」打开 `.md`，应导入「未分类」并跳转阅读页。
- 微信 / QQ / 其他 App 分享 `.md`，应通过 Share Extension 唤起主 App 并导入。
- 同名导入应生成 `-1` 后缀，不覆盖原文件。
- 分享 `.pdf` 等非法类型不应生成空记录。
