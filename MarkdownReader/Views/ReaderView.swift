import SwiftUI

struct ReaderView: View {
    let document: Document
    @State private var markdown = ""
    @State private var isLoading = true
    @State private var currentSelection: SelectionPayload?
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
            ) { payload in
                currentSelection = payload
                showAnnotationHUD = true
            }
            .ignoresSafeArea(edges: .bottom)

            if isLoading {
                SWCharSphereLoadingView(glyphs: MarkdownKeywords.glyphs(from: markdown))
            }

        }
        .sheet(isPresented: $showAnnotationHUD) {
            if let currentSelection {
                AnnotationHUD(selection: currentSelection, document: document)
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
