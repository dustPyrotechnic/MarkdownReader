import Foundation

/// 从 Markdown 文本提取用于加载动画字符球的字形集合。
///
/// 逐字符扫描，剔除空白、标点与符号（覆盖 `# * ` > - [ ]` 等 Markdown 标记），
/// 按首次出现顺序去重，并截断到 `maxCount`。空结果回退到 ``fallback``。
enum MarkdownKeywords {
    /// 文本为空或全是被过滤字符时使用的兜底字形。
    static let fallback = ["M", "D"]

    /// 提取字形数组。
    /// - Parameters:
    ///   - markdown: 原始 Markdown 文本。
    ///   - maxCount: 返回字形数量上限，默认 60。
    /// - Returns: 去重后的单字符字符串数组；为空时返回 ``fallback``。
    static func glyphs(from markdown: String, maxCount: Int = 60) -> [String] {
        var seen = Set<Character>()
        var result: [String] = []
        for character in markdown {
            if character.isWhitespace || character.isPunctuation || character.isSymbol { continue }
            guard seen.insert(character).inserted else { continue }
            result.append(String(character))
            if result.count >= maxCount { break }
        }
        return result.isEmpty ? fallback : result
    }
}
