# SwiftUI 组件化设计架构

本项目采用组件化设计模式，将 UI 组件按照职责和复杂度分为多个层次，确保代码的可维护性、可复用性和可测试性。

## 🏗️ 架构层次

### 1. **Atoms (基础组件层)**
`/Components/Atoms/`

最小的、不可再分的 UI 组件，如按钮、文本、图标等基础元素。

**特点：**
- 高度可复用
- 接受简单参数
- 无业务逻辑
- 使用 `@Binding` 进行状态管理

**示例组件：**
```swift
struct PrimaryButton: View
struct IconLabel: View  
struct CustomTextField: View
struct LoadingIndicator: View
struct TagView: View
```

### 2. **Molecules (复合组件层)**
`/Components/Molecules/`

由基础组件组合而成的功能单元，如搜索栏、卡片、列表项等。

**特点：**
- 组合多个基础组件
- 具有特定功能
- 可包含简单交互逻辑
- 使用 `@State` 管理内部状态

**示例组件：**
```swift
struct SearchBar: View
struct RecordingCard: View
struct NavigationHeader: View
struct FilterTabBar: View
```

### 3. **Organisms (模块组件层)**
`/Components/Organisms/`

完整的功能模块，包含复杂的业务逻辑。

**特点：**
- 包含业务逻辑
- 可能依赖 ViewModel
- 处理数据流转
- 使用 `@StateObject` 或 `@ObservedObject`

**示例组件：**
```swift
struct RecordingCardsView: View
struct FloatingRecordingControl: View
struct SettingsPanel: View
```

### 4. **Utilities (共享工具)**
`/Components/Utilities/`

共享的工具类、扩展和修饰符。

**包含：**
- ViewModifiers
- Extensions
- Constants
- Helper Functions

## 📁 文件组织结构

```
Components/
├── README.md                    # 本文档
├── Atoms/                       # 基础组件
│   ├── Buttons/
│   ├── Text/
│   ├── Icons/
│   └── Input/
├── Molecules/                   # 复合组件
│   ├── Cards/
│   ├── Navigation/
│   └── Forms/
├── Organisms/                   # 模块组件
│   ├── Lists/
│   ├── Headers/
│   └── Panels/
└── Utilities/                   # 工具类
    ├── ViewModifiers/
    ├── Extensions/
    └── Constants/
```

## 🎯 设计原则

### 1. **单一职责原则**
每个组件只负责一件事，职责明确。

### 2. **依赖倒置原则**
高层组件不依赖低层实现细节，通过协议进行解耦。

### 3. **接口隔离原则**
通过协议定义组件间的通信，避免不必要的依赖。

### 4. **组合优于继承**
使用 ViewModifier 和 ViewBuilder 进行组合，而非继承。

## 📋 数据流和状态管理

### 基础组件 (Atoms)
```swift
struct CustomButton: View {
    @Binding var isSelected: Bool
    let title: String
    let action: () -> Void
}
```

### 复合组件 (Molecules)
```swift
struct SearchBar: View {
    @State private var searchText: String = ""
    @Binding var isSearching: Bool
    let onSearchChanged: (String) -> Void
}
```

### 模块组件 (Organisms)
```swift
struct ProductList: View {
    @StateObject private var viewModel = ProductViewModel()
    @EnvironmentObject var appState: AppState
}
```

## 🔧 命名约定

### 组件命名
- 使用描述性的名称
- 避免缩写，除非是广泛认知的
- 使用 `View` 后缀（可选）

### 文件命名
- 与组件名称保持一致
- 使用 PascalCase
- 按功能分组到子文件夹

## 📚 使用指南

### 创建新组件时的检查清单

1. **确定组件层次**
   - 是否可以进一步拆分？→ Molecules/Organisms
   - 是否是最小单元？→ Atoms
   - 是否包含业务逻辑？→ Organisms

2. **设计接口**
   - 明确输入参数
   - 定义回调函数
   - 确定状态管理方式

3. **选择合适的文件夹**
   - 按功能分类
   - 考虑复用性

4. **编写文档**
   - 添加注释说明用途
   - 提供使用示例
   - 说明参数含义

## 🚀 最佳实践

1. **优先考虑复用性**：设计时考虑在其他地方是否可能用到

2. **保持接口简洁**：避免过多的参数，考虑使用配置对象

3. **使用预览**：为每个组件提供 SwiftUI 预览

4. **测试友好**：确保组件可以独立测试

5. **性能优化**：合理使用 `@ViewBuilder` 和条件渲染

## 📖 参考资源

- [SwiftUI 官方文档](https://developer.apple.com/documentation/swiftui)
- [Atomic Design 原则](https://bradfrost.com/blog/post/atomic-web-design/)
- [SwiftUI 最佳实践](https://developer.apple.com/documentation/swiftui/swiftui-overview)

---

💡 **提示**：在实现新功能时，优先查看是否有现有组件可以复用，避免重复造轮子。