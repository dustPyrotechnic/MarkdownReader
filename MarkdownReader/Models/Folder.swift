import Foundation
import SwiftData

/// 文档库中的文件夹，支持多级嵌套。
@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    /// 是否为系统默认「未分类」文件夹。
    var isDefault: Bool = false

    // to-one: 父文件夹（子侧，无 @Relationship 注解）
    var parent: Folder?

    // to-many: 子文件夹（父侧，声明 inverse + cascade）
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder]?

    // to-many: 所属文档（父侧，声明 inverse + nullify）
    @Relationship(deleteRule: .nullify, inverse: \Document.folder)
    var documents: [Document]?

    /// 创建文件夹。
    /// - Parameters:
    ///   - name: 文件夹显示名。
    ///   - isDefault: 是否为默认「未分类」文件夹。
    init(name: String, isDefault: Bool = false) {
        self.name = name
        self.isDefault = isDefault
    }
}
