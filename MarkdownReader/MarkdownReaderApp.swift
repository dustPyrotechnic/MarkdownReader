import SwiftUI
import SwiftData

@main
struct MarkdownReaderApp: App {
    private let container: ModelContainer
    @State private var folderStore = FolderStore()
    @State private var importer = DocumentImporter()

    init() {
        do {
            container = try ModelContainerFactory.makeAppContainer()
        } catch {
            fatalError("无法创建 ModelContainer：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(folderStore)
                .environment(importer)
        }
        .modelContainer(container)
    }
}
