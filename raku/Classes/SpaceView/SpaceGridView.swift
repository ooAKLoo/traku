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
    
    @State private var selectedSpace: SpaceCategory? = nil
    @State private var isNavigatingToSpace = false
    @State private var spaces = SpaceCategory.mockSpaces
    @State private var cardStates: [String: Bool] = [:]
    @State private var showingInspirationList = false
    
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
                    ForEach(spaces) { space in
                        SpaceInspirationCard(
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
                                    spaces.removeAll { $0.id == space.id }
                                }
                            },
                            onDragStateChanged: { isDragging in
                                // 可以在这里处理拖动状态变化
                                cardStates[space.id.uuidString] = isDragging
                            }
                        )
                        .onTapGesture {
                            // 只有在没有拖动时才导航
                            if cardStates[space.id.uuidString] != true {
                                selectedSpace = space
                                isNavigatingToSpace = true
                            }
                        }
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