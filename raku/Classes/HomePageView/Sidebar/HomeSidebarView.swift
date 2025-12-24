//
//  HomeSidebarView.swift
//  raku
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

// MARK: - 首页侧边栏视图 (Linear 风格)
struct HomeSidebarView: View {
    @ObservedObject var audioManager: AudioRecordingService
    @Binding var isPresented: Bool
    @Binding var showingSettings: Bool
    let isDarkMode: Bool

    @State private var showingConnectionConfig = false

    private var sidebarWidth: CGFloat { 280 }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景遮罩 - 更柔和的模糊效果
                if isPresented {
                    Color.black
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                isPresented = false
                            }
                        }
                        .transition(.opacity)
                }

                // 侧边栏内容
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部 Logo 区域
                        SidebarLogoSection(isDarkMode: isDarkMode)

                        // 分隔线
                        SidebarDivider(isDarkMode: isDarkMode)
                            .padding(.top, 8)

                        // 设备区域
                        SidebarSection(title: "设备", isDarkMode: isDarkMode) {
                            DeviceRow(
                                audioManager: audioManager,
                                isDarkMode: isDarkMode
                            ) {
                                showingConnectionConfig = true
                            }
                        }
                        .padding(.top, 16)

                        Spacer()

                        // 底部区域
                        SidebarBottomSection(isDarkMode: isDarkMode) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingSettings = true
                            }
                        }
                    }
                    .frame(width: sidebarWidth)
                    .background(
                        // Linear 风格的背景
                        isDarkMode ?
                            Color(red: 0.067, green: 0.067, blue: 0.078) :
                            Color(red: 0.98, green: 0.98, blue: 0.99)
                    )
                    .offset(x: isPresented ? 0 : -sidebarWidth)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingConnectionConfig) {
            ConnectionConfigView(audioManager: audioManager)
        }
    }
}

// MARK: - Logo 区域
private struct SidebarLogoSection: View {
    let isDarkMode: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Logo
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.35, blue: 0.95),
                            Color(red: 0.55, green: 0.35, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Text("R")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )

            Text("Raku")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }
}

// MARK: - 分隔线
private struct SidebarDivider: View {
    let isDarkMode: Bool

    var body: some View {
        Rectangle()
            .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - 区块容器
private struct SidebarSection<Content: View>: View {
    let title: String
    let isDarkMode: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 区块标题
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

            content
        }
    }
}

// MARK: - 设备行
private struct DeviceRow: View {
    @ObservedObject var audioManager: AudioRecordingService
    let isDarkMode: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 设备图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                        .frame(width: 36, height: 36)

                    Image("product")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                }

                // 设备信息
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("homepage_product_name"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))

                    HStack(spacing: 5) {
                        // 状态指示点
                        Circle()
                            .fill(audioManager.isConnected ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color(red: 0.55, green: 0.55, blue: 0.58))
                            .frame(width: 6, height: 6)

                        Text(audioManager.isConnected ? L("homepage_device_connected") : L("homepage_device_disconnected"))
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                    }
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.25) : Color.black.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ?
                        (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04)) :
                        Color.clear
                    )
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 底部区域
private struct SidebarBottomSection: View {
    let isDarkMode: Bool
    let onSettingsTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            SidebarDivider(isDarkMode: isDarkMode)

            Button(action: onSettingsTap) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.5))

                    Text("设置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.7))

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ?
                            (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.06)) :
                            (isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Preview
#Preview("Light Mode") {
    HomeSidebarView(
        audioManager: AudioRecordingService(skipDatabaseLoad: true),
        isPresented: .constant(true),
        showingSettings: .constant(false),
        isDarkMode: false
    )
}

#Preview("Dark Mode") {
    HomeSidebarView(
        audioManager: AudioRecordingService(skipDatabaseLoad: true),
        isPresented: .constant(true),
        showingSettings: .constant(false),
        isDarkMode: true
    )
    .background(Color.black)
}
