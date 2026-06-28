import Foundation

/// 把外部传入的 URL 归类为导入意图（纯函数，便于单测）。
enum ImportURLRouter {
    /// 导入意图。
    enum Intent: Equatable {
        /// 系统本地文件 URL（Open In / 文件 App）。
        case openInPlace(URL)
        /// 自定义 scheme 携带的文件 URL（Share Extension 回传）。
        case shareImport(URL)
    }

    /// 解析传入 URL 的导入意图。
    /// - Parameter url: `onOpenURL` 收到的 URL。
    /// - Returns: 可识别返回对应意图，否则 `nil`。
    static func intent(for url: URL) -> Intent? {
        if url.isFileURL {
            return .openInPlace(url)
        }

        if let fileURL = ShareURLScheme.fileURL(fromImportURL: url) {
            return .shareImport(fileURL)
        }

        return nil
    }
}
