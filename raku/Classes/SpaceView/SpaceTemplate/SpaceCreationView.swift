//
//  SpaceCreationView.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 空间创建统一视图
struct SpaceCreationView: View {
    @Binding var isPresented: Bool
    let isDarkMode: Bool
    let onTemplateSelected: (SpaceTemplate) -> Void
    let onCustomSelected: () -> Void
    
    @State private var selectedMode: CreationMode = .template
    @State private var showingCustomSpaceView = false
    
    enum CreationMode: String, CaseIterable {
        case custom = "自定义"
        case template = "模板"
    }
    
    private let templates = SpaceTemplate.defaultTemplates
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                dragIndicator
                
                // 模式切换Slider
                modeSelector
                
                // 根据选择显示不同内容
                Group {
                    if selectedMode == .custom {
                        customModeContent
                    } else {
                        templateModeContent
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: selectedMode)
            }
            .background(
                ZStack {
                    // 主背景
                    (isDarkMode ? Color.black : Color(uiColor: .systemBackground))
                    
                    // 添加微妙的渐变效果
                    LinearGradient(
                        colors: [
                            isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(isDarkMode ? Color.black : Color(uiColor: .systemBackground))
    }
    
    // MARK: - 拖拽指示器
    private var dragIndicator: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.15))
                .frame(width: 36, height: 5)
                .shadow(color: isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05), radius: 1, y: 1)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - 模式选择器
    private var modeSelector: some View {
        VStack(spacing: 24) {
            titleSection
            modeSwitcher
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - 标题部分
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("创建空间")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .black)
                .tracking(-0.5)
            
            Text("为你的灵感打造专属领地")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
        }
    }
    
    // MARK: - 模式切换器
    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(CreationMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
        .padding(4)
        .background(switcherBackground)
        .padding(.horizontal, 20)
    }
    
    // MARK: - 模式按钮
    private func modeButton(for mode: CreationMode) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedMode = mode
            }
        }) {
            modeButtonContent(for: mode)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 模式按钮内容
    private func modeButtonContent(for mode: CreationMode) -> some View {
        let isSelected = selectedMode == mode
        let iconName = mode == .custom ? "sparkles" : "square.grid.3x3"
        let textColor = buttonTextColor(isSelected: isSelected)
        let backgroundColor = buttonBackgroundColor(isSelected: isSelected)
        let shadowColor = buttonShadowColor(isSelected: isSelected)
        
        return VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                
                Text(mode.rawValue)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
            }
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - 颜色辅助方法
    private func buttonTextColor(isSelected: Bool) -> Color {
        if isSelected {
            return isDarkMode ? Color.black : Color.white
        } else {
            return isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.5)
        }
    }
    
    private func buttonBackgroundColor(isSelected: Bool) -> Color {
        if isSelected {
            return isDarkMode ? Color.white : Color.black
        } else {
            return Color.clear
        }
    }
    
    private func buttonShadowColor(isSelected: Bool) -> Color {
        if isSelected {
            return isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    // MARK: - 切换器背景
    private var switcherBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1), lineWidth: 0.5)
            )
    }
    
    // MARK: - 模板模式内容
    private var templateModeContent: some View {
        VStack(spacing: 16) {
            // 描述文本
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择一个模板")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
                    
                    Text("根据你的场景快速开始")
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(templates) { template in
                        TemplateCard(
                            template: template,
                            isDarkMode: isDarkMode,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    onTemplateSelected(template)
                                    isPresented = false
                                }
                            }
                        )
                        .scaleEffect(1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: template.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
        .transition(.asymmetric(
            insertion: .push(from: .trailing).combined(with: .opacity),
            removal: .push(from: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - 自定义模式内容
    private var customModeContent: some View {
        VStack(spacing: 16) {
            // 描述文本
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("从零开始构建")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
                    
                    Text("创建完全符合你需求的空间")
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            CustomSpaceConfigView(
                isPresented: $isPresented,
                isDarkMode: isDarkMode,
                onSpaceCreated: { customSpace in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                        onCustomSelected()
                    }
                },
                isEmbedded: true
            )
        }
        .transition(.asymmetric(
            insertion: .push(from: .leading).combined(with: .opacity),
            removal: .push(from: .trailing).combined(with: .opacity)
        ))
    }
}

// MARK: - 预览
struct SpaceCreationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SpaceCreationView(
                isPresented: .constant(true),
                isDarkMode: false,
                onTemplateSelected: { _ in },
                onCustomSelected: {}
            )
            .previewDisplayName("Light Mode")
            
            SpaceCreationView(
                isPresented: .constant(true),
                isDarkMode: true,
                onTemplateSelected: { _ in },
                onCustomSelected: {}
            )
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
        }
    }
}