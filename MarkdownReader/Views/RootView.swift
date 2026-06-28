import SwiftUI
import SwiftData

/// 应用根视图，承载导航栈。
struct RootView: View {
    @Environment(FolderStore.self) private var folderStore
    @Environment(DocumentImporter.self) private var importer
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
        .onOpenURL { url in
            handleIncoming(url)
        }
        .task {
            AppBootstrap.run(store: folderStore, context: context)
#if DEBUG
            openRendererTestDocumentIfNeeded()
#endif
        }
    }

    /// 处理外部传入的导入 URL：拷入「未分类」并跳转到阅读页。
    private func handleIncoming(_ url: URL) {
        guard let intent = ImportURLRouter.intent(for: url) else { return }

        let fileURL = switch intent {
        case .openInPlace(let url):
            url
        case .shareImport(let url):
            url
        }

        let unfiled = folderStore.ensureDefaultFolder(context: context)
        guard let document = importer.importSecurityScopedFile(from: fileURL, into: unfiled, context: context) else {
            return
        }

        try? context.save()
        path = NavigationPath()
        path.append(unfiled)
        path.append(document)
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
