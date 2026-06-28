import Testing
import Foundation
@testable import MarkdownReader

struct ShareURLSchemeTests {
    @Test func 构造再解析得到原文件URL() throws {
        let fileURL = URL(fileURLWithPath: "/private/tmp/我的 笔记.md")
        let importURL = try #require(ShareURLScheme.makeImportURL(for: fileURL))
        #expect(importURL.scheme == "markdownreader")
        #expect(ShareURLScheme.fileURL(fromImportURL: importURL) == fileURL)
    }

    @Test func 非本scheme解析返回nil() {
        #expect(ShareURLScheme.fileURL(fromImportURL: URL(string: "https://x.com")!) == nil)
    }
}
