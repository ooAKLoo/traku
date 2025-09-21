//
//  DeleteSpaceView.swift
//  raku
//
//  Created by Assistant on 2025/9/21.
//

import SwiftUI

// MARK: - 删除空间确认视图
struct DeleteSpaceView: View {
    let space: Space
    let isDarkMode: Bool
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.8))
            
            // 标题
            Text("确认删除")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            // 描述
            VStack(spacing: 8) {
                Text("确定要删除空间")
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                Text("\"\(space.name)\"")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("吗？")
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
            }
            
            Text("此操作将删除该空间下的所有内容，且无法恢复。")
                .font(.system(size: 14))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 按钮
            HStack(spacing: 16) {
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                }
                
                Button(action: onDelete) {
                    Text("删除")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                        )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color(hex: "1C1C1E") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}