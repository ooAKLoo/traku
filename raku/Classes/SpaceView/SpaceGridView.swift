//
//  SpaceGridView.swift
//  raku
//
//  Created by Claude on 2025/1/15.
//

import SwiftUI

// MARK: - 空间网格视图
struct SpaceGridView: View {
    let isDarkMode: Bool
    
    @State private var selectedSpace: Space? = nil
    @State private var isNavigatingToSpace = false
    @State private var spaces: [Space] = []
    @State private var showingInspirationList = false
    @State private var showingSpaceCreation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 资源池卡片
                InspirationPoolCard(isDarkMode: isDarkMode) {
                    showingInspirationList = true
                }
                .padding(.horizontal, 20)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 20) {
                    // 添加空间按钮
                    AddSpaceCard(isDarkMode: isDarkMode) {
                        showingSpaceCreation = true
                    }
                    
                    ForEach(spaces) { space in
                        SpaceCard(
                            space: space,
                            isDarkMode: isDarkMode,
                            onTap: {
                                // 导航到详情页
                                selectedSpace = space
                                isNavigatingToSpace = true
                            },
                            onDelete: {
                                // 处理删除逻辑
                                withAnimation(.spring()) {
                                    if DatabaseManager.shared.deleteSpace(id: space.id) {
                                        loadSpaces()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(spaceNavigationLink)
        .sheet(isPresented: $showingInspirationList) {
            InspirationListView(isDarkMode: isDarkMode)
        }
        .onChange(of: showingInspirationList) { isShowing in
            // 当关闭灵感列表时立即隐藏批量选择浮窗
            if !isShowing {
                GlobalPopupManager.shared.hideBatchSelectionImmediately()
            }
        }
        .sheet(isPresented: $showingSpaceCreation) {
            SpaceCreationView(
                isPresented: $showingSpaceCreation,
                isDarkMode: isDarkMode,
                onSpaceCreated: { _ in
                    loadSpaces()
                }
            )
        }
        .onAppear {
            loadSpaces()
        }
    }
    
    // MARK: - 空间导航链接
    private var spaceNavigationLink: some View {
        Group {
            if let space = selectedSpace {
                NavigationLink(
                    destination: SpaceDetailView(space: space)
                        .navigationBarHidden(true),
                    isActive: $isNavigatingToSpace
                ) {
                    EmptyView()
                }
                .hidden()
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Data Loading Methods
    
    private func loadSpaces() {
        spaces = DatabaseManager.shared.getAllSpaces()
    }
}

// MARK: - 添加空间卡片
struct AddSpaceCard: View {
    let isDarkMode: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                        .frame(width: 48, height: 48)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                }
                
                Text(L("space_add_action"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 120)
            .padding(16)
            .background(
                ZStack {
                    // 纯色背景
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    
                    // 虚线边框
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.15),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                }
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }) {}
    }
}

// MARK: - Preview
struct SpaceGridView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式预览
            SpaceGridView(isDarkMode: false)
                .previewDisplayName("Light Mode")
            
            // 深色模式预览
            SpaceGridView(isDarkMode: true)
                .previewDisplayName("Dark Mode")
                .preferredColorScheme(.dark)
        }
    }
}
