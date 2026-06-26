# MarkdownReader

一款以**阅读体验**为核心的 iOS Markdown 文档库，支持从微信、QQ 等应用一键导入 `.md` 文件，提供完整渲染、多级文件夹管理与批阅功能。

---

## 定位

> 不是编辑器，是阅读器 + 文档库。

用户从聊天软件收到 `.md` 文件后，选择"用 MarkdownReader 打开"，文件自动存入"未分类"文件夹，按需整理到自建文件夹长期保存。

---

## MVP 功能范围

| 模块 | 内容 |
|------|------|
| 导入 | Open In、Share Extension、Files App 集成 |
| 渲染 | 完整 GFM + 数学公式（KaTeX）+ 流程图（Mermaid.js） |
| 文件管理 | 多级嵌套文件夹，默认"未分类"，支持移动 |
| 批阅 | 划选文字后添加简短文字或 Emoji 评注 |
| 主题 | 跟随系统深浅色，渲染主题自动切换（GitHub Light / Dark） |
| 变现 | MVP 阶段完全免费 |

编辑功能在 MVP 之后上线。

---

## 技术架构

### 架构模式：MV + @Observable

本项目采用 **MV + @Observable** 架构。`@Observable` 是 Swift 5.9 引入的宏，让 Store 类具备自动通知 View 刷新的能力，与 SwiftData 原生无缝配合。

#### 三层职责

**Model**（`Models/`）——只描述数据结构，不含逻辑

```swift
@Model class Folder {
    var name: String
    var parent: Folder?
    @Relationship(deleteRule: .cascade) var children: [Folder] = []
    @Relationship(deleteRule: .cascade) var documents: [Document] = []
}

@Model class Document {
    var fileName: String
    var filePath: String
    var createdAt: Date
    var folder: Folder?
}

@Model class Annotation {
    var documentID: String
    var rangeStart: Int
    var rangeEnd: Int
    var comment: String
    var emoji: String?
}
```

**Store**（`Stores/`）——业务逻辑，相当于 MVC 的 Controller

```swift
@Observable
class FolderStore {
    var rootFolders: [Folder] = []

    func createFolder(name: String, parent: Folder? = nil, context: ModelContext) {
        let folder = Folder(name: name, parent: parent)
        context.insert(folder)
    }

    func move(_ document: Document, to folder: Folder) {
        document.folder = folder
    }
}

@Observable
class DocumentImporter {
    var isImporting: Bool = false

    func importFile(url: URL, into folder: Folder, context: ModelContext) async {
        isImporting = true
        // 复制文件到沙盒，写入 SwiftData
        isImporting = false
    }
}
```

**View**（`Views/`）——纯 UI，不含业务判断，通过 Store 触发动作

```swift
struct FolderListView: View {
    @Environment(FolderStore.self) private var folderStore
    @Environment(\.modelContext) private var context

    var body: some View {
        List(folderStore.rootFolders) { folder in
            NavigationLink(folder.name) {
                DocumentListView(folder: folder)
            }
        }
        .toolbar {
            Button("新建文件夹") {
                folderStore.createFolder(name: "新文件夹", context: context)
            }
        }
    }
}
```

#### 单向数据流

```
用户操作
    ↓
View 调用 Store 方法
    ↓
Store 修改 SwiftData Model
    ↓
SwiftData 自动通知 View 刷新
    ↓
View 更新 UI
```

数据永远单向流动，不会出现 View 直接改 Model 的混乱情况。

#### 项目文件结构

```
MarkdownReader/
├── Models/
│   ├── Folder.swift
│   ├── Document.swift
│   └── Annotation.swift
├── Stores/
│   ├── FolderStore.swift
│   ├── DocumentImporter.swift
│   └── AnnotationStore.swift
├── Views/
│   ├── FolderListView.swift
│   ├── DocumentListView.swift
│   ├── ReaderView.swift
│   └── AnnotationHUD.swift
├── WebView/
│   └── MarkdownWebView.swift
└── Resources/
    ├── marked.min.js
    ├── katex.min.js
    └── mermaid.min.js
```

---

### 技术分层

```
SwiftUI（文件夹 / 文件列表 + 导航）
    ↓ 点击文件
WKWebView（Markdown 渲染 + 批阅交互层）
    ↓ WKScriptMessageHandler（JS Bridge）
Swift（批注数据 ↔ SwiftData）
```

### 渲染引擎（离线 Bundle）

| 功能 | 库 |
|------|----|
| Markdown 解析 | marked.js（GFM） |
| 数学公式 | KaTeX |
| 流程图 | Mermaid.js |
| 代码高亮 | highlight.js |

所有 JS 资源打包进 App Bundle，完全离线可用。

### 数据层

- **文件本体**：存入 App 沙盒（`Documents/`）
- **元数据**（文件夹层级、文件名、批注）：**SwiftData**

### 导入入口

| 入口 | 实现方式 |
|------|---------|
| "用...打开" | `UTType.text` / `.markdown` Document Type |
| 分享菜单 | Share Extension |
| 系统文件 App | UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace |

---

## UI 设计方向

- 以阅读体验为核心：大量留白、精心排版、沉浸式阅读页
- 文件列表：卡片式布局，层级感清晰
- 阅读页：状态栏自动隐藏，底部工具栏滑入/滑出
- 主题：跟随系统深浅色，不提供手动切换

### Metal / 动画

| 场景 | 动画方案 |
|------|---------|
| 大文件渲染加载 | **SWCharSphere**（字符球体）——将文档关键词散布在球面旋转，与阅读主题高度契合 |
| 文件导入中 | SWInkSmoke（墨水扩散） |
| 冷启动 Splash | SWNeuroNoise 或 SWLiquidMetal |
| 空文件夹占位 | SWStarfield（轻量、优雅） |

**SWCharSphere 来源**：[signerlabs/ShipSwift](https://github.com/signerlabs/ShipSwift/blob/main/ShipSwift/SWPackage/SWAnimation/SWCharSphere.swift)（MIT 协议）。纯 SwiftUI Canvas 实现，无 Metal 依赖，100~300 字符稳定 60fps。加载时用文档提取的关键词作为字符输入。

其余动画组件来自同仓库 `SWPackage/SWAnimation/SWMetal/`，本地学习副本位于 `Metal-demo/ShipSwiftMetal/`。

---

## 批阅功能设计

1. 用户在阅读页长按选中文字
2. JS 监听 `selectionchange`，通过 `WKScriptMessageHandler` 将选中范围传给 Swift
3. Swift 弹出轻量 HUD（文字输入 + Emoji 选择器）
4. 批注数据写入 SwiftData，关联到文档 ID + 字符偏移量
5. 重新打开文档时，JS 层读取批注并在对应位置渲染高亮下划线

---

## 平台要求

| 项 | 要求 |
|----|------|
| 最低 iOS | **iOS 18+** |
| 框架 | SwiftUI、WebKit、SwiftData |
| 动画 | SwiftUI Canvas（SWCharSphere）、Metal Shading Language（其他） |

---

## 路线图

### MVP
- [ ] 项目架构搭建
- [ ] WKWebView 渲染引擎（GFM + KaTeX + Mermaid）
- [ ] 文件导入（Open In / Share Extension / Files App）
- [ ] 多级文件夹管理（SwiftData）
- [ ] 批阅功能（划线 + 文字/Emoji 评注）
- [ ] SWCharSphere 加载动画集成
- [ ] 深浅色主题适配

### Post-MVP
- [ ] Markdown 编辑器（所见即所得）
- [ ] 批注导出（PDF / Markdown）
- [ ] 变现方案（一次性买断）
- [ ] iPad 分屏支持
