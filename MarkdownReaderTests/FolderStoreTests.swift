import Testing
import Foundation
import SwiftData
@testable import MarkdownReader

@MainActor
struct FolderStoreTests {
    @Test func 首次保障会创建唯一的未分类文件夹() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let store = FolderStore()

        let first = store.ensureDefaultFolder(context: context)
        let second = store.ensureDefaultFolder(context: context)

        #expect(first.isDefault)
        #expect(first.name == "未分类")
        #expect(first.id == second.id)
        let allFolders = try context.fetch(FetchDescriptor<Folder>())
        let defaults = allFolders.filter { $0.isDefault }
        #expect(defaults.count == 1)
    }

    @Test func 新建文件夹挂在指定父级下() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let store = FolderStore()
        let parent = store.createFolder(name: "技术", parent: nil, context: context)
        let child = store.createFolder(name: "Swift", parent: parent, context: context)
        try context.save()

        #expect(child.parent?.id == parent.id)
        #expect(parent.children?.contains(where: { $0.id == child.id }) == true)
    }

    @Test func 改名生效() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let store = FolderStore()
        let folder = store.createFolder(name: "旧名", parent: nil, context: context)
        store.rename(folder, to: "新名", context: context)
        #expect(folder.name == "新名")
    }

    @Test func 删除文件夹时其文档回收到未分类() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let store = FolderStore()
        let unfiled = store.ensureDefaultFolder(context: context)
        let folder = store.createFolder(name: "待删", parent: nil, context: context)
        let doc = Document(fileName: "x.md", relativePath: "待删/x.md")
        context.insert(doc)
        doc.folder = folder
        try context.save()

        store.delete(folder, context: context)

        #expect(doc.folder?.id == unfiled.id)
        let allAfter = try context.fetch(FetchDescriptor<Folder>())
        let remaining = allAfter.filter { $0.name == "待删" }
        #expect(remaining.isEmpty)
    }

    @Test func 不允许删除默认文件夹() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let store = FolderStore()
        let unfiled = store.ensureDefaultFolder(context: context)
        store.delete(unfiled, context: context)
        let allFolders = try context.fetch(FetchDescriptor<Folder>())
        let defaults = allFolders.filter { $0.isDefault }
        #expect(defaults.count == 1)
    }
}
