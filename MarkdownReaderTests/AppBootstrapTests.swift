import Testing
import SwiftData
@testable import MarkdownReader

@MainActor
struct AppBootstrapTests {
    @Test func bootstrap后存在默认文件夹且幂等() throws {
        let container = try TestModelContainer.make()
        let store = FolderStore()

        AppBootstrap.run(store: store, context: container.mainContext)
        AppBootstrap.run(store: store, context: container.mainContext)

        let all = try container.mainContext.fetch(FetchDescriptor<Folder>())
        let defaults = all.filter { $0.isDefault }
        #expect(defaults.count == 1)
    }
}
