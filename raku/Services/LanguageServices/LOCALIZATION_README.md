# 本地化系统使用指南

## 概述

本项目使用统一的文案管理系统，确保所有UI文本都通过标准化的key来获取，而不是硬编码字符串。这样做的好处：

1. **易于发现错误**：当文案key错误时，会直接显示key值，便于快速定位问题
2. **统一管理**：所有文案集中管理，方便维护和更新
3. **多语言支持**：轻松实现国际化，支持多语言切换
4. **一致性保证**：相同功能使用相同文案，保证用户体验一致性

## 使用方法

### 基本使用

```swift
// 获取简单文本
Text(L("common_cancel"))  // 显示：取消

// 获取带参数的文本
Text(L("search_result_count", 10))  // 显示：找到 10 个结果

// 在任何需要字符串的地方使用
Button(L("common_save")) {
    // 保存操作
}
```

### 重要原则

⚠️ **永远不要提供默认值**

```swift
// ❌ 错误做法
Text(L("some_key") ?? "默认文本")

// ✅ 正确做法
Text(L("some_key"))
```

当key不存在时，系统会返回key本身并在控制台打印警告，这样可以快速发现文案错误。

## Key命名规范

### 1. 通用文案 (common_)

格式：`common_功能_类型`

```
common_cancel       // 取消
common_save         // 保存
common_delete       // 删除
common_loading      // 加载中...
```

### 2. 业务文案

格式：`域_功能_场景_类型`

- **域**：业务模块（recording、detail、homepage、search等）
- **功能**：具体功能（list、control、tag等）
- **场景**：使用场景（empty、confirm、edit等）
- **类型**：文案类型（title、desc、message、button等）

```
recording_list_empty            // 录音列表为空
recording_list_empty_desc       // 录音列表为空的描述
recording_delete_confirm_title  // 删除录音确认标题
detail_tag_edit_title          // 详情页标签编辑标题
```

### 3. 常见类型后缀

- `_title`：标题
- `_desc`：描述
- `_message`：消息内容
- `_placeholder`：输入框占位符
- `_button`：按钮文本
- `_label`：标签文本
- `_error`：错误信息
- `_success`：成功信息
- `_loading`：加载状态
- `_empty`：空状态

## 添加新文案

### 1. 在 LocalizationKeys.swift 中添加key注释

```swift
// MARK: - 新功能模块 Keys
// feature_action_title
// feature_action_desc
// feature_error_message
```

### 2. 在 LocalizationData.swift 中添加对应文案

```swift
// 简体中文
"feature_action_title": "功能标题",
"feature_action_desc": "功能描述",
"feature_error_message": "操作失败，请重试",

// 英文
"feature_action_title": "Feature Title",
"feature_action_desc": "Feature description",
"feature_error_message": "Operation failed, please try again",
```

### 3. 在代码中使用

```swift
Text(L("feature_action_title"))
```

## 文件结构

```
LanguageServices/
├── LocalizationManager.swift    # 核心管理器
├── LocalizationKeys.swift       # Key定义参考
├── LocalizationData.swift       # 实际文案数据
└── README.md                    # 本文档
```

## 最佳实践

### 1. 文案复用

相同含义的文案应该复用同一个key：

```swift
// ✅ 好的做法
Button(L("common_cancel")) { }  // 所有取消按钮都用这个

// ❌ 不好的做法
Button(L("recording_cancel")) { }  // 录音页的取消
Button(L("detail_cancel")) { }     // 详情页的取消
```

### 2. 语义化命名

Key应该描述功能而不是具体文案：

```swift
// ✅ 好的命名
"recording_list_empty"       // 描述状态

// ❌ 不好的命名
"no_recordings_text"         // 描述文案内容
```

### 3. 参数化文案

需要动态内容的文案使用参数：

```swift
// 定义
"search_result_count": "找到 %d 个结果"

// 使用
L("search_result_count", results.count)
```

### 4. 错误处理

所有错误信息都应该本地化：

```swift
// ✅ 正确
ToastManager.shared.showError(L("recording_error_save_failed"))

// ❌ 错误
ToastManager.shared.showError("保存失败")
```

## 调试技巧

1. **查看缺失的key**：运行时控制台会打印所有缺失的key
2. **搜索硬编码文案**：搜索项目中的中文字符串，确保都已本地化
3. **测试多语言**：切换语言测试所有文案是否正确显示

## 语言切换

```swift
// 切换到英文
LocalizationManager.shared.switchLanguage(to: "en-US")

// 切换到中文
LocalizationManager.shared.switchLanguage(to: "zh-CN")
```

## 注意事项

1. **不要硬编码任何UI文案**
2. **不要使用默认值掩盖错误**
3. **保持key命名的一致性**
4. **及时更新文档和注释**
5. **新增文案时同时添加所有支持的语言**

## 示例对照

| 场景 | ❌ 错误做法 | ✅ 正确做法 |
|------|------------|------------|
| 按钮文本 | `Button("保存")` | `Button(L("common_save"))` |
| 错误提示 | `Text("网络连接失败")` | `Text(L("error_network_message"))` |
| 动态内容 | `Text("共\(count)条")` | `Text(L("search_result_count", count))` |
| 默认值 | `L("key") ?? "默认"` | `L("key")` |

通过遵循这些规范，我们可以构建一个健壮、易维护的本地化系统。