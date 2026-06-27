import SwiftUI

/// 某文件夹下的文档列表（阶段二接入阅读页，本阶段为占位）。
struct DocumentListView: View {
    let folder: Folder

    var body: some View {
        List(folder.documents ?? []) { document in
            Text(document.fileName)
        }
        .navigationTitle(folder.name)
        .overlay {
            if (folder.documents ?? []).isEmpty {
                ContentUnavailableView("暂无文档", systemImage: "doc.text")
            }
        }
    }
}
