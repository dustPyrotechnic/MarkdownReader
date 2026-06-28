import Testing
import Foundation
@testable import MarkdownReader

struct ImportURLRouterTests {
    @Test func 本地文件URL解析为openInPlace() {
        let url = URL(fileURLWithPath: "/tmp/a.md")
        #expect(ImportURLRouter.intent(for: url) == .openInPlace(url))
    }

    @Test func 自定义scheme解析为shareImport() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/b.md")
        let scheme = try #require(ShareURLScheme.makeImportURL(for: fileURL))
        #expect(ImportURLRouter.intent(for: scheme) == .shareImport(fileURL))
    }

    @Test func 无法识别的URL返回nil() throws {
        let url = try #require(URL(string: "https://example.com"))
        #expect(ImportURLRouter.intent(for: url) == nil)
    }
}
