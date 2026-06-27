# Swift / SwiftUI / SwiftData 详细编码规范

> 本文是 `CLAUDE.md` 中"编码规范"一节的完整细则。`CLAUDE.md` 只保留高频要点，需要逐条核对时查阅本文。

## Swift

- 优先 Swift 原生写法而非 Foundation：用 `replacing("hello", with: "world")` 而非 `replacingOccurrences(of:with:)`。
- 优先现代 Foundation API：用 `URL.documentsDirectory` 取文档目录，用 `appending(path:)` 拼接路径。
- 禁止 C 风格数字格式化（`String(format: "%.2f", ...)`），改用 `Text(value, format: .number.precision(.fractionLength(2)))`。
- 优先静态成员查找：`.circle` 而非 `Circle()`，`.borderedProminent` 而非 `BorderedProminentButtonStyle()`。
- 禁止旧式 GCD（`DispatchQueue.main.async()`），统一用现代 Swift 并发。
- 基于用户输入的文本过滤必须用 `localizedStandardContains()`，不用 `contains()`。
- 避免强解包与强制 `try`，除非不可恢复。

## SwiftUI

- 用 `foregroundStyle()` 而非 `foregroundColor()`。
- 用 `clipShape(.rect(cornerRadius:))` 而非 `cornerRadius()`。
- 用 `Tab` API 而非 `tabItem()`。
- 禁止 `ObservableObject`，统一用 `@Observable`。
- `onChange()` 禁用单参版本，只用双参或零参版本。
- 仅当需要点击位置/次数时用 `onTapGesture()`，其余一律用 `Button`。
- 用 `Task.sleep(for:)` 而非 `Task.sleep(nanoseconds:)`。
- 不用 `UIScreen.main.bounds` 读可用尺寸。
- 不用计算属性拆分视图，拆成独立的 `View` struct。
- 不写死字号，优先 Dynamic Type。
- 用 `NavigationStack` + `navigationDestination(for:)`，不用 `NavigationView`。
- 图标按钮必须带文字：`Button("Tap me", systemImage: "plus", action: myButtonAction)`。
- 渲染 SwiftUI 视图为图片用 `ImageRenderer`，不用 `UIGraphicsImageRenderer`。
- 加粗用 `bold()`，非必要不用 `fontWeight(.bold)`。
- 有更新替代（`containerRelativeFrame()`、`visualEffect()`）时不用 `GeometryReader`。
- 对 `enumerated` 序列做 `ForEach` 时不要先转数组：`ForEach(x.enumerated(), id: \.element.id)`。
- 隐藏滚动指示器用 `.scrollIndicators(.hidden)`，不用初始化器的 `showsIndicators: false`。
- 视图逻辑放进 view model 等可测试的位置。
- 非必要不用 `AnyView`。
- 非必要不写死 padding / stack spacing。
- SwiftUI 代码里不用 UIKit 颜色。

## SwiftData（CloudKit 模式下）

- 禁用 `@Attribute(.unique)`。
- 模型属性必须有默认值或标记为 optional。
- 所有关系必须 optional。

## 项目结构

- 目录按功能划分，命名严格统一。
- 不同类型拆分到不同 Swift 文件，不在单文件堆多个 struct/class/enum。
- 为核心逻辑写单元测试；仅当无法写单测时才写 UI 测试。
- 按需补充代码注释与文档注释。
- 密钥（API key 等）绝不入库。

## PR

- 若已安装 SwiftLint，提交前确保零 warning / error。
