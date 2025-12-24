//
//  GlobalPopupView.swift
//  raku
//
//  Created by Assistant on 2025/1/16.
//  全局浮窗视图 - 显示在屏幕底部的全局浮窗组件
//

import SwiftUI

// MARK: - 全局浮窗视图
struct GlobalPopupView: View {
    @EnvironmentObject var popupManager: GlobalPopupManager
    @Environment(\.colorScheme) var colorScheme
    
    var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear

                // 通用浮窗
                if let popup = popupManager.currentPopup, popupManager.isShowing {
                    popupContent(popup, geometry: geometry)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                // 注意：批量选择工具栏已迁移到各页面内部管理（如 RecordingDetailView）
                // 不再在全局浮窗中渲染，以实现更好的动画协调
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - 通用浮窗内容
    private func popupContent(_ popup: PopupItem, geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // 图标
                Image(systemName: popup.type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(popup.type.color)
                
                // 消息
                Text(popup.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // 操作按钮（如果有）
                if popup.action != nil {
                    Button(action: {
                        popup.action?()
                        popupManager.dismiss()
                    }) {
                        Text("查看")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(popup.type.color)
                    }
                }
                
                // 关闭按钮
                Button(action: {
                    popupManager.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.black : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(popup.type.color.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(isDarkMode ? 0.5 : 0.15),
                        radius: 20,
                        x: 0,
                        y: -5
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
        }
    }
}

