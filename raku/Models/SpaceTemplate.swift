//
//  SpaceTemplate.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 空间模板数据模型
struct SpaceTemplate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let emoji: String
    let categories: [TemplateCategoryItem]
    
    var categoryCount: Int {
        categories.count
    }
}

// MARK: - 模板类别项模型
struct TemplateCategoryItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TemplateCategoryItem, rhs: TemplateCategoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 预设模板数据
extension SpaceTemplate {
    static let defaultTemplates: [SpaceTemplate] = [
        // 产品灵感库
        SpaceTemplate(
            title: "产品灵感库",
            description: "记录产品想法和用户反馈",
            emoji: "📋",
            categories: [
                TemplateCategoryItem(name: "功能点", emoji: "⚡", color: .blue),
                TemplateCategoryItem(name: "用户反馈", emoji: "💬", color: .green),
                TemplateCategoryItem(name: "竞品亮点", emoji: "🔍", color: .orange),
                TemplateCategoryItem(name: "运营活动", emoji: "🎯", color: .red),
                TemplateCategoryItem(name: "Slogan", emoji: "💡", color: .purple)
            ]
        ),
        
        // 设计灵感库
        SpaceTemplate(
            title: "设计灵感库",
            description: "收集视觉和交互设计灵感",
            emoji: "🎨",
            categories: [
                TemplateCategoryItem(name: "色彩", emoji: "🌈", color: .pink),
                TemplateCategoryItem(name: "排版", emoji: "📝", color: .blue),
                TemplateCategoryItem(name: "交互模式", emoji: "🖱️", color: .green),
                TemplateCategoryItem(name: "图形元素", emoji: "🔷", color: .orange),
                TemplateCategoryItem(name: "灵感来源", emoji: "⚡", color: .purple)
            ]
        ),
        
        // 创业想法池
        SpaceTemplate(
            title: "创业想法池",
            description: "记录商业机会和创新思路",
            emoji: "🚀",
            categories: [
                TemplateCategoryItem(name: "市场机会", emoji: "📈", color: .green),
                TemplateCategoryItem(name: "商业模式", emoji: "💰", color: .yellow),
                TemplateCategoryItem(name: "竞品分析", emoji: "🔎", color: .blue),
                TemplateCategoryItem(name: "MVP功能", emoji: "🚀", color: .red),
                TemplateCategoryItem(name: "融资思路", emoji: "💼", color: .purple)
            ]
        ),
        
        // 学习研究库
        SpaceTemplate(
            title: "学习研究库",
            description: "整理知识和研究思路",
            emoji: "📚",
            categories: [
                TemplateCategoryItem(name: "阅读摘录", emoji: "📖", color: .blue),
                TemplateCategoryItem(name: "研究问题", emoji: "🤔", color: .orange),
                TemplateCategoryItem(name: "实验灵感", emoji: "🧪", color: .green),
                TemplateCategoryItem(name: "论文思路", emoji: "📄", color: .purple),
                TemplateCategoryItem(name: "待查资料", emoji: "🔖", color: .red)
            ]
        ),
        
        // 创作灵感库
        SpaceTemplate(
            title: "创作灵感库",
            description: "记录写作和创作素材",
            emoji: "✍️",
            categories: [
                TemplateCategoryItem(name: "人物设定", emoji: "👤", color: .blue),
                TemplateCategoryItem(name: "情节走向", emoji: "📚", color: .green),
                TemplateCategoryItem(name: "场景描写", emoji: "🏞️", color: .orange),
                TemplateCategoryItem(name: "主题思想", emoji: "💭", color: .purple),
                TemplateCategoryItem(name: "句子片段", emoji: "✨", color: .pink)
            ]
        )
    ]
}