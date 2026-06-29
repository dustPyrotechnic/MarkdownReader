import Testing
import Foundation
@testable import MarkdownReader

struct SelectionPayloadTests {
    @Test func 合法body解码成功() {
        let body: [String: Any] = ["text": "选中文字", "rangeStart": 3, "rangeEnd": 7]
        let payload = SelectionPayload(body: body)
        #expect(payload == SelectionPayload(text: "选中文字", rangeStart: 3, rangeEnd: 7))
    }

    @Test func 缺字段返回nil() {
        #expect(SelectionPayload(body: ["text": "x"]) == nil)
        #expect(SelectionPayload(body: ["rangeStart": 0, "rangeEnd": 1]) == nil)
    }

    @Test func 空文字或非法区间返回nil() {
        #expect(SelectionPayload(body: ["text": "", "rangeStart": 0, "rangeEnd": 0]) == nil)
        #expect(SelectionPayload(body: ["text": "x", "rangeStart": 5, "rangeEnd": 5]) == nil)
        #expect(SelectionPayload(body: ["text": "x", "rangeStart": 7, "rangeEnd": 3]) == nil)
    }
}
