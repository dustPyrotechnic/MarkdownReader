import Testing
import SwiftData
@testable import MarkdownReader

@MainActor
struct ModelRelationshipTests {
    @Test func 文档归属文件夹的双向关系成立() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "工作")
        let doc = Document(fileName: "周报.md", relativePath: "工作/周报.md")
        context.insert(folder)
        context.insert(doc)
        doc.folder = folder
        try context.save()

        #expect(doc.folder?.name == "工作")
        #expect(folder.documents?.contains(where: { $0.fileName == "周报.md" }) == true)
    }

    @Test func 删除文件夹级联删除其批注但文档仅置空() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "临时")
        let doc = Document(fileName: "a.md", relativePath: "临时/a.md")
        let note = Annotation(rangeStart: 0, rangeEnd: 3, comment: "重点")
        context.insert(folder)
        context.insert(doc)
        context.insert(note)
        doc.folder = folder
        note.document = doc
        try context.save()

        context.delete(folder)
        try context.save()

        let docs = try context.fetch(FetchDescriptor<Document>())
        #expect(docs.count == 1)
        #expect(docs.first?.folder == nil)
    }
}
