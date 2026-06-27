import SwiftUI
import SwiftData

/// 根级文件夹列表。
struct FolderListView: View {
    @Environment(FolderStore.self) private var folderStore
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.createdAt)
    private var rootFolders: [Folder]

    var body: some View {
        List(rootFolders) { folder in
            NavigationLink(value: folder) {
                Label(folder.name, systemImage: folder.isDefault ? "tray" : "folder")
            }
        }
        .navigationTitle("文档库")
        .toolbar {
            Button("新建文件夹", systemImage: "folder.badge.plus") {
                folderStore.createFolder(name: "新文件夹", parent: nil, context: context)
            }
        }
    }
}
