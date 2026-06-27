import SwiftUI

struct ReaderView: View {
    let document: Document
    @State private var markdown = ""
    @State private var isLoading = true
    @State private var selectedText = ""
    @State private var showAnnotationHUD = false

    var body: some View {
        ZStack {
            MarkdownWebView(
                markdown: markdown,
                baseURL: documentURL.deletingLastPathComponent(),
                onRenderFinished: { result in
                    isLoading = false
                    if case let .failure(error) = result {
                        print("[ReaderView] render failed error=\(error)")
                    }
                }
            ) { text in
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
        isLoading = true
        markdown = (try? String(contentsOf: documentURL, encoding: .utf8)) ?? "# 文件读取失败"
    }

    private var documentURL: URL {
        URL.documentsDirectory.appending(path: document.relativePath)
    }
}
