import SwiftUI
import SwiftData

/// 选区批注录入 HUD：文字 + Emoji，保存写入 SwiftData。
struct AnnotationHUD: View {
    let selection: SelectionPayload
    let document: Document
    @Environment(AnnotationStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var selectedEmoji: String?

    private let emojis = ["⭐️", "❓", "💡", "⚠️", "❤️", "👍", "📌", "🔥"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("批注").font(.headline)

            Text("“\(selection.text.prefix(60))”")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField("添加评注…", text: $comment, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            EmojiPickerRow(emojis: emojis, selection: $selectedEmoji)

            Button("保存批注") { save() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isEmpty)
        }
        .padding()
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }

    private var isEmpty: Bool {
        comment.trimmingCharacters(in: .whitespaces).isEmpty && selectedEmoji == nil
    }

    private func save() {
        store.add(selection: selection, comment: comment, emoji: selectedEmoji, to: document, context: context)
        try? context.save()
        dismiss()
    }
}

/// Emoji 选择行（独立 View，不用计算属性拆视图）。
private struct EmojiPickerRow: View {
    let emojis: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { selection = selection == emoji ? nil : emoji }
                        .font(.title2)
                        .padding(6)
                        .background(selection == emoji ? Color.accentColor.opacity(0.2) : .clear)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }
}
