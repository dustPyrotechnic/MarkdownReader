import Foundation

/// JS `selectionChanged` 回传的选区载荷（纯值类型，便于单测）。
struct SelectionPayload: Equatable {
    /// 选中的可见文本。
    let text: String
    /// 选区起始字符偏移（相对内容根）。
    let rangeStart: Int
    /// 选区结束字符偏移（相对内容根，开区间上界）。
    let rangeEnd: Int

    /// 从 `WKScriptMessage.body` 字典解码；字段缺失、文本为空或区间非法返回 `nil`。
    /// - Parameter body: message body 字典。
    init?(body: [String: Any]) {
        guard let text = body["text"] as? String, !text.isEmpty,
              let start = body["rangeStart"] as? Int,
              let end = body["rangeEnd"] as? Int,
              start < end
        else { return nil }
        self.text = text
        self.rangeStart = start
        self.rangeEnd = end
    }

    /// 直接构造（测试用）。
    init(text: String, rangeStart: Int, rangeEnd: Int) {
        self.text = text
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
    }
}
