import SwiftUI

struct ReaderView: View {
    let document: Document
    @State private var markdown = ""
    @State private var isLoading = true
    @State private var selectedText = ""
    @State private var showAnnotationHUD = false

    var body: some View {
        ZStack {
            MarkdownWebView(markdown: markdown) { text in
                selectedText = text
                showAnnotationHUD = true
            }
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                ProgressView("正在渲染…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.95))
            }
        }
        .navigationTitle(document.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMarkdown() }
    }

    private func loadMarkdown() async {
        let url = URL.documentsDirectory.appending(path: document.relativePath)
        markdown = (try? String(contentsOf: url, encoding: .utf8)) ?? "# 文件读取失败"
        isLoading = false
    }
}
