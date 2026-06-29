import Foundation
import SwiftData
import Observation

/// 批注业务：把选区评注写入 SwiftData 并维护与 `Document` 的关系。
@MainActor
@Observable
final class AnnotationStore {
    /// 新增批注并关联到文档。
    /// - Parameters:
    ///   - selection: 选区载荷（提供字符偏移）。
    ///   - comment: 文字评注，可为空。
    ///   - emoji: 可选 Emoji。
    ///   - document: 目标文档。
    ///   - context: SwiftData 上下文。
    /// - Returns: 新建的 `Annotation`。
    @discardableResult
    func add(
        selection: SelectionPayload,
        comment: String,
        emoji: String?,
        to document: Document,
        context: ModelContext
    ) -> Annotation {
        let annotation = Annotation(
            rangeStart: selection.rangeStart,
            rangeEnd: selection.rangeEnd,
            comment: comment,
            emoji: emoji
        )
        context.insert(annotation)
        annotation.document = document
        return annotation
    }

    /// 删除批注。
    /// - Parameters:
    ///   - annotation: 待删除批注。
    ///   - context: SwiftData 上下文。
    func delete(_ annotation: Annotation, context: ModelContext) {
        // 先断开反向关系，确保 `document.annotations` 即时刷新（删除标记不会立即同步反向数组）。
        annotation.document = nil
        context.delete(annotation)
    }
}
