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
                    // 左侧：Sidebar按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar.toggle()
                        }
                    }) {
                        VStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(isDarkMode ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
                                    .frame(width: 20, height: 2.5)
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    // 标题
                    Text(L("homepage_filter_tag"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)

                    Spacer()

                    // 右侧：搜索按钮
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSearchBar.toggle()
                        }
                    }) {
                        Circle()
                            .fill(isDarkMode ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                            )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
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
