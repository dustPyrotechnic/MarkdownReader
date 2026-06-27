import SwiftUI

struct DocumentListView: View {
    let folder: Folder

    var body: some View {
        List(folder.documents ?? []) { document in
            NavigationLink(value: document) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.fileName)
                        .bold()
                    Text(document.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationDestination(for: Document.self) { doc in
            ReaderView(document: doc)
        }
        .overlay {
            if (folder.documents ?? []).isEmpty {
                ContentUnavailableView("暂无文档", systemImage: "doc.text")
            }
        }
    }
}
