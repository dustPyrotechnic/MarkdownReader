import Foundation
import SwiftData
import Observation

/// 文件导入业务：把外部文件拷入沙盒并登记 `Document` 记录。
@MainActor
@Observable
final class DocumentImporter {
    /// 可恢复的导入错误。
    enum ImportError: Error, Equatable {
        case unsupportedType
        case unreadableSource
        case copyFailed
    }

    /// 受支持的 Markdown 文本扩展名（小写）。
    static let supportedExtensions: Set<String> = ["md", "markdown", "txt"]

    /// 是否正在导入（驱动 UI 加载态）。
    private(set) var isImporting = false
    /// 最近一次失败的本地化描述。
    var lastError: String?

    private let documentsBaseURL: URL
    private let fileManager: FileManager

    /// - Parameters:
    ///   - documentsBaseURL: 沙盒文档根目录；生产用 `URL.documentsDirectory`，测试注入临时目录。
    ///   - fileManager: 文件管理器（可注入）。
    init(documentsBaseURL: URL = URL.documentsDirectory, fileManager: FileManager = .default) {
        self.documentsBaseURL = documentsBaseURL
        self.fileManager = fileManager
    }

    /// 判断文件名扩展名是否受支持（大小写不敏感）。
    /// - Parameter fileName: 含扩展名的文件名。
    /// - Returns: 受支持返回 `true`。
    static func isSupported(fileName: String) -> Bool {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    /// 在目标目录内为 `fileName` 求一个不冲突的文件名；重名时按 `name-1.ext`、`name-2.ext` 递增。
    /// - Parameters:
    ///   - fileName: 期望文件名（含扩展名）。
    ///   - directory: 目标目录。
    ///   - fileManager: 文件管理器（可注入）。
    /// - Returns: 该目录下尚未占用的文件名。
    static func uniqueFileName(for fileName: String, in directory: URL, fileManager: FileManager) -> String {
        let url = URL(fileURLWithPath: fileName)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var candidate = fileName
        var index = 1

        while fileManager.fileExists(atPath: directory.appending(path: candidate).path) {
            candidate = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            index += 1
        }

        return candidate
    }

    /// 把外部文件拷入沙盒目标文件夹并登记 `Document`。
    /// - Parameters:
    ///   - sourceURL: 外部源文件（可能是安全作用域 URL）。
    ///   - folder: 目标文件夹。
    ///   - context: SwiftData 上下文。
    /// - Returns: 新建的 `Document`。
    /// - Throws: `ImportError`。
    @discardableResult
    func importFile(from sourceURL: URL, into folder: Folder, context: ModelContext) throws -> Document {
        guard Self.isSupported(fileName: sourceURL.lastPathComponent) else {
            throw ImportError.unsupportedType
        }
        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw ImportError.unreadableSource
        }

        let destDir = documentsBaseURL.appending(path: folder.name)
        do {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
        } catch {
            throw ImportError.copyFailed
        }

        let fileName = Self.uniqueFileName(
            for: sourceURL.lastPathComponent,
            in: destDir,
            fileManager: fileManager
        )
        let destURL = destDir.appending(path: fileName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            throw ImportError.copyFailed
        }

        let relativePath = "\(folder.name)/\(fileName)"
        let document = Document(fileName: fileName, relativePath: relativePath)
        context.insert(document)
        document.folder = folder
        return document
    }

    /// 安全作用域包装版导入：先申请访问权限再调用 `importFile`，并维护 `isImporting`/`lastError`。
    /// - Returns: 成功返回 `Document`，失败返回 `nil`（错误写入 `lastError`）。
    @discardableResult
    func importSecurityScopedFile(from sourceURL: URL, into folder: Folder, context: ModelContext) -> Document? {
        isImporting = true
        lastError = nil
        defer { isImporting = false }

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try importFile(from: sourceURL, into: folder, context: context)
        } catch {
            lastError = (error as? ImportError).map(Self.message(for:)) ?? error.localizedDescription
            return nil
        }
    }

    private static func message(for error: ImportError) -> String {
        switch error {
        case .unsupportedType:
            "不支持的文件类型，仅支持 .md / .markdown / .txt"
        case .unreadableSource:
            "无法读取来源文件"
        case .copyFailed:
            "文件拷贝失败"
        }
    }
}
