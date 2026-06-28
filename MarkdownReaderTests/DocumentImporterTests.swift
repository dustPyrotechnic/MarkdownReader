import Testing
import Foundation
import SwiftData
@testable import MarkdownReader

@MainActor
struct DocumentImporterTests {
    @Test func 支持的扩展名通过校验() {
        #expect(DocumentImporter.isSupported(fileName: "note.md"))
        #expect(DocumentImporter.isSupported(fileName: "note.markdown"))
        #expect(DocumentImporter.isSupported(fileName: "note.txt"))
        #expect(DocumentImporter.isSupported(fileName: "NOTE.MD"))
    }

    @Test func 不支持的扩展名被拒() {
        #expect(!DocumentImporter.isSupported(fileName: "a.pdf"))
        #expect(!DocumentImporter.isSupported(fileName: "noext"))
    }

    @Test func 目录为空时文件名原样返回() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let name = DocumentImporter.uniqueFileName(for: "a.md", in: dir, fileManager: .default)
        #expect(name == "a.md")
    }

    @Test func 重名时追加序号() {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(atPath: dir.appending(path: "a.md").path, contents: nil)
        FileManager.default.createFile(atPath: dir.appending(path: "a-1.md").path, contents: nil)

        let name = DocumentImporter.uniqueFileName(for: "a.md", in: dir, fileManager: .default)
        #expect(name == "a-2.md")
    }

    @Test func 导入后文件落沙盒且生成Document记录() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)

        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        let source = makeSourceFile(name: "hello.md", body: "# Hi")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let doc = try importer.importFile(from: source, into: folder, context: context)

        #expect(doc.fileName == "hello.md")
        #expect(doc.relativePath == "技术/hello.md")
        #expect(doc.folder?.id == folder.id)
        let copied = sandbox.appending(path: "技术/hello.md")
        #expect(FileManager.default.fileExists(atPath: copied.path))
        #expect((try? String(contentsOf: copied, encoding: .utf8)) == "# Hi")
    }

    @Test func 同名导入两次不覆盖而是去重() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)
        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        let firstSource = makeSourceFile(name: "a.md", body: "1")
        let secondSource = makeSourceFile(name: "a.md", body: "2")
        defer {
            try? FileManager.default.removeItem(at: firstSource.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: secondSource.deletingLastPathComponent())
        }

        _ = try importer.importFile(from: firstSource, into: folder, context: context)
        let second = try importer.importFile(from: secondSource, into: folder, context: context)

        #expect(second.fileName == "a-1.md")
        #expect(second.relativePath == "技术/a-1.md")
        let copied = sandbox.appending(path: "技术/a-1.md")
        #expect((try? String(contentsOf: copied, encoding: .utf8)) == "2")
    }

    @Test func 不支持的类型抛错且不落盘() throws {
        let container = try TestModelContainer.make()
        let context = container.mainContext
        let folder = Folder(name: "技术")
        context.insert(folder)
        let sandbox = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let importer = DocumentImporter(documentsBaseURL: sandbox, fileManager: .default)

        let source = makeSourceFile(name: "a.pdf", body: "x")
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        #expect(throws: DocumentImporter.ImportError.unsupportedType) {
            try importer.importFile(from: source, into: folder, context: context)
        }
        #expect(!FileManager.default.fileExists(atPath: sandbox.appending(path: "技术/a.pdf").path))
    }

    /// 造一个临时「外部源文件」。
    private func makeSourceFile(name: String, body: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: name)
        try? body.data(using: .utf8)?.write(to: url)
        return url
    }
}
