import Testing
import SwiftUI
@testable import MarkdownReader

@MainActor
struct RenderingCaptionSnapshotTests {
    @Test func 文案层快照稳定() throws {
        try SnapshotTesting.assertSnapshot(
            of: RenderingCaption().padding(),
            size: CGSize(width: 200, height: 60),
            named: "RenderingCaption"
        )
    }
}
