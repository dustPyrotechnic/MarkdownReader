import SwiftUI
import WebKit

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var onSelectionChanged: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "selectionChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = .clear

        context.coordinator.webView = webView
        loadRenderer(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingMarkdown = markdown
        if context.coordinator.isLoaded {
            renderMarkdown(markdown, in: webView)
        }
    }

    private func loadRenderer(in webView: WKWebView, coordinator: Coordinator) {
        guard let url = Bundle.main.url(forResource: "renderer", withExtension: "html") else { return }
        webView.navigationDelegate = coordinator
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func renderMarkdown(_ markdown: String, in webView: WKWebView) {
        let escaped = markdown
            .replacing("\\", with: "\\\\")
            .replacing("`", with: "\\`")
        webView.evaluateJavaScript("renderMarkdown(`\(escaped)`)", completionHandler: nil)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var isLoaded = false
        var pendingMarkdown = ""
        weak var webView: WKWebView?
        var onSelectionChanged: ((String) -> Void)?

        init(onSelectionChanged: ((String) -> Void)?) {
            self.onSelectionChanged = onSelectionChanged
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let escaped = pendingMarkdown
                .replacing("\\", with: "\\\\")
                .replacing("`", with: "\\`")
            webView.evaluateJavaScript("renderMarkdown(`\(escaped)`)", completionHandler: nil)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "selectionChanged",
                  let body = message.body as? [String: Any],
                  let text = body["text"] as? String else { return }
            Task { @MainActor in self.onSelectionChanged?(text) }
        }
    }
}
