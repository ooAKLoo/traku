//
//  AIAnalysisTriggerButton.swift
//  raku
//
//  AI 深度分析触发按钮
//  用于手动触发第二阶段 enrichedContent 生成
//

import SwiftUI

struct AIAnalysisTriggerButton: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading {
                // 触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                // 图标区域
                ZStack {
                    if isLoading {
                        // 加载动画
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .white.opacity(0.8) : .blue))
                            .scaleEffect(0.9)
                    } else {
                        // Sparkles 图标 - 蓝色渐变
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: isDarkMode
                                        ? [Color.blue.opacity(0.8), Color.cyan.opacity(0.7)]
                                        : [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: 24, height: 24)

                // 文字区域
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLoading ? "正在生成深度解读..." : "生成 AI 深度解读")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))

                    if !isLoading {
                        Text("基于内容分析行动建议")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.45))
                    }
                }

                Spacer()

                // 右侧箭头（非加载状态）
                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.25))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color(hex: "1C1C1E") : Color(hex: "F5F5F3"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Preview
struct AIAnalysisTriggerButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 正常状态 - Light
            AIAnalysisTriggerButton(isLoading: false) {
                print("Tapped")
            }
            .padding(.horizontal, 24)

            // 加载状态 - Light
            AIAnalysisTriggerButton(isLoading: true) {
                print("Tapped")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
        .background(Color.white)
        .previewDisplayName("Light Mode")

        VStack(spacing: 20) {
            // 正常状态 - Dark
            AIAnalysisTriggerButton(isLoading: false) {
                print("Tapped")
            }
            .padding(.horizontal, 24)

            // 加载状态 - Dark
            AIAnalysisTriggerButton(isLoading: true) {
                print("Tapped")
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .previewDisplayName("Dark Mode")
    }
}
