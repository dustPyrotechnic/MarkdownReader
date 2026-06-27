import SwiftData
@testable import MarkdownReader

/// 仅用于单元测试的内存容器工厂，互不污染、用完即弃。
enum TestModelContainer {
    /// 构建一个纯内存的 `ModelContainer`。
    static func make() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: ModelContainerFactory.schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: ModelContainerFactory.schema, configurations: configuration)
    }
}
