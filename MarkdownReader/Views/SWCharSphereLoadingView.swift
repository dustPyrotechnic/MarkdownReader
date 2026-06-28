import SwiftUI

/// 渲染期间的确定性文案层。**不含动画**，作为快照测试目标。
struct RenderingCaption: View {
    var text: String = "正在渲染…"

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// 文档渲染加载动画：背景字符球 + 底部文案。
struct SWCharSphereLoadingView: View {
    let glyphs: [String]

    var body: some View {
        ZStack {
            Color(.systemBackground).opacity(0.95)

            SWCharSphere(
                chars: glyphs.isEmpty ? MarkdownKeywords.fallback : glyphs,
                glyphCount: 180,
                colors: [.primary, .secondary, Color.accentColor],
                background: .clear,
                rotationSpeed: 0.4
            )
            .frame(width: 260, height: 260)

            RenderingCaption()
                .offset(y: 150)
        }
        .ignoresSafeArea()
    }
}

#Preview("加载动画") {
    SWCharSphereLoadingView(glyphs: MarkdownKeywords.glyphs(from: "天地玄黄 宇宙洪荒 SwiftUI"))
}

#Preview("文案层") {
    RenderingCaption()
}
