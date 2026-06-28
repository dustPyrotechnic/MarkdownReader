import Testing
import SwiftUI
import Foundation

/// 极简原生快照工具：用 `ImageRenderer` 把视图渲染成 PNG。
/// 参考图缺失时录制（测试失败并提示），存在时逐字节比对。
@MainActor
enum SnapshotTesting {
    /// 断言视图与已录制参考图一致；缺参考图则录制并使测试失败。
    static func assertSnapshot(
        of view: some View,
        size: CGSize,
        named name: String,
        filePath: String = #filePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else {
            Issue.record("无法渲染视图为 PNG", sourceLocation: sourceLocation)
            return
        }

        let dir = URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let reference = dir.appendingPathComponent("\(name).png")

        guard FileManager.default.fileExists(atPath: reference.path) else {
            try data.write(to: reference)
            Issue.record(
                "已录制参考快照：\(reference.path)。请确认后重跑测试。",
                sourceLocation: sourceLocation
            )
            return
        }

        let expected = try Data(contentsOf: reference)
        #expect(data == expected, "快照与参考图不一致：\(name)", sourceLocation: sourceLocation)
    }
}
