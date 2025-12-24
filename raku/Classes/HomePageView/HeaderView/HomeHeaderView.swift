//
//  homepageHeaderView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 顶部导航栏视图
struct HomepageHeaderView: View {
    @ObservedObject var audioManager: AudioRecordingService
    let isDarkMode: Bool
    @Binding var searchText: String
    @Binding var showingSidebar: Bool

    @State private var showingSearchBar = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 单行导航栏：[Sidebar按钮] [标题] ---- [搜索按钮]
            HStack(spacing: 16) {
                if showingSearchBar {
                    // 搜索模式：展开搜索框
                    HStack(spacing: 12) {
                        // 返回按钮
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSearchBar = false
                                searchText = ""
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                        }

                        // 智能搜索框
                        SmartSearchBar(
                            searchText: $searchText,
                            isDarkMode: isDarkMode,
                            onSearchAction: {
                                // TODO: 实现AI搜索建议功能
                            },
                            onTextChange: nil,
                            isTextFieldFocused: $isSearchFieldFocused
                        )

                        // 清除按钮
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    // 正常模式
                    // 左侧：Sidebar按钮 - 使用更简约的 SF Symbol
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
                            .frame(width: 24, height: 40, alignment: .leading)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    // 右侧：胶囊形搜索框（SmartSearchBar 的缩小版）
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSearchBar.toggle()
                        }
                    }) {
                        HStack(spacing: 0) {
                            // 左侧 sparkles 图标
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: isDarkMode ? [
                                            Color.cyan,
                                            Color.purple
                                        ] : [
                                            Color.orange,
                                            Color.purple
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.leading, 14)
                                .padding(.trailing, 10)

                            // 竖线分隔
                            Rectangle()
                                .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                                .frame(width: 1, height: 16)

                            // 搜索图标 + placeholder
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))

                                Text(L("search_placeholder"))
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))

                                Spacer()
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 14)
                        }
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isDarkMode ? Color.gray.opacity(0.15) : Color(hex: "EBEBE9").opacity(0.5))
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
        .padding(.horizontal, UIConstants.horizontalPadding)
        .padding(.top, UIConstants.Header.topPadding)
        .padding(.bottom, UIConstants.Header.bottomPadding)
        .background(
            (isDarkMode ? Color.black : Color.appBackground)
        )
        .onChange(of: showingSearchBar) { newValue in
            // 仅在从 false 变为 true 时聚焦
            if newValue {
                // 延迟聚焦以确保动画完成和视图渲染
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchFieldFocused = true
                    }
                }
            }
        }
    }
    
}

#Preview("Light Mode") {
    HomepageHeaderView(
        audioManager: AudioRecordingService(skipDatabaseLoad: true),
        isDarkMode: false,
        searchText: .constant(""),
        showingSidebar: .constant(false)
    )
}

#Preview("Dark Mode") {
    HomepageHeaderView(
        audioManager: AudioRecordingService(skipDatabaseLoad: true),
        isDarkMode: true,
        searchText: .constant(""),
        showingSidebar: .constant(false)
    )
    .background(Color.black)
}
