# 阶段四：文件导入（Task 8–10）实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 MarkdownReader 打通三条 `.md` 导入入口——应用内 DocumentImporter 拷贝核心、系统 "Open In / 文件 App" 打开、以及从微信/QQ 等 App 经 Share Extension 导入——把外部文件落入沙盒并登记为 `Document` 记录。

**Architecture:** 遵循 MV + @Observable。导入业务集中在 `Stores/DocumentImporter.swift`（`@MainActor @Observable`），核心拷贝逻辑通过**注入沙盒根目录与 FileManager** 实现可单测；与系统交互的部分（URL Scheme 构造/解析、文件名去重、类型校验）拆成**纯函数**单独单测；真正依赖系统能力的环节（Info.plist 注册、Share Extension 进程、真机分享）只做**手动真机验证**。单向数据流：系统回调 → Importer 拷贝 + 插入 `Document` → SwiftData 驱动 UI。

**Tech Stack:** Swift 6.2、SwiftData、SwiftUI、UniformTypeIdentifiers、App Extension（Share Extension）、Swift Testing（`@Test` / `#expect`）。

---

## 测试方案总览（先读这一段）

| 环节 | 可测性 | 手段 |
|------|--------|------|
| 类型校验（扩展名白名单） | ✅ 纯函数 | Swift Testing 单测 |
| 文件名去重（重名追加 `-1/-2`） | ✅ 纯函数 + 临时目录 | Swift Testing 单测 |
| `importFile` 拷贝 + 写 `Document` | ✅ 注入临时目录 | Swift Testing 单测（内存容器 + `FileManager` 临时目录） |
| Share URL Scheme 构造/解析往返 | ✅ 纯函数 | Swift Testing 单测 |
| `onOpenURL` 路由意图解析 | ✅ 纯函数 | Swift Testing 单测 |
| Info.plist Document Types / UTI 注册 | ❌ | 手动真机：文件 App 长按 `.md` → 用本 App 打开 |
| Share Extension 进程内导入 | ❌ | 手动真机：从其他 App 分享 `.md` |
| Files App 就地编辑可见性 | ❌（Task 13 覆盖） | 手动真机 |

**测试约定（沿用既有工程）：**
- 单测一律用 Swift Testing：`@MainActor struct`、中文 `@Test` 方法名、`#expect`、`TestModelContainer.make()` 取内存容器。
- 凡触碰文件系统的单测，**注入临时目录**（`FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)`），测试末尾清理；**绝不**写真实 `URL.documentsDirectory`。
- 部署目标 iOS 26.5：跑测试须用 **OS 26.5 模拟器**（见 `mvp-progress` 记忆）。
- 不强解包、不强制 `try`；可恢复失败走 `throws` + `ImportError`。

**测试运行命令（每个 Task 末尾用）：**

```bash
xcodebuild test \
  -scheme MarkdownReader \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.5' \
  -only-testing:MarkdownReaderTests/DocumentImporterTests 2>&1 | xcbeautify
```

> 若环境无 `xcbeautify`，去掉管道即可；`-only-testing` 按 Task 替换为对应测试类型名。也可用 Xcode MCP 的 `RunSomeTests`。

---

## Task 8：DocumentImporter 拷贝核心

把外部文件拷入 `Documents/<文件夹名>/<文件名>` 并登记 `Document`。先做两个纯函数（类型校验、文件名去重），再做注入式 `importFile`，最后包安全作用域访问。

**Files:**
- Create: `MarkdownReader/Stores/DocumentImporter.swift`
- Test: `MarkdownReaderTests/DocumentImporterTests.swift`

---

### 8.1 类型校验纯函数

**Step 1: 写失败测试**

`MarkdownReaderTests/DocumentImporterTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import MarkdownReader

@MainActor
struct DocumentImporterTests {
    @Test func 支持的扩展名通过校验() {
        #expect(DocumentImporter.isSupported(fileName: "note.md"))
        #expect(DocumentImporter.isSupported(fileName: "note.markdown"))
        #expect(DocumentImporter.isSupported(fileName: "note.txt"))
        #expect(DocumentImporter.isSupported(fileName: "NOTE.MD"))   // 大小写不敏感
    }

    @Test func 不支持的扩展名被拒() {
        #expect(!DocumentImporter.isSupported(fileName: "a.pdf"))
        #expect(!DocumentImporter.isSupported(fileName: "noext"))
    }
}
```

**Step 2: 跑测试确认失败**

Run（同上命令，`-only-testing:MarkdownReaderTests/DocumentImporterTests`）
Expected: 编译失败 —— `DocumentImporter` 未定义。

**Step 3: 最小实现**

`MarkdownReader/Stores/DocumentImporter.swift`：

```swift
import Foundation
import SwiftData
import Observation

/// 文件导入业务：把外部文件拷入沙盒并登记 `Document` 记录。
@MainActor
@Observable
final class DocumentImporter {
    /// 受支持的 Markdown 文本扩展名（小写）。
    static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    /// 判断文件名扩展名是否受支持（大小写不敏感）。
    /// - Parameter fileName: 含扩展名的文件名。
    /// - Returns: 受支持返回 `true`。
    static func isSupported(fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }
}
```

**Step 4: 跑测试确认通过** —— Expected: 2 passed。

**Step 5: Commit**

```bash
git add MarkdownReader/Stores/DocumentImporter.swift MarkdownReaderTests/DocumentImporterTests.swift
git commit -m "feat: DocumentImporter 扩展名白名单校验纯函数 + 单测"
```

---

### 8.2 文件名去重纯函数

**Step 1: 写失败测试**（追加到 `DocumentImporterTests`）

```swift
    @Test func 目录为空时文件名原样返回() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let name = DocumentImporter.uniqueFileName(for: "a.md", in: dir, fileManager: .default)
        #expect(name == "a.md")
    }

    @Test func 重名时追加序号() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appending(path: "a.md").path, contents: nil)
        FileManager.default.createFile(atPath: dir.appending(path: "a-1.md").path, contents: nil)

        let name = DocumentImporter.uniqueFileName(for: "a.md", in: dir, fileManager: .default)
        #expect(name == "a-2.md")
    }
```

**Step 2: 跑测试确认失败** —— Expected: 编译失败，`uniqueFileName` 未定义。

**Step 3: 最小实现**（加入 `DocumentImporter`）

```swift
    /// 在目标目录内为 `fileName` 求一个不冲突的文件名；重名时按 `name-1.ext`、`name-2.ext` 递增。
    /// - Parameters:
    ///   - fileName: 期望文件名（含扩展名）。
    ///   - directory: 目标目录。
    ///   - fileManager: 文件管理器（可注入）。
    /// - Returns: 该目录下尚未占用的文件名。
    static func uniqueFileName(for fileName: String, in directory: URL, fileManager: FileManager) -> String {
        let ns = fileName as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        var candidate = fileName
        var index = 1
        while fileManager.fileExists(atPath: directory.appending(path: candidate).path) {
            let suffix = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            candidate = suffix
            index += 1
        }
        return candidate
    }
```

**Step 4: 跑测试确认通过** —— Expected: 4 passed。

**Step 5: Commit**

```bash
git add MarkdownReader/Stores/DocumentImporter.swift MarkdownReaderTests/DocumentImporterTests.swift
git commit -m "feat: DocumentImporter 文件名去重纯函数 + 单测"
```

---

### 8.3 importFile：拷贝 + 登记 Document（注入沙盒根目录）

**Step 1: 写失败测试**（追加）

```swift
    /// 造一个临时「外部源文件」。
    private func makeSourceFile(name: String, body: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: name)
        try? body.data(using: .utf8)?.write(to: url)
        return url
    }

    @Test func 导入后文件落沙盒且生成Document记录() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)

        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        let source = makeSourceFile(name: "hello.md", body: "# Hi")
        let doc = try importer.importFile(from: source, into: folder, context: context)

        #expect(doc.fileName == "hello.md")
        #expect(doc.relativePath == "技术/hello.md")
        #expect(doc.folder?.id == folder.id)
        let copied = sandbox.appending(path: "技术/hello.md")
        #expect(FileManager.default.fileExists(atPath: copied.path))
        #expect((try? String(contentsOf: copied, encoding: .utf8)) == "# Hi")
    }

    @Test func 同名导入两次不覆盖而是去重() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)
        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        _ = try importer.importFile(from: makeSourceFile(name: "a.md", body: "1"), into: folder, context: context)
        let second = try importer.importFile(from: makeSourceFile(name: "a.md", body: "2"), into: folder, context: context)

        #expect(second.fileName == "a-1.md")
        #expect(second.relativePath == "技术/a-1.md")
    }

    @Test func 不支持的类型抛错且不落盘() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)
        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        let source = makeSourceFile(name: "a.pdf", body: "x")
        #expect(throws: DocumentImporter.ImportError.unsupportedType) {
            try importer.importFile(from: source, into: folder, context: context)
        }
    }
```

**Step 2: 跑测试确认失败** —— Expected: 编译失败，`init(documentsBaseURL:fileManager:)` / `importFile` / `ImportError` 未定义。

**Step 3: 最小实现**（补全 `DocumentImporter` 主体）

```swift
    /// 可恢复的导入错误。
    enum ImportError: Error, Equatable {
        case unsupportedType
        case unreadableSource
        case copyFailed
    }

    /// 是否正在导入（驱动 UI 加载态）。
    private(set) var isImporting = false
    /// 最近一次失败的本地化描述。
    var lastError: String?

    private let documentsBaseURL: URL
    private let fileManager: FileManager

    /// - Parameters:
    ///   - documentsBaseURL: 沙盒文档根目录；生产用 `URL.documentsDirectory`，测试注入临时目录。
    ///   - fileManager: 文件管理器（可注入）。
    init(documentsBaseURL: URL = URL.documentsDirectory, fileManager: FileManager = .default) {
        self.documentsBaseURL = documentsBaseURL
        self.fileManager = fileManager
    }

    /// 把外部文件拷入沙盒目标文件夹并登记 `Document`。
    /// - Parameters:
    ///   - sourceURL: 外部源文件（可能是安全作用域 URL）。
    ///   - folder: 目标文件夹。
    ///   - context: SwiftData 上下文。
    /// - Returns: 新建的 `Document`。
    /// - Throws: `ImportError`。
    @discardableResult
    func importFile(from sourceURL: URL, into folder: Folder, context: ModelContext) throws -> Document {
        guard Self.isSupported(fileName: sourceURL.lastPathComponent) else {
            throw ImportError.unsupportedType
        }

        let destDir = documentsBaseURL.appending(path: folder.name)
        do {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            throw ImportError.copyFailed
        }

        let fileName = Self.uniqueFileName(
            for: sourceURL.lastPathComponent,
            in: destDir,
            fileManager: fileManager
        )
        let destURL = destDir.appending(path: fileName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw ImportError.copyFailed
        }

        let relativePath = "\(folder.name)/\(fileName)"
        let document = Document(fileName: fileName, relativePath: relativePath)
        context.insert(document)
        document.folder = folder
        return document
    }
```

**Step 4: 跑测试确认通过** —— Expected: 7 passed。

**Step 5: Commit**

```bash
git add MarkdownReader/Stores/DocumentImporter.swift MarkdownReaderTests/DocumentImporterTests.swift
git commit -m "feat: DocumentImporter.importFile 拷贝落盘 + 登记 Document + 单测"
```

---

### 8.4 安全作用域包装 + 便捷入口

外部 URL（文件 App / 分享）多为安全作用域资源，须 `startAccessingSecurityScopedResource()` 包裹。该行为依赖真实系统权限，无法单测，封成薄包装方法，导入核心仍走已测的 `importFile`。

**Step 1: 加入 `DocumentImporter`**

```swift
    /// 安全作用域包装版导入：先申请访问权限再调用 `importFile`，并维护 `isImporting`/`lastError`。
    /// - Returns: 成功返回 `Document`，失败返回 `nil`（错误写入 `lastError`）。
    @discardableResult
    func importSecurityScopedFile(from sourceURL: URL, into folder: Folder, context: ModelContext) -> Document? {
        isImporting = true
        defer { isImporting = false }

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            return try importFile(from: sourceURL, into: folder, context: context)
        } catch {
            lastError = (error as? ImportError).map(Self.message(for:)) ?? error.localizedDescription
            return nil
        }
    }

    private static func message(for error: ImportError) -> String {
        switch error {
        case .unsupportedType: "不支持的文件类型，仅支持 .md / .markdown / .txt"
        case .unreadableSource: "无法读取来源文件"
        case .copyFailed: "文件拷贝失败"
        }
    }
```

**Step 2: 编译验证** —— Run: `xcodebuild build -scheme MarkdownReader -destination '...OS=26.5'`，Expected: 成功。

**Step 3: Commit**

```bash
git add MarkdownReader/Stores/DocumentImporter.swift
git commit -m "feat: DocumentImporter 安全作用域导入包装"
```

---

## Task 9：Open In / 文件 App 打开

注册 Document Types + UTI，App 收 `onOpenURL` 后把文件导入「未分类」并跳转。URL → 意图的解析做成纯函数单测，系统注册与真机打开靠手动验证。

**Files:**
- Modify: `MarkdownReader/MarkdownReaderApp.swift`
- Modify: `MarkdownReader/Views/RootView.swift`
- Create: `MarkdownReader/Support/ImportURLRouter.swift`
- Test: `MarkdownReaderTests/ImportURLRouterTests.swift`
- Modify: 项目 Info（Xcode Target → Info）

---

### 9.1 ImportURLRouter 意图解析纯函数

区分两类传入 URL：系统的本地文件 URL（Open In / 文件 App）、自定义 scheme `markdownreader://import?path=...`（Share Extension 回传，Task 10 用）。

**Step 1: 写失败测试** `MarkdownReaderTests/ImportURLRouterTests.swift`

```swift
import Testing
import Foundation
@testable import MarkdownReader

struct ImportURLRouterTests {
    @Test func 本地文件URL解析为openInPlace() {
        let url = URL(fileURLWithPath: "/tmp/a.md")
        #expect(ImportURLRouter.intent(for: url) == .openInPlace(url))
    }

    @Test func 自定义scheme解析为shareImport() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/b.md")
        let scheme = try #require(ShareURLScheme.makeImportURL(for: fileURL))
        #expect(ImportURLRouter.intent(for: scheme) == .shareImport(fileURL))
    }

    @Test func 无法识别的URL返回nil() {
        #expect(ImportURLRouter.intent(for: URL(string: "https://example.com")!) == nil)
    }
}
```

> 本测试依赖 `ShareURLScheme`（Task 10.1 定义）。建议先做 10.1 再做 9.1，或暂时注释第二个用例、待 10.1 完成解注。

**Step 2: 跑测试确认失败** —— Expected: 编译失败，`ImportURLRouter` 未定义。

**Step 3: 最小实现** `MarkdownReader/Support/ImportURLRouter.swift`

```swift
import Foundation

/// 把外部传入的 URL 归类为导入意图（纯函数，便于单测）。
enum ImportURLRouter {
    /// 导入意图。
    enum Intent: Equatable {
        /// 系统本地文件 URL（Open In / 文件 App）。
        case openInPlace(URL)
        /// 自定义 scheme 携带的文件 URL（Share Extension 回传）。
        case shareImport(URL)
    }

    /// 解析传入 URL 的导入意图。
    /// - Parameter url: `onOpenURL` 收到的 URL。
    /// - Returns: 可识别返回对应意图，否则 `nil`。
    static func intent(for url: URL) -> Intent? {
        if url.isFileURL {
            return .openInPlace(url)
        }
        if let fileURL = ShareURLScheme.fileURL(fromImportURL: url) {
            return .shareImport(fileURL)
        }
        return nil
    }
}
```

**Step 4: 跑测试确认通过** —— Expected: 3 passed（依赖 10.1 完成）。

**Step 5: Commit**

```bash
git add MarkdownReader/Support/ImportURLRouter.swift MarkdownReaderTests/ImportURLRouterTests.swift
git commit -m "feat: ImportURLRouter 导入意图解析纯函数 + 单测"
```

---

### 9.2 App 接线：onOpenURL → 导入 → 跳转

**Step 1: 改 `MarkdownReaderApp.swift`** 注入 importer

```swift
    @State private var folderStore = FolderStore()
    @State private var importer = DocumentImporter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(folderStore)
                .environment(importer)
        }
        .modelContainer(container)
    }
```

**Step 2: 改 `RootView.swift`** 加 `onOpenURL` 处理

```swift
    @Environment(DocumentImporter.self) private var importer
```

在 `NavigationStack { ... }` 的修饰链上追加：

```swift
        .onOpenURL { url in handleIncoming(url) }
```

并新增私有方法：

```swift
    /// 处理外部传入的导入 URL：拷入「未分类」并跳转到阅读页。
    private func handleIncoming(_ url: URL) {
        guard let intent = ImportURLRouter.intent(for: url) else { return }
        let fileURL: URL = switch intent {
        case .openInPlace(let u): u
        case .shareImport(let u): u
        }
        let unfiled = folderStore.ensureDefaultFolder(context: context)
        guard let document = importer.importSecurityScopedFile(from: fileURL, into: unfiled, context: context) else { return }
        try? context.save()
        path = NavigationPath()
        path.append(unfiled)
        path.append(document)
    }
```

**Step 3: 编译验证** —— Expected: 成功。

**Step 4: Commit**

```bash
git add MarkdownReader/MarkdownReaderApp.swift MarkdownReader/Views/RootView.swift
git commit -m "feat: onOpenURL 导入并跳转到阅读页"
```

---

### 9.3 注册 Document Types + UTI（手动 + 真机验证）

**Step 1: Xcode → 选中 App Target → Info 标签 → Document Types** 新增一条：

| 字段 | 值 |
|------|---|
| Name | Markdown Document |
| Types | `net.daringfireball.markdown`, `public.plain-text` |
| Additional `CFBundleTypeExtensions` | `md`, `markdown`, `txt` |
| LSHandlerRank | Alternate |

**Step 2: Imported / Exported UTIs** 新增（Markdown 无系统 UTI，声明为 Exported）：

| 字段 | 值 |
|------|---|
| Identifier | `net.daringfireball.markdown` |
| Conforms To | `public.plain-text` |
| Extensions | `md`, `markdown` |

**Step 3: 真机测试（无法单测）**
- 文件 App 里长按一个 `.md` → 「共享」/「打开方式」→ 选 MarkdownReader。
- 预期：App 启动 → 文件出现在「未分类」→ 自动跳转阅读页正常渲染。

**Step 4: Commit**

```bash
git add MarkdownReader.xcodeproj
git commit -m "feat: 注册 .md Document Types 与 Exported UTI 支持 Open In"
```

---

## Task 10：Share Extension（从其他 App 分享导入）

新建 Share Extension Target；扩展把分享的文件经自定义 scheme 回传主 App。Scheme 的构造/解析纯函数单测，扩展进程行为靠真机验证。

**Files:**
- Create: `MarkdownReader/Support/ShareURLScheme.swift`（Target Membership：**主 App + 扩展**）
- Test: `MarkdownReaderTests/ShareURLSchemeTests.swift`
- Create: 新 Target `MarkdownReaderShare`（Share Extension）
- Create: `MarkdownReaderShare/ShareViewController.swift`
- Modify: 主 App Info —— 注册 URL Scheme `markdownreader`

---

### 10.1 ShareURLScheme 往返纯函数

**Step 1: 写失败测试** `MarkdownReaderTests/ShareURLSchemeTests.swift`

```swift
import Testing
import Foundation
@testable import MarkdownReader

struct ShareURLSchemeTests {
    @Test func 构造再解析得到原文件URL() throws {
        let fileURL = URL(fileURLWithPath: "/private/tmp/我的 笔记.md")
        let importURL = try #require(ShareURLScheme.makeImportURL(for: fileURL))
        #expect(importURL.scheme == "markdownreader")
        #expect(ShareURLScheme.fileURL(fromImportURL: importURL) == fileURL)
    }

    @Test func 非本scheme解析返回nil() {
        #expect(ShareURLScheme.fileURL(fromImportURL: URL(string: "https://x.com")!) == nil)
    }
}
```

**Step 2: 跑测试确认失败** —— Expected: 编译失败，`ShareURLScheme` 未定义。

**Step 3: 最小实现** `MarkdownReader/Support/ShareURLScheme.swift`

```swift
import Foundation

/// 主 App 与 Share Extension 之间传递「待导入文件 URL」的自定义 scheme 编解码（纯函数）。
enum ShareURLScheme {
    /// 自定义 scheme 名。
    static let scheme = "markdownreader"
    private static let host = "import"
    private static let pathQueryName = "path"

    /// 用文件 URL 构造可唤起主 App 的导入 URL。
    /// - Parameter fileURL: 待导入的本地文件 URL。
    /// - Returns: `markdownreader://import?path=<percent-encoded file url>`。
    static func makeImportURL(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: pathQueryName, value: fileURL.absoluteString)]
        return components.url
    }

    /// 从导入 URL 还原文件 URL。
    /// - Parameter url: 形如 `markdownreader://import?path=...` 的 URL。
    /// - Returns: 还原的文件 URL，非本 scheme 返回 `nil`。
    static func fileURL(fromImportURL url: URL) -> URL? {
        guard url.scheme == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == pathQueryName })?.value,
              let fileURL = URL(string: value),
              fileURL.isFileURL
        else { return nil }
        return fileURL
    }
}
```

**Step 4: 跑测试确认通过** —— Expected: 2 passed。（此后回到 9.1 解注那条用例并确认全绿）

**Step 5: Commit**

```bash
git add MarkdownReader/Support/ShareURLScheme.swift MarkdownReaderTests/ShareURLSchemeTests.swift
git commit -m "feat: ShareURLScheme 导入 URL 往返编解码 + 单测"
```

---

### 10.2 新建 Share Extension Target + ShareViewController

**Step 1: Xcode → File → New → Target → Share Extension**，命名 `MarkdownReaderShare`；语言 Swift。完成后删掉模板自带的 `MainInterface.storyboard` 相关、改为代码实现（或保留默认，仅替换 `ShareViewController`）。

**Step 2: 把 `ShareURLScheme.swift` 勾选进扩展 Target Membership**（File Inspector → Target Membership 勾 `MarkdownReaderShare`）。

**Step 3: 实现 `MarkdownReaderShare/ShareViewController.swift`**

```swift
import UIKit
import UniformTypeIdentifiers

/// Share Extension：接收分享的 .md/.txt，经自定义 scheme 唤起主 App 导入。
final class ShareViewController: UIViewController {
    private static let candidateTypeIDs = [
        "net.daringfireball.markdown",
        UTType.plainText.identifier,
        UTType.text.identifier
    ]

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: { provider in
                  Self.candidateTypeIDs.contains { provider.hasItemConformingToTypeIdentifier($0) }
              }),
              let typeID = Self.candidateTypeIDs.first(where: { provider.hasItemConformingToTypeIdentifier($0) })
        else {
            finish()
            return
        }

        provider.loadItem(forTypeIdentifier: typeID) { [weak self] item, _ in
            DispatchQueue.main.async {
                if let url = item as? URL, let importURL = ShareURLScheme.makeImportURL(for: url) {
                    self?.openMainApp(importURL)
                }
                self?.finish()
            }
        }
    }

    private func openMainApp(_ url: URL) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url)
                return
            }
            responder = current.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
```

**Step 4: 主 App Info 注册 URL Scheme** —— Target → Info → URL Types 新增一条，Identifier `com.<bundle>.import`，URL Schemes 填 `markdownreader`。

**Step 5: 编译两个 Target** —— Run: `xcodebuild build -scheme MarkdownReader -destination '...OS=26.5'`，Expected: 成功（含扩展）。

**Step 6: Commit**

```bash
git add MarkdownReaderShare MarkdownReader MarkdownReader.xcodeproj
git commit -m "feat: Share Extension 经自定义 scheme 导入 .md 到主 App"
```

---

### 10.3 真机联调（无法单测）

**Step 1:** 真机装上含扩展的构建。
**Step 2:** 微信/QQ/文件 收到 `.md` → 分享面板选 MarkdownReader。
**Step 3:** 预期：主 App 被唤起 → 文件进「未分类」→ 跳转阅读页渲染正常。
**Step 4:** 异常路径：分享一个 `.pdf` → 应被类型白名单忽略、不产生空记录。

**Step 5: Commit**（如需修正）

```bash
git commit -am "fix: Share Extension 真机联调修正"
```

---

## 阶段四完成标准（Definition of Done）

- [x] `DocumentImporterTests` / `ImportURLRouterTests` / `ShareURLSchemeTests` 全绿（OS 26.5 模拟器）。
- [x] 文件 App「打开方式」可导入并跳转阅读页（真机）。
- [x] 其他 App 分享 `.md` 可导入并跳转（真机）。
- [x] 同名文件不覆盖、非法类型不落空记录。
- [x] 更新项目文档：`README.md`、`CLAUDE.md`、`docs/modules/file-import.md`、`docs/plans/2026-06-26-mvp.md`。

> 实测说明：本机没有 `iPhone 16, OS=26.5` 模拟器，自动化测试使用 `iPhone 17, OS=26.5`。

---

## 备注：与既有代码的衔接点

- `FolderStore.ensureDefaultFolder(context:)` 已存在，导入「未分类」直接复用，勿重复造默认文件夹逻辑。
- `Document` 初始化为 `Document(fileName:relativePath:)`，`relativePath` 相对 `Documents/`，与 `FolderStore.seedRendererTestDocumentsIfNeeded` 的落盘约定一致——拷贝目录结构沿用 `Documents/<文件夹名>/<文件名>`。
- `RootView` 已用 `NavigationPath path` 驱动 `Folder`/`Document` 跳转，导入后 `path.append` 即可复用现有 `navigationDestination`。
- DEBUG seeding 与导入互不影响（不同文件夹），无需改动。
```
