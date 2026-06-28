import Foundation

/// 主 App 与 Share Extension 之间传递「待导入文件 URL」的自定义 scheme 编解码（纯函数）。
enum ShareURLScheme {
    /// 自定义 scheme 名。
    static let scheme = "markdownreader"
    private static let host = "import"
    private static let pathQueryName = "path"

    /// 用文件 URL 构造可唤起主 App 的导入 URL。
    /// - Parameter fileURL: 待导入的本地文件 URL。
    /// - Returns: `markdownreader://import?path=<percent-encoded file url>`。
    static func makeImportURL(for fileURL: URL) -> URL? {
        guard fileURL.isFileURL else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: pathQueryName, value: fileURL.absoluteString)]
        return components.url
    }

    /// 从导入 URL 还原文件 URL。
    /// - Parameter url: 形如 `markdownreader://import?path=...` 的 URL。
    /// - Returns: 还原的文件 URL，非本 scheme 返回 `nil`。
    static func fileURL(fromImportURL url: URL) -> URL? {
        guard url.scheme == scheme,
              url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == pathQueryName })?.value,
              let fileURL = URL(string: value),
              fileURL.isFileURL
        else { return nil }

        return fileURL
    }
}
