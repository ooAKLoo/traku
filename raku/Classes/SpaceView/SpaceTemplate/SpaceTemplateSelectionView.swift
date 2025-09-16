//
//  SpaceTemplateSelectionView.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 空间模板选择视图（Bottom Sheet）
struct SpaceTemplateSelectionView: View {
    @Binding var isPresented: Bool
    @State private var showingCustomSpaceView = false
    let isDarkMode: Bool
    let onSpaceCreated: (Space) -> Void
    
    private let templates = SpaceTemplate.defaultTemplates
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                dragIndicator
                
                // 标题区域
                titleSection
                
                // 模板网格
                templateGrid
                
                // 底部自定义按钮
                customButton
            }
            .background(isDarkMode ? Color.black : Color.white)
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showingCustomSpaceView) {
            CustomSpaceConfigView(
                isPresented: $showingCustomSpaceView,
                isDarkMode: isDarkMode,
                onSpaceCreated: { space in
                    onSpaceCreated(space)
                    isPresented = false
                }
            )
        }
    }
    
    // MARK: - 拖拽指示器
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 20)
    }
    
    // MARK: - 标题区域
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("选择空间模板")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("从预设模板快速开始，或自定义专属空间")
                .font(.system(size: 16))
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - 模板网格
    private var templateGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(templates) { template in
                    TemplateCard(
                        template: template,
                        isDarkMode: isDarkMode,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                createSpaceFromTemplate(template)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 自定义按钮
    private var customButton: some View {
        VStack(spacing: 16) {
            Divider()
                .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
            
            Button(action: {
                showingCustomSpaceView = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .light))
                    
                    Text("自定义空间")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(isDarkMode ? Color.blue.opacity(0.8) : Color.blue.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isDarkMode ? Color.blue.opacity(0.2) : Color.blue.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isDarkMode ? Color.blue.opacity(0.03) : Color.blue.opacity(0.03))
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
    }
    
    // MARK: - Methods
    private func createSpaceFromTemplate(_ template: SpaceTemplate) {
        // 创建空间
        let space = Space(
            name: template.title,
            description: template.description
        )
        
        // 保存到数据库
        if DatabaseManager.shared.createSpace(space) {
            // 创建类别
            for categoryItem in template.categories {
                let category = Category(
                    spaceId: space.id,
                    name: categoryItem.name
                )
                _ = DatabaseManager.shared.createCategory(category)
            }
            
            onSpaceCreated(space)
            isPresented = false
        }
    }
}

// MARK: - 模板卡片
struct TemplateCard: View {
    let template: SpaceTemplate
    let isDarkMode: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // 标题和描述
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(template.emoji)
                            .font(.system(size: 22))
                            .opacity(0.9)
                        
                        Text(template.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
                            .lineLimit(1)
                    }
                    
                    Text(template.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 类别预览
                CategoryPreviewView(
                    categories: template.categories,
                    isDarkMode: isDarkMode
                )

                Spacer(minLength: 4)
            }
            .padding(16)
            .frame(height: 180)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04),
                                lineWidth: 0.5
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - 类别预览组件
struct CategoryPreviewView: View {
    let categories: [TemplateCategoryItem]
    let isDarkMode: Bool
    
    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(categories, id: \.name) { category in
                CategoryTag(category: category, isDarkMode: isDarkMode)
            }
        }
    }
}

// MARK: - 类别标签组件
struct CategoryTag: View {
    let category: TemplateCategoryItem
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            Text(category.emoji)
                .font(.system(size: 10))
                .opacity(0.8)
            
            Text(category.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isDarkMode ? .white.opacity(0.55) : .black.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(category.color.opacity(isDarkMode ? 0.08 : 0.1))
        )
    }
}

// MARK: - 预览
struct SpaceTemplateSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SpaceTemplateSelectionView(
            isPresented: .constant(true),
            isDarkMode: false,
            onSpaceCreated: { _ in }
        )
    }
}
