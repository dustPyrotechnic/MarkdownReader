import SwiftUI

/// 应用根视图，承载导航栈。
struct RootView: View {
    var body: some View {
        NavigationStack {
            FolderListView()
        }
    }
}
