//
//  HelpView.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 功能数据模型
struct CoreFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct QuickStartStep: Identifiable {
    let id = UUID()
    let number: String
    let title: String
    let description: String
}

// MARK: - 帮助页面
struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    
    private let features = [
        CoreFeature(
            icon: "mic",
            title: "语音捕捉",
            description: "一键录制，随时随地记录你的思考"
        ),
        CoreFeature(
            icon: "brain.head.profile",
            title: "智能整理",
            description: "AI自动分类和标签，让想法井然有序"
        ),
        CoreFeature(
            icon: "magnifyingglass",
            title: "语义搜索",
            description: "理解你的意图，找到相关内容而非关键词匹配"
        )
    ]
    
    private let quickStartSteps = [
        QuickStartStep(
            number: "1",
            title: "点击录制",
            description: "轻触麦克风按钮开始记录"
        ),
        QuickStartStep(
            number: "2", 
            title: "说出想法",
            description: "自然表达你的思考和灵感"
        ),
        QuickStartStep(
            number: "3",
            title: "自动整理",
            description: "AI生成标题和标签分类"
        ),
        QuickStartStep(
            number: "4",
            title: "查找回顾",
            description: "通过搜索快速定位内容"
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 1. 产品理念区
                    ProductVisionSection(isDarkMode: isDarkMode)
                        .padding(.vertical, 60)
                    
                    Divider()
                        .opacity(0.3)
                        .padding(.horizontal, 40)
                    
                    // 2. 核心功能区
                    CoreFeaturesSection(features: features, isDarkMode: isDarkMode)
                        .padding(.vertical, 60)
                    
                    // 3. 快速开始区
                    QuickStartSection(steps: quickStartSteps, isDarkMode: isDarkMode)
                        .padding(.vertical, 60)
                        .background(
                            (isDarkMode ? Color.white.opacity(0.02) : Color.gray.opacity(0.02))
                                .ignoresSafeArea()
                        )
                    
                    // 4. 底部留白
                    Spacer()
                        .frame(height: 40)
                }
            }
            .background(isDarkMode ? Color.black : Color.white)
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

// MARK: - 产品理念区
struct ProductVisionSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Text("让思考发生")
                .font(.largeTitle.weight(.thin))
                .tracking(2)
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("捕捉每一个灵感瞬间")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - 核心功能区
struct CoreFeaturesSection: View {
    let features: [CoreFeature]
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("核心功能")
                .font(.title2.weight(.medium))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.bottom, 40)
            
            VStack(spacing: 32) {
                ForEach(features) { feature in
                    HStack(spacing: 20) {
                        Image(systemName: feature.icon)
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.headline)
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Text(feature.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

// MARK: - 快速开始区
struct QuickStartSection: View {
    let steps: [QuickStartStep]
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("快速开始")
                .font(.title2.weight(.medium))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.bottom, 40)
            
            VStack(spacing: 24) {
                ForEach(steps) { step in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                                .frame(width: 32, height: 32)
                            
                            Text(step.number)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Text(step.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

// MARK: - 预览
#Preview {
    HelpView(isDarkMode: false)
}

#Preview("Dark Mode") {
    HelpView(isDarkMode: true)
}