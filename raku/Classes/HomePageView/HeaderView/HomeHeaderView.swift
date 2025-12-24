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
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 单行导航栏：[设备图标] [搜索框] [设置按钮]
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
                    // 左侧：设备图标
                    Button(action: {
                        // TODO: 可以点击跳转到设备列表或其他功能
                    }) {
                        Image("product")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                    // 中间：胶囊形搜索框
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

                            // placeholder
                            HStack(spacing: 6) {
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

                    // 右侧：设置按钮
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                            .frame(width: 20, height: 40, alignment: .trailing)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
