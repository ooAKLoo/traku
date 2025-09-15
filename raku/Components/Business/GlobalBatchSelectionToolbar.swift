//
//  GlobalBatchSelectionToolbar.swift
//  raku
//
//  Created by Assistant on 2025/1/15.
//  批量选择工具栏 - 全局批量操作工具栏组件（已迁移到全局浮窗系统）
//

import SwiftUI

// MARK: - 全局批量选择工具栏
struct GlobalBatchSelectionToolbar: View {
    let data: BatchSelectionData
    let isDarkMode: Bool
    let onDismiss: () -> Void
    
    // 动画状态
    @State private var isShowing = false
    @State private var buttonScale = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏内容
            HStack(spacing: 20) {
                // 左侧：选择状态指示器
                HStack(spacing: 12) {
                    // 动态圆形指示器
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.blue.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 42, height: 42)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.15),
                                        Color.blue.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                        
                        Text("\(data.selectedCount)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                    }
//                    .scaleEffect(isShowing ? 1.0 : 0.8)
//                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1), value: isShowing)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选择")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        
                        Button(action: {
                            if data.selectedCount == data.totalCount {
                                data.onDeselectAll()
                            } else {
                                data.onSelectAll()
                            }
                        }) {
                            Text(data.selectedCount == data.totalCount ? "取消全选" : "全选")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // 右侧：操作按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        buttonScale = 1.0
                        data.onAction()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: data.actionIcon)
                            .font(.system(size: 15, weight: .semibold))
                        
                        Text(data.actionTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            // 背景渐变
                            LinearGradient(
                                colors: data.selectedCount == 0 ? 
                                    [Color.gray, Color.gray.opacity(0.8)] :
                                    [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // 光泽效果
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(data.selectedCount == 0 ? 0.1 : 0.2),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        }
                        .clipShape(Capsule())
                        .shadow(
                            color: (data.selectedCount == 0 ? Color.gray : Color.blue).opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    )
                    .scaleEffect(buttonScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
                }
                .disabled(data.selectedCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
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
                    color: Color.black.opacity(isDarkMode ? 0.4 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 1,
                    x: 0,
                    y: 1
                )
            )
        }
        .offset(y: isShowing ? 0 : 150)
        .opacity(isShowing ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0), value: isShowing)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isShowing = true
            }
        }
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


