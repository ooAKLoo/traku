//
//  homepageHeaderView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 顶部导航栏视图
struct HomepageHeaderView: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    let isDarkMode: Bool
    @Binding var selectedFilter: String
    @Binding var showingSettings: Bool
    @Binding var hoveredFilter: String?
    @Binding var searchText: String
    @Binding var showingConnectionConfig: Bool
    
    @State private var showingSearchBar = false
    let filters = ["全部", "标签"]
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部信息栏
            HStack(spacing: 16) {
                // 左侧产品信息区域
                HStack(spacing: 12) {
                    // 产品图片（可点击配置连接）
                    Button(action: {
                        showingConnectionConfig = true
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
                        Text("Echo o1")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text(audioManager.isConnected ? "已连接" : "未连接")
                            .font(.system(size: 12))
                            .foregroundColor(audioManager.isConnected ? 
                                (isDarkMode ? Color.green.opacity(0.8) : Color.green) : 
                                (isDarkMode ? Color.red.opacity(0.8) : Color.red))
                    }
                }
                
                Spacer()
                
                // 右侧按钮区域
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
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                            )
                    }
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
        .padding(.bottom, 16)
        .background(
            (isDarkMode ? Color.black : Color.white)
        )
    }
}

#Preview("Light Mode") {
    HomepageHeaderView(
        audioManager: AudioManagerAdapter(),
        isDarkMode: false,
        selectedFilter: .constant("全部"),
        showingSettings: .constant(false),
        hoveredFilter: .constant(nil),
        searchText: .constant(""),
        showingConnectionConfig: .constant(false)
    )
}

#Preview("Dark Mode") {
    HomepageHeaderView(
        audioManager: AudioManagerAdapter(),
        isDarkMode: true,
        selectedFilter: .constant("标签"),
        showingSettings: .constant(false),
        hoveredFilter: .constant(nil),
        searchText: .constant(""),
        showingConnectionConfig: .constant(false)
    )
    .background(Color.black)
}
