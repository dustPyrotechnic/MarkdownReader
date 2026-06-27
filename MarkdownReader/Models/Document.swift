import Foundation
import SwiftData

/// 一个 Markdown 文档的元数据（文件本体存沙盒，阶段三接入）。
@Model
final class Document {
    var id: UUID = UUID()
    var fileName: String = ""
    /// 相对 `Documents/` 的存储路径。
    var relativePath: String = ""
    var createdAt: Date = Date.now

    // to-one: 所属文件夹（子侧，无 @Relationship 注解）
    var folder: Folder?

    // to-many: 批注（父侧，声明 inverse + cascade）
    @Relationship(deleteRule: .cascade, inverse: \Annotation.document)
    var annotations: [Annotation]?

    /// 创建文档元数据。
    /// - Parameters:
    ///   - fileName: 含扩展名的文件名。
    ///   - relativePath: 相对 Documents 目录的路径。
    init(fileName: String, relativePath: String) {
        self.fileName = fileName
        self.relativePath = relativePath
    }
}
