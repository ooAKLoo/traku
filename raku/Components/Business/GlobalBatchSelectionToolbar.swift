//
//  GlobalBatchSelectionToolbar.swift
//  raku
//
//  Created by Assistant on 2025/1/15.
//  批量选择工具栏 - 全局批量操作工具栏组件（已迁移到全局浮窗系统）
//

import SwiftUI

// MARK: - 独立的选择圆环组件
struct SelectionRingView: View {
    let selectedCount: Int
    let totalCount: Int
    let onToggle: () -> Void
    
    @State private var animatedProgress: CGFloat
    
    private var progress: CGFloat {
        totalCount > 0 ? CGFloat(selectedCount) / CGFloat(totalCount) : 0
    }
    
    init(selectedCount: Int, totalCount: Int, onToggle: @escaping () -> Void) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.onToggle = onToggle
        
        // 初始化时就设置正确的进度值，避免从0开始的动画
        let initialProgress = totalCount > 0 ? CGFloat(selectedCount) / CGFloat(totalCount) : 0
        self._animatedProgress = State(initialValue: initialProgress)
    }
    
    private var isFullySelected: Bool {
        selectedCount == totalCount && totalCount > 0
    }
    
    var body: some View {
        Button(action: onToggle) {
            ZStack {
                // 背景圆环
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)

                // 进度圆环 - 使用缓变动效
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .opacity(selectedCount > 0 ? 1 : 0)

                // 数字显示（白底蓝字）
                if selectedCount > 0 && !isFullySelected {
                    Text(selectedCount > 99 ? "99+" : "\(selectedCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                }

                // 对勾
                if isFullySelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 26, height: 26)
        }
        .frame(width: 36, height: 36)
        .animation(.none, value: selectedCount) // 禁用 selectedCount 导致的二次动画
        .onChange(of: progress) { newProgress in
            // 当进度变化时，触发缓变动效（仅在数字改变时，不在转场时）
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = newProgress
            }
        }
    }
}

// MARK: - 全局批量选择工具栏
struct GlobalBatchSelectionToolbar: View {
    let data: BatchSelectionData
    let isDarkMode: Bool
    let onDismiss: () -> Void

    // 动画状态
    @State private var buttonScale = 1.0

    var body: some View {
        // 工具栏内容
        HStack(spacing: 16) {
                // 左侧：全选/取消全选圆环按钮
                SelectionRingView(
                    selectedCount: data.selectedCount,
                    totalCount: data.totalCount,
                    onToggle: {
                        if data.selectedCount == data.totalCount {
                            data.onDeselectAll()
                        } else {
                            data.onSelectAll()
                        }
                    }
                )
                
                Spacer()
                
                // 中间：操作按钮（包含选择数量）
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        buttonScale = 1.0
                        data.onAction()
                    }
                }) {
                    HStack(spacing: 6) {
                        // Plus按钮
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(data.selectedCount == 0 ? 
                                           (isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)) :
                                           .white)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(data.selectedCount == 0 ? 
                                          Color.gray.opacity(0.25) :
                                          Color.blue)
                            )
                        
                        Text(data.actionTitle)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(data.selectedCount == 0 ? 
                                   (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)) :
                                   (isDarkMode ? .white.opacity(0.9) : .blue.opacity(0.9)))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(data.selectedCount == 0 ? 
                                  Color.gray.opacity(isDarkMode ? 0.2 : 0.15) :
                                  Color.blue.opacity(isDarkMode ? 0.4 : 0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        data.selectedCount == 0 ? 
                                        Color.clear :
                                        Color.blue.opacity(isDarkMode ? 0.6 : 0.4),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .scaleEffect(buttonScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
                }
                .disabled(data.selectedCount == 0)
                
                Spacer()
                
                // 右侧：取消按钮
                Button(action: {
                    data.onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08))
                        )
                }
        }
        .frame(height: 63)
        .padding(.horizontal, 20)
        .background(
            // 轻盈的背景效果
            ZStack {
                // 模糊背景
                VisualEffectBlur(blurStyle: isDarkMode ? .systemThinMaterialDark : .systemThinMaterialLight)

                // 微妙的渐变叠加
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDarkMode ? 0.05 : 0.1),
                        Color.white.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 边框高光
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDarkMode ? 0.2 : 0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(
                color: Color.black.opacity(isDarkMode ? 0.3 : 0.08),
                radius: 12,
                x: 0,
                y: 4
            )
            .shadow(
                color: Color.black.opacity(isDarkMode ? 0.15 : 0.04),
                radius: 32,
                x: 0,
                y: 8
            )
        )
    }
}

// MARK: - 视觉效果模糊
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - 圆角形状
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
