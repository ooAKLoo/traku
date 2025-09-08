//
//  Toast.swift
//  高级质感的 Toast 提示组件
//

import SwiftUI

// MARK: - Toast 数据模型
struct ToastItem: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    var duration: TimeInterval = 3.0
    
    enum ToastType {
        case info
        case success
        case warning
        case error
        
        var iconName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        // 更精致的配色方案
        var accentColor: Color {
            switch self {
            case .info:
                return Color(red: 0.0, green: 0.48, blue: 1.0) // 纯净蓝
            case .success:
                return Color(red: 0.2, green: 0.78, blue: 0.35) // 清新绿
            case .warning:
                return Color(red: 1.0, green: 0.58, blue: 0.0) // 温暖橙
            case .error:
                return Color(red: 1.0, green: 0.23, blue: 0.19) // 优雅红
            }
        }
        
        // 图标背景渐变色
        var iconGradient: LinearGradient {
            switch self {
            case .info:
                return LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.48, blue: 1.0),
                        Color(red: 0.0, green: 0.35, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .success:
                return LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.78, blue: 0.35),
                        Color(red: 0.15, green: 0.68, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .warning:
                return LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.58, blue: 0.0),
                        Color(red: 0.95, green: 0.48, blue: 0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .error:
                return LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.23, blue: 0.19),
                        Color(red: 0.9, green: 0.15, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

// MARK: - Toast 视图
struct ToastView: View {
    let toast: ToastItem
    @State private var isShowing = false
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标部分 - 使用渐变背景
            ZStack {
                Circle()
                    .fill(toast.type.iconGradient)
                    .frame(width: 32, height: 32)
                
                Image(systemName: toast.type.iconName)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            // 文字内容
            Text(toast.message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(isDarkMode ? .white : Color(red: 0.15, green: 0.15, blue: 0.2))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            // 关闭按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // 毛玻璃效果背景
            ZStack {
                // 基础背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode
                        ? Color(red: 0.15, green: 0.15, blue: 0.17)
                        : Color.white
                    )
                
                // 毛玻璃效果
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        .ultraThinMaterial.opacity(isDarkMode ? 0.8 : 0.95)
                    )
            }
            .shadow(
                color: isDarkMode
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.08),
                radius: 20,
                x: 0,
                y: 10
            )
            // 细微的彩色光晕
            .shadow(
                color: toast.type.accentColor.opacity(0.15),
                radius: 30,
                x: 0,
                y: 5
            )
        )
        // 极细的边框增加精致感
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
                            isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .padding(.horizontal, 20)
        .offset(y: dragOffset.height)
        .scaleEffect(isShowing ? 1 : 0.9)
        .opacity(isShowing ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isShowing)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {  // 改为向上拖动
                        dragOffset = value.translation
                        isDragging = true
                    }
                }
                .onEnded { value in
                    if value.translation.height < -50 {  // 向上拖动超过50触发关闭
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                            dragOffset.height = -200  // 向上消失
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                            isDragging = false
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                isShowing = true
            }
            
            if !isDragging {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    if !isDragging {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isShowing = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 极简风格 Toast（备选方案）
struct MinimalToastView: View {
    let toast: ToastItem
    @State private var isShowing = false
    @Environment(\.colorScheme) var colorScheme
    let onDismiss: () -> Void
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 左侧彩色指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(toast.type.accentColor)
                .frame(width: 3, height: 24)
            
            // 图标
            Image(systemName: toast.type.iconName)
                .foregroundColor(toast.type.accentColor)
                .font(.system(size: 14, weight: .semibold))
            
            // 文字
            Text(toast.message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : Color(red: 0.2, green: 0.2, blue: 0.25))
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isDarkMode
                    ? Color(red: 0.18, green: 0.18, blue: 0.2)
                    : Color(red: 0.98, green: 0.98, blue: 0.99)
                )
                .shadow(
                    color: isDarkMode
                        ? Color.black.opacity(0.4)
                        : Color.black.opacity(0.06),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 20)
        .scaleEffect(isShowing ? 1 : 0.95)
        .opacity(isShowing ? 1 : 0)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isShowing)
        .onAppear {
            withAnimation {
                isShowing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                withAnimation {
                    isShowing = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Toast 管理器
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var toasts: [ToastItem] = []
    private let maxToasts = 3 // 最多同时显示的 Toast 数量
    
    private init() {}
    
    func show(_ message: String, type: ToastItem.ToastType = .info, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            // 如果超过最大数量，移除最早的
            if self.toasts.count >= self.maxToasts {
                self.toasts.removeFirst()
            }
            
            let toast = ToastItem(message: message, type: type, duration: duration)
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.toasts.append(toast)
            }
        }
    }
    
    func showInfo(_ message: String) {
        show(message, type: .info)
    }
    
    func showSuccess(_ message: String) {
        show(message, type: .success)
    }
    
    func showWarning(_ message: String) {
        show(message, type: .warning)
    }
    
    func showError(_ message: String) {
        show(message, type: .error)
    }
    
    func dismiss(_ toast: ToastItem) {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.toasts.removeAll { $0.id == toast.id }
            }
        }
    }
}

// MARK: - Toast 容器修饰符
struct ToastModifier: ViewModifier {
    @ObservedObject private var toastManager = ToastManager.shared
    var useMinimalStyle: Bool = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack(spacing: 8) {
                ForEach(toastManager.toasts) { toast in
                    if useMinimalStyle {
                        MinimalToastView(toast: toast) {
                            toastManager.dismiss(toast)
                        }
                    } else {
                        ToastView(toast: toast) {
                            toastManager.dismiss(toast)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 50) // 添加顶部安全距离
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastManager.toasts.count)
        }
    }
}

// MARK: - View 扩展
extension View {
    func toastContainer(minimal: Bool = false) -> some View {
        modifier(ToastModifier(useMinimalStyle: minimal))
    }
}

// MARK: - 预览
struct Toast_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("高级质感 Toast")
                .font(.largeTitle)
                .bold()
                .padding(.top, 50)
            
            Button("显示信息") {
                ToastManager.shared.showInfo("同步已完成，数据已更新")
            }
            .buttonStyle(.borderedProminent)
            
            Button("显示成功") {
                ToastManager.shared.showSuccess("文件上传成功")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            
            Button("显示警告") {
                ToastManager.shared.showWarning("存储空间即将不足")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            
            Button("显示错误") {
                ToastManager.shared.showError("网络连接失败")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .toastContainer() // 使用默认高级样式
//         .toastContainer(minimal: true) // 使用极简样式
    }
}
