import Testing
import Foundation
import SwiftData
@testable import MarkdownReader

@MainActor
struct AnnotationStoreTests {
    @Test func 添加批注关联到文档() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let doc = Document(fileName: "a.md", relativePath: "未分类/a.md")
        context.insert(doc)
        let store = AnnotationStore()

        let annotation = store.add(
            selection: SelectionPayload(text: "重点", rangeStart: 4, rangeEnd: 6),
            comment: "记一笔", emoji: "⭐️", to: doc, context: context
        )

        #expect(annotation.comment == "记一笔")
        #expect(annotation.emoji == "⭐️")
        #expect(annotation.rangeStart == 4)
        #expect(annotation.rangeEnd == 6)
        #expect(annotation.document?.id == doc.id)
        #expect(doc.annotations?.count == 1)
    }

    @Test func 删除批注后文档不再持有() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let doc = Document(fileName: "a.md", relativePath: "未分类/a.md")
        context.insert(doc)
        let store = AnnotationStore()
        let annotation = store.add(
            selection: SelectionPayload(text: "x", rangeStart: 0, rangeEnd: 1),
            comment: "c", emoji: nil, to: doc, context: context
        )

        store.delete(annotation, context: context)

        #expect((doc.annotations ?? []).isEmpty)
    }
}
