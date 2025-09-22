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
    @Binding var selectedFilter: String
    @Binding var showingSettings: Bool
    @Binding var hoveredFilter: String?
    @Binding var searchText: String
    @Binding var showingConnectionConfig: Bool
    
    @State private var showingSearchBar = false
    @FocusState private var isSearchFieldFocused: Bool  // 添加聚焦状态
    @State private var isProductReleased = false  // 产品发布状态
    let filters = [L("homepage_filter_tag"), L("homepage_filter_space")]
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部信息栏
            HStack(spacing: 16) {
                if !showingSearchBar {
                    // 左侧产品信息区域（搜索时隐藏）
                    HStack(spacing: 12) {
                        // 产品图片（可点击配置连接）
                        Button(action: {
                            if isProductReleased {
                                showingConnectionConfig = true
                            } else {
                                ToastManager.shared.show(
                                    "产品待发布，敬请期待",
                                    textIcon: "◡̈",
                                    color: .orange
                                )
                            }
                        }) {
                            Image("product")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(isDarkMode ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 产品信息（纯展示，不可点击）
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("homepage_product_name"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            HStack(spacing: 4) {
                                // 连接状态图标
                                Image(systemName: audioManager.isConnected ? "checkmark.circle" : "circle.dotted")
                                    .font(.system(size: 10, weight: audioManager.isConnected ? .light : .medium))
                                    .foregroundColor(audioManager.isConnected ?
                                                     (isDarkMode ? Color.green.opacity(0.8) : Color.green) :
                                                        (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                                
                                Text(audioManager.isConnected ? L("homepage_device_connected") : L("homepage_device_disconnected"))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(audioManager.isConnected ?
                                                     (isDarkMode ? Color.green.opacity(0.8) : Color.green) :
                                                        (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                            }
                        }
                    }
                    .overlay(
                        // 朦胧遮罩层
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.8))
                            .allowsHitTesting(false)
                            .opacity(isProductReleased ? 0 : 1)
                            .animation(.easeInOut(duration: 0.3), value: isProductReleased)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                if showingSearchBar {
                    // 搜索输入框
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
                    Spacer()
                    
                    // 右侧按钮区域（搜索时隐藏）
                    HStack(spacing: 12) {
                        // 搜索按钮
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
                        
                        // 设置按钮
                        Button(action: {
                            showingSettings = true
                        }) {
                            Circle()
                                .fill(isDarkMode ? Color.gray.opacity(0.15) : Color.gray.opacity(0.1))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                                )
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            
            // 第二行：筛选栏
            HStack(spacing: 30) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(filter)
                                .font(.system(size: 16, weight: selectedFilter == filter ? .semibold : .regular))
                                .foregroundColor(selectedFilter == filter ?
                                                 (isDarkMode ? .white : .black) :
                                                    (hoveredFilter == filter ?
                                                     (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                                        (isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))))
                                .animation(.easeInOut(duration: 0.2), value: selectedFilter)
                                .animation(.easeInOut(duration: 0.15), value: hoveredFilter)
                            
                            // 底部指示线
                            ZStack {
                                // 背景透明线条（占位）
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 40, height: 2)
                                
                                // 实际显示的线条
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                (isDarkMode ? Color.white : Color.black).opacity(0.8),
                                                (isDarkMode ? Color.white : Color.black)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 24, height: 2)
                                    .cornerRadius(1)
                                    .scaleEffect(x: selectedFilter == filter ? 1 : 0, y: 1)
                                    .opacity(selectedFilter == filter ? 1 : 0)
                                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: selectedFilter)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredFilter = isHovered ? filter : nil
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
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
        selectedFilter: .constant("标签"),
        showingSettings: .constant(false),
        hoveredFilter: .constant(nil),
        searchText: .constant(""),
        showingConnectionConfig: .constant(false)
    )
}

#Preview("Dark Mode") {
    HomepageHeaderView(
        audioManager: AudioRecordingService(skipDatabaseLoad: true),
        isDarkMode: true,
        selectedFilter: .constant("标签"),
        showingSettings: .constant(false),
        hoveredFilter: .constant(nil),
        searchText: .constant(""),
        showingConnectionConfig: .constant(false)
    )
    .background(Color.black)
}
