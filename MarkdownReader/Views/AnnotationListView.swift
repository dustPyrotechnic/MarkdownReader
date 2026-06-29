import SwiftUI
import SwiftData

/// 文档批注列表：查看与滑动删除。
struct AnnotationListView: View {
    let document: Document
    @Environment(AnnotationStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var annotations: [Annotation] {
        (document.annotations ?? []).sorted { $0.rangeStart < $1.rangeStart }
    }

    var body: some View {
        NavigationStack {
            List {
                if annotations.isEmpty {
                    ContentUnavailableView("暂无批注", systemImage: "highlighter")
                } else {
                    ForEach(annotations) { annotation in
                        AnnotationRow(annotation: annotation)
                    }
                    .onDelete(perform: deleteAt)
                }
            }
            .navigationTitle("批注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets { store.delete(annotations[index], context: context) }
        try? context.save()
    }
}

/// 单条批注行。
private struct AnnotationRow: View {
    let annotation: Annotation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let emoji = annotation.emoji { Text(emoji) }
                Text(annotation.comment.isEmpty ? "（无评注）" : annotation.comment)
                    .font(.body)
            }
            Text("区间 \(annotation.rangeStart)–\(annotation.rangeEnd)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
