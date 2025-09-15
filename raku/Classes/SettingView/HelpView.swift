//
//  HelpView.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 帮助页面
struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        IntroductionSection(isDarkMode: isDarkMode)
                        FeaturesSection(isDarkMode: isDarkMode)
                        TipsSection(isDarkMode: isDarkMode)
                        QuickStartSection(isDarkMode: isDarkMode)
                        
                        Text("我们相信，好的工具应该是透明的 - 你只需要专注于思考本身。")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle(L("common_help"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common_done")) {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct IntroductionSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📝 我们的设计理念")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("这个APP诞生于一个简单的想法：让每一个闪念都不被遗忘，让每一次思考都能沉淀。")
                .font(.system(size: 15))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct FeaturesSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 核心功能")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureItem(title: "最近", description: "所有新增内容的聚合地", isDarkMode: isDarkMode)
                FeatureItem(title: "笔记", description: "深度思考的归档，AI帮你结构化整理", isDarkMode: isDarkMode)
                FeatureItem(title: "灵感", description: "碎片创意的集合，围绕项目/主题自动组织", isDarkMode: isDarkMode)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct TipsSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 使用建议")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            VStack(alignment: .leading, spacing: 12) {
                TipItem(number: "1", title: "别纠结分类", description: "直接记录你的想法，系统会自动判断", isDarkMode: isDarkMode)
                TipItem(number: "2", title: "相信AI建议", description: "自动生成的标签和分类通常很准确", isDarkMode: isDarkMode)
                TipItem(number: "3", title: "善用最近", description: "如果不确定内容去哪了，先看最近页面", isDarkMode: isDarkMode)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct QuickStartSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 快速开始")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("只需点击右下角的 + 按钮，说出或写下你的想法，剩下的交给我们。")
                .font(.system(size: 15))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05))
        )
    }
}

struct FeatureItem: View {
    let title: String
    let description: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
        }
    }
}

struct TipItem: View {
    let number: String
    let title: String
    let description: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
        }
    }
}