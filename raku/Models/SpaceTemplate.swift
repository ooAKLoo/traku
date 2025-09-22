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
    static let defaultTemplates1: [SpaceTemplate] = [
        // 产品灵感库
        SpaceTemplate(
            title: "产品灵感库",
            description: L("space_template_feedback_description"),
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


extension SpaceTemplate {
    static let defaultTemplates: [SpaceTemplate] = [
        // 产品（PM）
        SpaceTemplate(
            title: "产品灵感库",
            description: "产品痛点、机会与验证线索",
            emoji: "📋",
            categories: [
                TemplateCategoryItem(name: "痛点", emoji: "🔧", color: .red),
                TemplateCategoryItem(name: "机会", emoji: "📈", color: .green),
                TemplateCategoryItem(name: "功能", emoji: "⚙️", color: .blue),
                TemplateCategoryItem(name: "Slogan", emoji: "💡", color: .purple)
            ]
        ),

        // 视觉/交互（设计师）
        SpaceTemplate(
            title: "设计灵感",
            description: "视觉、交互与参考素材",
            emoji: "🎨",
            categories: [
                TemplateCategoryItem(name: "色彩", emoji: "🌈", color: .pink),
                TemplateCategoryItem(name: "排版", emoji: "✒️", color: .blue),
                TemplateCategoryItem(name: "交互", emoji: "🖱️", color: .green),
                TemplateCategoryItem(name: "参考", emoji: "🔗", color: .orange)
            ]
        ),

        // 创业 / 商业
        SpaceTemplate(
            title: "商业想法",
            description: "市场、商业模式与MVP想法",
            emoji: "🚀",
            categories: [
                TemplateCategoryItem(name: "市场", emoji: "📈", color: .green),
                TemplateCategoryItem(name: "MVP", emoji: "🧩", color: .blue),
                TemplateCategoryItem(name: "模式", emoji: "💰", color: .yellow),
                TemplateCategoryItem(name: "用户", emoji: "👥", color: .purple)
            ]
        ),

        // 学习 / 研究（学生/研究员）
        SpaceTemplate(
            title: "学习笔记",
            description: "阅读摘录、问题与实验想法",
            emoji: "📚",
            categories: [
                TemplateCategoryItem(name: "摘录", emoji: "📖", color: .blue),
                TemplateCategoryItem(name: "问题", emoji: "❓", color: .orange),
                TemplateCategoryItem(name: "方法", emoji: "🧭", color: .green),
                TemplateCategoryItem(name: "资料", emoji: "🔖", color: .red)
            ]
        ),

        // 写作 / 创作（作者）
        SpaceTemplate(
            title: "创作灵感",
            description: "人物、情节与片段收藏",
            emoji: "✍️",
            categories: [
                TemplateCategoryItem(name: "人物", emoji: "👤", color: .blue),
                TemplateCategoryItem(name: "情节", emoji: "📚", color: .green),
                TemplateCategoryItem(name: "场景", emoji: "🏞️", color: .orange),
                TemplateCategoryItem(name: "片段", emoji: "✨", color: .pink)
            ]
        ),

        // 个人/生活灵感（日常）
        SpaceTemplate(
            title: "个人灵感",
            description: "生活感悟、好句子与习惯记录",
            emoji: "💭",
            categories: [
                TemplateCategoryItem(name: "感悟", emoji: "☕", color: .yellow),
                TemplateCategoryItem(name: "金句", emoji: "💬", color: .purple),
                TemplateCategoryItem(name: "习惯", emoji: "🔁", color: .green)
            ]
        ),

        // 运营 / 增长
        SpaceTemplate(
            title: "运营策划",
            description: "活动、拉新与转化想法",
            emoji: "🎯",
            categories: [
                TemplateCategoryItem(name: "活动", emoji: "📣", color: .red),
                TemplateCategoryItem(name: "流量", emoji: "🌊", color: .blue),
                TemplateCategoryItem(name: "转化", emoji: "💸", color: .green)
            ]
        ),

        // 用户 & 问题收集
        SpaceTemplate(
            title: "用户声音",
            description: "反馈、Bug 与改进建议",
            emoji: "🗣️",
            categories: [
                TemplateCategoryItem(name: "反馈", emoji: "💬", color: .green),
                TemplateCategoryItem(name: "Bug", emoji: "🐞", color: .red),
                TemplateCategoryItem(name: "改进", emoji: "🔧", color: .orange)
            ]
        ),

        // 会议 / 项目跟进
        SpaceTemplate(
            title: "会议与任务",
            description: "决议、任务与待跟进项",
            emoji: "📝",
            categories: [
                TemplateCategoryItem(name: "决议", emoji: "✅", color: .green),
                TemplateCategoryItem(name: "任务", emoji: "🗂️", color: .blue),
                TemplateCategoryItem(name: "跟进", emoji: "🔁", color: .purple)
            ]
        )
    ]
}
