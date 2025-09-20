//
//  ASRConfiguration.swift
//  ASR开发配置 - 生产环境模型选择
//

import Foundation

// MARK: - ASR开发配置
struct ASRConfiguration {
    
    /// 生产环境使用的ASR模型
    /// 修改此值来切换生产环境使用的模型
    static let defaultModel: ASRModelType = .doubao
}
