//
//  LLMConfiguration.swift
//  raku
//
//  Created by 杨东举 on 2025/9/2.
//  配置文件：LLM统一配置
//

import Foundation

// MARK: - 两步式LLM配置
struct TwoStepLLMConfiguration {
    let apiURL: String
    let apiKey: String
    let liteModel: String  // 用于分类和标题生成
    let flashModel: String // 用于生成辅助内容
    let timeout: TimeInterval
    
    static let `default` = TwoStepLLMConfiguration(
        apiURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        apiKey: "7dda38f8-2383-434c-9d8d-a26263d4b5d1",
        liteModel: "doubao-1-5-lite-32k-250115",
//        flashModel: "doubao-seed-1-6-flash-250715",
//        flashModel: "doubao-seed-1-6-thinking-250715",
        flashModel: "doubao-seed-1-6-250615",
        timeout: 300.0
    )
}

// MARK: - 闪念类型枚举
enum FlashThoughtType: String, CaseIterable {
    case reflection = "思考"
    case insight = "灵感"
    case unknown = "未分类"
    
    var promptKey: String {
        switch self {
        case .reflection:
            return "reflection"
        case .insight:
            return "insight"
        case .unknown:
            return "general"
        }
    }
}

// MARK: - 错误类型
enum TwoStepLLMError: Error, LocalizedError {
    case invalidURL
    case requestError(Error)
    case networkError(Error)
    case apiError(code: Int, message: String)
    case parseError
    case emptyResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的API URL"
        case .requestError(let error):
            return "请求错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 \(code): \(message)"
        case .parseError:
            return "响应解析错误"
        case .emptyResponse:
            return "响应数据为空"
        case .timeout:
            return "请求超时"
        }
    }
}

// MARK: - Prompt配置
struct LLMPromptConfiguration {
    
    /// 获取第一步分析的系统prompt
    static func getFirstStepSystemPrompt(needsSummary: Bool) -> String {
        return """
        你是一个精准的闪念分类助手。请严格按照以下要求处理用户asr处理后的输入内容：

        1. **ASR文本矫正（用于polishedText字段）**：
           - 必须完整保留原文的所有句子和观点，不能遗漏或合并
           - 删除语气词（如"呃"、"嗯"、"就是"、"然后"、"Yeah"等）
           - 修正明显的ASR错误（包括常见成语、短语、词语识别错误）
           - 保持原句的数量和顺序，不得缩写或改写意思
           
        2. **类型判定**（请根据语义判断，必须选择其一）：
           - 思考(reflection)：深度思考、疑问探索、矛盾分析
           -灵感型（insight）：点子、slogan、金句、顿悟、引用、创意片段、简短的陈述语句
           示例：
            输入: "找合作伙伴不等于找朋友"
            输出: {"type": "insight"}
            
            输入: "人生得到无穷已，江月年年望相似"
            输出: {"type": "insight"}
            
            输入: "为什么我感觉找合作伙伴和找朋友有时候矛盾？"
            输出: {"type": "reflection"}

        3. **生成标题**：
           - 提取核心内容，生成20字以内的概括标题
           - 保持原意，不过度概括

        4. **标签生成（仅一个）**：
           - 生成**唯一一个**最具分类价值的标签（2-4个字）
           - 标签必须满足：
             •能作为长期知识管理的聚合维度（如“合作观”、“时间管理”、“认知偏差”）
             • 避免过于具体或一次性词汇（如“张三项目”、“昨天会议”）
             • 优先选择主题域、思维模式、情绪状态、功能类型等可复用维度
             • 必须高度概括内容本质，便于未来检索与归类

        输出格式要求（严格JSON）：
        {
          "polishedText": "完整的润色后文本（去除口语词但保留所有内容）",
          "title": "简洁标题",
          "type": "reflection",
          "tags": ["唯一标签"],
        }

        重要说明：
        - polishedText：必须是原文的完整润色版本，只清理口语化表达，不做任何总结
        - polishedText 必须与原文句子数量和顺序保持一致，只删除语气词和修正错误，不得合并句子或缩写。

        注意：必须输出纯JSON，不要有任何额外文字。
        """
    }
    
    /// 获取特定类型的Markdown生成prompt
    static func getMarkdownPromptForType(_ type: FlashThoughtType) -> String {
        switch type {
        case .reflection:
            return getReflectionMarkdownPrompt()
        case .insight:
            // 灵感类型不需要生成Markdown，直接返回空字符串
            return ""
        case .unknown:
            return getGeneralMarkdownPrompt()
        }
    }
    
    /// 思考类型的Markdown prompt
    private static func getReflectionMarkdownPrompt() -> String {
        return """
        你是一个专业的思维整理专家，擅长使用金字塔原理（Pyramid Principle）来结构化杂乱的想法，帮助人们深化和闭环他们的思考。通过分析用户的初步想法，提炼核心要素，串联逻辑，并以人性化、自然流畅的方式呈现，帮助用户获得更清晰的洞见和行动启发。

        输出要求：
        - 以Markdown格式输出，确保整体简洁、易读，避免学术化。
        - 不使用emoji符号。
        """
    }
    
    /// 通用类型的Markdown prompt
    private static func getGeneralMarkdownPrompt() -> String {
        return """
        你是一个专业的思维整理专家，擅长使用金字塔原理（Pyramid Principle）来结构化杂乱的想法，帮助人们深化和闭环他们的思考。通过分析用户的初步想法，提炼核心要素，串联逻辑，并以人性化、自然流畅的方式呈现，帮助用户获得更清晰的洞见和行动启发。

        输出要求：
        - 以Markdown格式输出，确保整体简洁、易读，避免学术化。
        - 不使用emoji符号。
        """
    }
}
