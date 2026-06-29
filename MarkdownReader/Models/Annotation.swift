import Foundation
import SwiftData

/// 针对文档某一字符区间的批注（阶段五启用 UI）。
@Model
final class Annotation {
    var id: UUID = UUID()
    var rangeStart: Int = 0
    var rangeEnd: Int = 0
    var comment: String = ""
    var emoji: String?
    var createdAt: Date = Date.now

    var document: Document?

    /// 创建批注。
    /// - Parameters:
    ///   - rangeStart: 选区起始字符偏移。
    ///   - rangeEnd: 选区结束字符偏移。
    ///   - comment: 文字评注。
    ///   - emoji: 可选 Emoji。
    init(rangeStart: Int, rangeEnd: Int, comment: String, emoji: String? = nil) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.comment = comment
        self.emoji = emoji
    }
}
