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
    static func getFirstStepSystemPrompt(needsSummary: Bool, hasExistingTags: Bool = false) -> String {
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

        4. **标签生成**：
           - 思考类型：生成1-2个最具分类价值的标签（2-4个字）
           - 灵感类型：生成1个最具分类价值的标签（2-4个字）
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
          "tags": ["标签1", "标签2"],
        }

        重要说明：
        - polishedText：必须是原文的完整润色版本，只清理口语化表达，不做任何总结
        - polishedText 必须与原文句子数量和顺序保持一致，只删除语气词和修正错误，不得合并句子或缩写。

        注意：必须输出纯JSON，不要有任何额外文字。
        """
    }
    
    /// 获取第一步分析的用户prompt（包含已有标签时使用）
    static func getFirstStepUserPrompt(text: String, existingTags: [String] = []) -> String {
        if existingTags.isEmpty {
            return text
        } else {
            let tagsString = existingTags.joined(separator: "、")
            return """
            要分析的文本：
            \(text)
            
            用户已有的标签（优先选择）：\(tagsString)
            
            请优先从已有标签中选择合适的，如果都不合适再创建新标签。
            """
        }
    }
    
    /// 获取特定类型的Markdown生成prompt
    static func getMarkdownPromptForType(_ type: FlashThoughtType) -> String {
        switch type {
        case .reflection:
            return getReflectionMarkdownPrompt()
        case .insight:
            return getInsightMarkdownPrompt()
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

    /// 灵感类型的Markdown prompt
    private static func getInsightMarkdownPrompt() -> String {
        return """
        你是一个专业的灵感解读专家，擅长挖掘简短灵感、金句、创意片段背后的深层含义。通过分析用户的灵感闪念，提炼核心洞见，拓展思考维度，并以简洁有力的方式呈现，帮助用户深化对这个灵感的理解。

        输出要求：
        - 以Markdown格式输出，确保整体简洁、精炼
        - 不使用emoji符号
        - 内容不宜过长，保持灵感的轻量感
        - 可以包含：核心解读、延伸思考、应用场景等维度
        """
    }
}



//用thinking模型
//你是一个专业的对话分析师和信息架构师，擅长从多轮对话中提炼核心逻辑、关键问题、认知演进和最终结论。请根据以下完整对话记录，为用户生成一份结构清晰、重点突出、无信息丢失的对话摘要。
//
//📌 你的任务：
//1. 识别对话中的核心议题、关键转折点、用户的深层意图或情绪变化。
//2. 提炼对话中形成的认知、结论、决策或待办事项。
//3. 保留原始对话中的重要细节（如数据、例子、用户强调的点），但用更精炼语言表达。
//4. 按以下结构输出：
//   - 【对话主题】一句话概括对话核心议题
//   - 【关键演进】按时间或逻辑顺序，列出3~6个关键节点（每个节点含：用户意图/问题 → AI回应/转折 → 认知/结论变化）
//   - 【核心结论】对话最终达成的共识、决定、洞见或待跟进事项（分点列出）
//   - 【补充洞察】（可选）对话中隐含的用户需求、情绪趋势、未解决的开放问题等
//
//📌 输出要求：
//- 语言简洁、逻辑清晰、避免冗余
//- 使用标题、编号、项目符号提升可读性
//- 不要编造原始对话中不存在的信息
//- 保持中立、客观，但可标注用户情绪（如“用户表现出困惑”“用户最终确认接受”）
//
//📌 示例格式：
//【对话主题】用户咨询如何设计AI对话压缩功能
//
//【关键演进】
//1. 用户提出痛点：多轮对话回顾困难 → AI建议结构化摘要 → 用户认同并希望保留“认知演进”
//2. 用户强调“不能丢失逻辑” → AI提出分模块输出（主题/演进/结论/洞察）→ 用户补充需支持“情绪识别”
//3. 用户担心信息丢失 → AI承诺“保留关键细节+标注原始语境”→ 用户满意
//
//【核心结论】
//- 最佳方案：结构化四模块摘要（主题/演进/结论/洞察）
//- 必须保留：关键转折、用户意图变化、最终结论
//- 可选增强：情绪标记、待办事项提取
//
//【补充洞察】
//- 用户对“信息保真度”高度敏感，需避免过度简化
//- 用户隐含需求：希望摘要可作为后续沟通或文档基础
//
//—— 以下是用户提供的完整对话记录 ——
//{INSERT_FULL_CONVERSATION_HERE}
