import SwiftUI
import UIKit
import WebKit

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var baseURL: URL?
    var annotations: [[String: Any]] = []
    var onRenderFinished: ((Result<Void, Error>) -> Void)?
    var onSelectionChanged: ((SelectionPayload) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onRenderFinished: onRenderFinished, onSelectionChanged: onSelectionChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "selectionChanged")
        config.userContentController.add(context.coordinator, name: "renderLog")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.isOpaque = false
        webView.backgroundColor = .clear

        context.coordinator.webView = webView
        loadRenderer(in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onRenderFinished = onRenderFinished
        coordinator.onSelectionChanged = onSelectionChanged
        coordinator.annotationsJSON = annotations
        // Skip render if markdown hasn't changed
        guard markdown != coordinator.renderedMarkdown || baseURL != coordinator.renderedBaseURL else { return }
        coordinator.pendingMarkdown = markdown
        coordinator.pendingBaseURL = baseURL
        if coordinator.isLoaded {
            renderMarkdown(markdown, baseURL: baseURL, in: webView, coordinator: coordinator)
        }
    }

    private func loadRenderer(in webView: WKWebView, coordinator: Coordinator) {
        guard let url = Bundle.main.url(forResource: "renderer", withExtension: "html") else { return }
        webView.navigationDelegate = coordinator
        webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: "/"))
    }

    private func renderMarkdown(_ markdown: String, baseURL: URL?, in webView: WKWebView, coordinator: Coordinator) {
        // Use callAsyncJavaScript with parameters to safely pass arbitrary markdown without escaping
        print("[MarkdownWebView] render start length=\(markdown.count)")
        webView.callAsyncJavaScript(
            "return renderMarkdown(markdown, baseURL)",
            arguments: ["markdown": markdown, "baseURL": baseURL?.absoluteString ?? ""],
            in: nil,
            in: .page,
            completionHandler: { result in
                switch result {
                case .success:
                    print("[MarkdownWebView] render success length=\(markdown.count)")
                    coordinator.renderedMarkdown = markdown
                    coordinator.renderedBaseURL = baseURL
                    coordinator.applyAnnotations(in: webView)
                    coordinator.finishRender(.success(()))
                case let .failure(error):
                    print("[MarkdownWebView] render failed length=\(markdown.count) error=\(error)")
                    coordinator.finishRender(.failure(error))
                }
            }
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var isLoaded = false
        var pendingMarkdown = ""
        var pendingBaseURL: URL?
        var renderedMarkdown = ""
        var renderedBaseURL: URL?
        weak var webView: WKWebView?
        var onRenderFinished: ((Result<Void, Error>) -> Void)?
        var onSelectionChanged: ((SelectionPayload) -> Void)?
        var annotationsJSON: [[String: Any]] = []

        init(
            onRenderFinished: ((Result<Void, Error>) -> Void)?,
            onSelectionChanged: ((SelectionPayload) -> Void)?
        ) {
            self.onRenderFinished = onRenderFinished
            self.onSelectionChanged = onSelectionChanged
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            print("[MarkdownWebView] renderer didFinish pendingLength=\(pendingMarkdown.count)")
            guard !pendingMarkdown.isEmpty else { return }
            webView.callAsyncJavaScript(
                "return renderMarkdown(markdown, baseURL)",
                arguments: ["markdown": pendingMarkdown, "baseURL": pendingBaseURL?.absoluteString ?? ""],
                in: nil,
                in: .page,
                completionHandler: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        print("[MarkdownWebView] initial render success length=\(pendingMarkdown.count)")
                        renderedMarkdown = pendingMarkdown
                        renderedBaseURL = pendingBaseURL
                        applyAnnotations(in: webView)
                        finishRender(.success(()))
                    case let .failure(error):
                        print("[MarkdownWebView] initial render failed length=\(pendingMarkdown.count) error=\(error)")
                        finishRender(.failure(error))
                    }
                }
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if ["http", "https"].contains(url.scheme?.lowercased()) {
                print("[MarkdownWebView] open external link \(url.absoluteString)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(url.isFileURL ? .allow : .cancel)
        }

        func finishRender(_ result: Result<Void, Error>) {
            Task { @MainActor in self.onRenderFinished?(result) }
        }

        /// 渲染完成后把当前批注下发给 JS，由 `setAnnotations` 重建高亮。
        /// - Parameter webView: 目标 WebView。
        func applyAnnotations(in webView: WKWebView) {
            guard !annotationsJSON.isEmpty else { return }
            webView.callAsyncJavaScript(
                "return setAnnotations(items)",
                arguments: ["items": annotationsJSON],
                in: nil, in: .page, completionHandler: nil
            )
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "selectionChanged":
                guard let body = message.body as? [String: Any],
                      let payload = SelectionPayload(body: body) else { return }
                Task { @MainActor in self.onSelectionChanged?(payload) }
            case "renderLog":
                logRenderMessage(message.body)
            default:
                return
            }
        }

        private func logRenderMessage(_ body: Any) {
            guard let payload = body as? [String: Any] else {
                print("[MarkdownRenderer][unknown] \(body)")
                return
            }

            let level = payload["level"] as? String ?? "info"
            let message = payload["message"] as? String ?? "(no message)"
            let data = payload["data"] ?? [:]
            print("[MarkdownRenderer][\(level)] \(message) \(data)")
        }
    }
}
