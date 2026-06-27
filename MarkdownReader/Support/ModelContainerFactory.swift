import SwiftData

/// 集中描述 App 所有 @Model 类型，供正式容器与测试容器复用。
enum ModelContainerFactory {
    /// 应用涉及的全部持久化模型。
    static let schema = Schema([Folder.self, Document.self, Annotation.self])

    /// 构建落盘的正式容器。
    /// - Returns: 配置完成的 `ModelContainer`。
    static func makeAppContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
