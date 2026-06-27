import Testing
import SwiftData
@testable import MarkdownReader

@MainActor
struct SmokeTests {
    @Test func 内存容器可创建且初始为空() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folders = try context.fetch(FetchDescriptor<Folder>())
        #expect(folders.isEmpty)
    }
}
