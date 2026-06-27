import Foundation
import SwiftData
import Observation

/// 文件夹业务逻辑：默认文件夹保障、增删改、文档移动。
@MainActor
@Observable
final class FolderStore {
    /// 系统默认文件夹名称。
    static let defaultFolderName = "未分类"

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
    /// DEBUG 专用：将 Bundle 内的 test-render.md 注入到「未分类」文件夹。
    /// 已存在同名文档时跳过，避免重复。
    func seedTestDocumentIfNeeded(context: ModelContext) {
        let inbox = ensureDefaultFolder(context: context)
        let existingNames = (inbox.documents ?? []).map(\.fileName)
        guard !existingNames.contains("test-render.md") else { return }

        guard let bundleURL = Bundle.main.url(forResource: "test-render", withExtension: "md") else { return }

        let destDir = URL.documentsDirectory.appending(path: Self.defaultFolderName)
        let destURL = destDir.appending(path: "test-render.md")
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: bundleURL, to: destURL)
        } catch {
            return
        }

        let doc = Document(fileName: "test-render.md", relativePath: "\(Self.defaultFolderName)/test-render.md")
        doc.folder = inbox
        context.insert(doc)
    }
#endif
}
