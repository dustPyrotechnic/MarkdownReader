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
}
