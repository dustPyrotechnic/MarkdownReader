import Testing
@testable import MarkdownReader

struct MarkdownKeywordsTests {
    @Test func 空文本回退到默认字形() {
        #expect(MarkdownKeywords.glyphs(from: "") == ["M", "D"])
        #expect(MarkdownKeywords.glyphs(from: "   \n\t ") == ["M", "D"])
    }

    @Test func 按出现顺序去重单字符() {
        #expect(MarkdownKeywords.glyphs(from: "abca") == ["a", "b", "c"])
    }

    @Test func 过滤标点空白与Markdown标记() {
        // "# 标题\n**粗**" 去掉 #、空白、换行、*，留下中文字
        #expect(MarkdownKeywords.glyphs(from: "# 标题\n**粗**") == ["标", "题", "粗"])
    }

    @Test func 受数量上限约束() {
        let long = String(repeating: "天地玄黄宇宙洪荒", count: 50)
        #expect(MarkdownKeywords.glyphs(from: long, maxCount: 3).count == 3)
    }
}
