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
                annotations: annotationPayloads,
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

    /// 把文档批注转为下发给 JS 的纯字典数组（数据转换，非拆视图）。
    private var annotationPayloads: [[String: Any]] {
        (document.annotations ?? []).map { [
            "rangeStart": $0.rangeStart,
            "rangeEnd": $0.rangeEnd,
            "comment": $0.comment,
            "emoji": $0.emoji ?? ""
        ] }
    }
}
