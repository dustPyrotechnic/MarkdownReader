import UIKit
import UniformTypeIdentifiers

/// Share Extension：接收分享的 .md/.txt，经自定义 scheme 唤起主 App 导入。
final class ShareViewController: UIViewController {
    private static let candidateTypeIDs = [
        "net.daringfireball.markdown",
        UTType(filenameExtension: "md")?.identifier,
        UTType(filenameExtension: "markdown")?.identifier,
        UTType.plainText.identifier,
        UTType.text.identifier,
        UTType.fileURL.identifier
    ].compactMap(\.self)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first(where: { provider in
                  Self.candidateTypeIDs.contains { provider.hasItemConformingToTypeIdentifier($0) }
              }),
              let typeID = Self.candidateTypeIDs.first(where: { provider.hasItemConformingToTypeIdentifier($0) })
        else {
            finish()
            return
        }

        provider.loadItem(forTypeIdentifier: typeID) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let url = self.fileURL(from: item),
                   let importURL = ShareURLScheme.makeImportURL(for: url) {
                    self.openMainApp(importURL)
                }
                self.finish()
            }
        }
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8),
           let url = URL(string: text),
           url.isFileURL {
            return url
        }

        return nil
    }

    private func openMainApp(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self

        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
