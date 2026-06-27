import Foundation
import SwiftData
import Observation

/// 文件夹业务逻辑：默认文件夹保障、增删改、文档移动。
@MainActor
@Observable
final class FolderStore {
    /// 系统默认文件夹名称。
    static let defaultFolderName = "未分类"

#if DEBUG
    static let rendererTestFolderName = "MarkdownRendererTestDocs"
    static let initialRendererTestDocumentFileName = "09-frontmatter-toc-footnotes.md"

    static let rendererTestDocumentFileNames = [
        "01-basic-blocks.md",
        "02-inline-formatting.md",
        "03-lists-quotes.md",
        "04-code-fences.md",
        "05-tables.md",
        "06-links-images.md",
        "07-html-security.md",
        "08-edge-unicode.md",
        "09-frontmatter-toc-footnotes.md",
        "10-combined-stress.md"
    ]

    private static let rendererTestAssetFileNames = [
        "sample-image.svg",
        "sample-image-title.svg",
        "sample-linked-image.svg"
    ]
#endif

    /// 取得（必要时创建）唯一的默认「未分类」文件夹。
    /// - Parameter context: SwiftData 上下文。
    /// - Returns: 默认文件夹。
    @discardableResult
    func ensureDefaultFolder(context: ModelContext) -> Folder {
        let all = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
        if let existing = all.first(where: { $0.isDefault }) {
            return existing
        }
        let folder = Folder(name: Self.defaultFolderName, isDefault: true)
        context.insert(folder)
        return folder
    }

    /// 新建文件夹。
    /// - Returns: 新建的文件夹。
    @discardableResult
    func createFolder(name: String, parent: Folder?, context: ModelContext) -> Folder {
        let folder = Folder(name: name)
        context.insert(folder)
        folder.parent = parent
        return folder
    }

    /// 重命名文件夹。
    func rename(_ folder: Folder, to newName: String, context: ModelContext) {
        folder.name = newName
    }

    /// 把文档移动到目标文件夹。
    func move(_ document: Document, to folder: Folder, context: ModelContext) {
        document.folder = folder
    }

    /// 删除文件夹；默认文件夹不可删，其下文档回收到「未分类」。
    func delete(_ folder: Folder, context: ModelContext) {
        guard !folder.isDefault else { return }
        let unfiled = ensureDefaultFolder(context: context)
        for document in folder.documents ?? [] {
            document.folder = unfiled
        }
        context.delete(folder)
    }

#if DEBUG
    /// DEBUG 专用：将 Bundle 内的渲染测试文档注入到独立测试文件夹。
    func seedRendererTestDocumentsIfNeeded(context: ModelContext) {
        let folder = rendererTestFolder(context: context)
        let existingNames = Set((folder.documents ?? []).map(\.fileName))
        let destDir = URL.documentsDirectory.appending(path: Self.rendererTestFolderName)

        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            return
        }

        for fileName in Self.rendererTestDocumentFileNames {
            guard let sourceURL = rendererTestResourceURL(fileName: fileName) else { continue }

            let destURL = destDir.appending(path: fileName)
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                continue
            }

            guard !existingNames.contains(fileName) else { continue }

            let doc = Document(
                fileName: fileName,
                relativePath: "\(Self.rendererTestFolderName)/\(fileName)"
            )
            doc.folder = folder
            context.insert(doc)
        }

        for fileName in Self.rendererTestAssetFileNames {
            guard let sourceURL = rendererTestResourceURL(fileName: fileName) else { continue }

            let destURL = destDir.appending(path: fileName)
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                continue
            }
        }
    }

    func rendererTestFolder(context: ModelContext) -> Folder {
        let allFolders = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
        if let existing = allFolders.first(where: { $0.name == Self.rendererTestFolderName }) {
            return existing
        }

        let folder = Folder(name: Self.rendererTestFolderName)
        context.insert(folder)
        return folder
    }

    private func rendererTestResourceURL(fileName: String) -> URL? {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        return Bundle.main.url(
            forResource: baseName,
            withExtension: fileExtension,
            subdirectory: Self.rendererTestFolderName
        ) ?? Bundle.main.url(forResource: baseName, withExtension: fileExtension)
    }
#endif
}
