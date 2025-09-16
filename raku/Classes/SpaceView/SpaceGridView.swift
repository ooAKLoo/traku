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
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
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
    
    private let cardHeight: CGFloat = 120
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                
                Text("添加空间")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.gray.opacity(0.1) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2),
                                style: StrokeStyle(lineWidth: 2, dash: [4])
                            )
                    )
                    .shadow(
                        color: isDarkMode ? .clear : .black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
