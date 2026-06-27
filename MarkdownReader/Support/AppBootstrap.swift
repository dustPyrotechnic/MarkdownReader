import SwiftData

/// 应用启动时的一次性数据初始化。
enum AppBootstrap {
    /// 保障默认文件夹存在并落盘。
    @MainActor
    static func run(store: FolderStore, context: ModelContext) {
        store.ensureDefaultFolder(context: context)
        try? context.save()
    }
}
