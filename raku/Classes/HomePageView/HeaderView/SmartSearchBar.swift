//
//  SmartSearchBar.swift
//  raku
//
//  Created by Claude on 2025/1/12.
//

import SwiftUI

// MARK: - 智能搜索框组件
struct SmartSearchBar: View {
    @Binding var searchText: String
    let isDarkMode: Bool
    let onSearchAction: () -> Void
    let onTextChange: ((String) -> Void)?
    
    @State private var searchGlowAnimation = false
    @State private var searchTypingTimer: Timer?
    @State private var sparklesPulse = false
    @State private var flowingLightOffset: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧科技感 sparkles 按钮
            sparklesButton
            
            // 竖线分隔
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                .frame(width: 1, height: 20)
            
            // 搜索输入框
            TextField("", text: $searchText, prompt: 
                Text(L("search_smart_placeholder"))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    .font(.system(size: 16))
            )
            .font(.system(size: 16))
            .foregroundColor(isDarkMode ? .white : .black)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .focused($isTextFieldFocused)
            .onChange(of: searchText) { newValue in
                handleSearchTextChange(newValue)
                onTextChange?(newValue)
            }
        }
        .background(searchBarBackground)
        .onAppear {
            // 确保UI完全渲染后再聚焦，避免卡顿
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    // MARK: - 计算属性
    private var sparklesButton: some View {
        Button(action: {
            onSearchAction()
            triggerSparklesAnimation()
        }) {
            sparklesIcon
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .onAppear {
            startSparklesAnimation()
        }
    }
    
    private var sparklesIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(sparklesGradient)
            .scaleEffect(sparklesPulse ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), 
                      value: sparklesPulse)
    }
    
    private var sparklesGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ? [
                Color.cyan,
                Color.blue,
                Color.purple,
                Color.pink
            ] : [
                Color.orange,
                Color.red,
                Color.purple,
                Color.blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(isDarkMode ? Color.gray.opacity(0.15) : Color.white)
            .overlay(
                // 多层动态光晕效果
                ZStack {
                    // 基础光晕层
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: searchText.isEmpty ? [] : [
                                    isDarkMode ? Color.yellow.opacity(0.4) : Color.orange.opacity(0.4),
                                    isDarkMode ? Color.blue.opacity(0.3) : Color.blue.opacity(0.3),
                                    isDarkMode ? Color.purple.opacity(0.2) : Color.purple.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: searchText.isEmpty ? 0 : 1.5
                        )
                        .opacity(searchText.isEmpty ? 0 : 0.8)
                        .animation(.easeInOut(duration: 0.3), value: searchText.isEmpty)
                    
                    // 循环流光效果层
                    if !searchText.isEmpty && searchGlowAnimation {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.clear,
                                        isDarkMode ? Color.yellow.opacity(0.9) : Color.orange.opacity(0.9),
                                        isDarkMode ? Color.cyan.opacity(0.7) : Color.blue.opacity(0.7),
                                        isDarkMode ? Color.purple.opacity(0.5) : Color.purple.opacity(0.5),
                                        Color.clear,
                                        Color.clear
                                    ],
                                    startPoint: UnitPoint(x: flowingLightOffset - 0.3, y: 0.5),
                                    endPoint: UnitPoint(x: flowingLightOffset + 0.3, y: 0.5)
                                ),
                                lineWidth: 2.5
                            )
                            .opacity(0.8)
                            .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), 
                                      value: flowingLightOffset)
                    }
                    
                    // 呼吸光效层
                    if !searchText.isEmpty {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                RadialGradient(
                                    colors: [
                                        isDarkMode ? Color.yellow.opacity(0.3) : Color.orange.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                ),
                                lineWidth: 1
                            )
                            .scaleEffect(searchGlowAnimation ? 1.05 : 1.0)
                            .opacity(searchGlowAnimation ? 0.3 : 0.6)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), 
                                      value: searchGlowAnimation)
                    }
                }
            )
    }
    
    // MARK: - 私有方法
    private func handleSearchTextChange(_ newValue: String) {
        // 取消之前的定时器
        searchTypingTimer?.invalidate()
        
        if !newValue.isEmpty {
            // 开始流光动画
            withAnimation {
                searchGlowAnimation = true
            }
            
            // 启动循环流光动画
            startFlowingLightAnimation()
            
            // 设置定时器，持续输入期间保持动画
            searchTypingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                // 3秒后停止流光动画
                withAnimation(.easeOut(duration: 0.8)) {
                    searchGlowAnimation = false
                }
                stopFlowingLightAnimation()
            }
        } else {
            // 清空文本时立即停止动画
            withAnimation(.easeOut(duration: 0.3)) {
                searchGlowAnimation = false
            }
            stopFlowingLightAnimation()
            searchTypingTimer?.invalidate()
        }
    }
    
    private func startSparklesAnimation() {
        // 启动持续的脉动动画
        withAnimation {
            sparklesPulse = true
        }
    }
    
    private func triggerSparklesAnimation() {
        // 点击时的脉动反馈效果
        withAnimation(.easeInOut(duration: 0.3)) {
            sparklesPulse.toggle()
        }
    }
    
    private func startFlowingLightAnimation() {
        // 重置并开始流光循环动画
        flowingLightOffset = -0.5
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            flowingLightOffset = 1.5
        }
    }
    
    private func stopFlowingLightAnimation() {
        // 停止流光动画，平滑回到初始状态
        withAnimation(.easeOut(duration: 0.5)) {
            flowingLightOffset = 0
        }
    }
}

// MARK: - 预览
#Preview("Light Mode") {
    SmartSearchBar(
        searchText: .constant(""),
        isDarkMode: false,
        onSearchAction: {
            print("AI Search triggered")
        },
        onTextChange: { text in
            print("Text changed: \(text)")
        }
    )
    .padding()
    .background(Color(white: 0.95))
}

#Preview("Dark Mode") {
    SmartSearchBar(
        searchText: .constant("测试搜索"),
        isDarkMode: true,
        onSearchAction: {
            print("AI Search triggered")
        },
        onTextChange: { text in
            print("Text changed: \(text)")
        }
    )
    .padding()
    .background(Color.black)
}
