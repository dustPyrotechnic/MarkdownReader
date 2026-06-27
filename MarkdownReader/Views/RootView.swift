import SwiftUI
import SwiftData

/// 应用根视图，承载导航栈。
struct RootView: View {
    @Environment(FolderStore.self) private var folderStore
    @Environment(\.modelContext) private var context

    @State private var path = NavigationPath()
    @State private var didOpenDebugTestDocument = false

    var body: some View {
        NavigationStack(path: $path) {
            FolderListView()
                .navigationDestination(for: Folder.self) { folder in
                    DocumentListView(folder: folder)
                }
                .navigationDestination(for: Document.self) { document in
                    ReaderView(document: document)
                }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            AppBootstrap.run(store: folderStore, context: context)
#if DEBUG
            openRendererTestDocumentIfNeeded()
#endif
        }
    }

#if DEBUG
    private func openRendererTestDocumentIfNeeded() {
        guard !didOpenDebugTestDocument else { return }
        let folders = (try? context.fetch(FetchDescriptor<Folder>())) ?? []
        guard let folder = folders.first(where: { $0.name == FolderStore.rendererTestFolderName }) else { return }
        let documents = (folder.documents ?? []).sorted(by: { $0.fileName < $1.fileName })
        guard let document = documents.first(where: { $0.fileName == FolderStore.initialRendererTestDocumentFileName }) ?? documents.first else { return }

        didOpenDebugTestDocument = true
        path.append(folder)
        path.append(document)
    }
#endif
}
