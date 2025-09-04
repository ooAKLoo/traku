//
//  MockDataService.swift
//  统一的Mock数据管理服务
//

import Foundation

// MARK: - Mock数据配置
struct MockConfiguration {
    static let deviceIPRange = "192.168.1."
    static let audioPort = 8888
    static let statusPort = 8889
    static let mockDataIdentifier = "mock audio data"
    static let mockDevicePrefix = "ESP32-"
}

// MARK: - Mock数据管理服务
class MockDataService {
    
    // 单例
    static let shared = MockDataService()
    private init() {}
    
    // MARK: - 设备Mock数据
    
    /// 获取Mock设备列表
    func getMockDevices() -> [DeviceDiscoveryService.DiscoveredDevice] {
        return [
            DeviceDiscoveryService.DiscoveredDevice(
                name: "\(MockConfiguration.mockDevicePrefix)音频设备-1",
                ipAddress: "\(MockConfiguration.deviceIPRange)100",
                port: MockConfiguration.audioPort,
                statusPort: MockConfiguration.statusPort,
                isStreaming: false
            ),
            DeviceDiscoveryService.DiscoveredDevice(
                name: "\(MockConfiguration.mockDevicePrefix)会议室",
                ipAddress: "\(MockConfiguration.deviceIPRange)101",
                port: MockConfiguration.audioPort,
                statusPort: MockConfiguration.statusPort,
                isStreaming: true
            ),
            DeviceDiscoveryService.DiscoveredDevice(
                name: "\(MockConfiguration.mockDevicePrefix)办公室",
                ipAddress: "\(MockConfiguration.deviceIPRange)102",
                port: MockConfiguration.audioPort,
                statusPort: MockConfiguration.statusPort,
                isStreaming: false
            ),
            DeviceDiscoveryService.DiscoveredDevice(
                name: "\(MockConfiguration.mockDevicePrefix)实验室",
                ipAddress: "\(MockConfiguration.deviceIPRange)103",
                port: MockConfiguration.audioPort,
                statusPort: MockConfiguration.statusPort,
                isStreaming: false
            )
        ]
    }
    
    // MARK: - 录音Mock数据
    
    /// 获取Mock录音列表
    func getMockRecordings() -> [AudioRecording] {
        return [
            createMockRecording(
                timeOffset: -3600, // 1小时前
                duration: 45.2,
                transcription: "这是第一段测试录音的转录内容，用于展示应用的基本功能。包含语音识别、文本分析等核心特性。",
                summary: "功能演示录音",
                tags: ["测试", "演示", "功能"],
                audioDataSuffix: "1",
                enrichedContent: createBasicEnrichedContent(title: "应用功能演示", content: "展示了语音录制、转录和分析的完整流程")
            ),
            
            createMockRecording(
                timeOffset: -1800, // 30分钟前
                duration: 62.8,
                transcription: "第二段录音内容，展示了更长的录音时间和更多的文本内容。这段录音包含了复杂的语音模式和多种话题讨论。",
                summary: "长时间录音测试",
                tags: ["长录音", "测试", "复杂"],
                audioDataSuffix: "2",
                enrichedContent: createBasicEnrichedContent(title: "长时间录音分析", content: "演示了系统处理长时间音频的能力")
            ),
            
            createMockRecording(
                timeOffset: -300, // 5分钟前
                duration: 28.5,
                transcription: "嗯，结合大道质简，如何理解真经一句话，假经万卷书。这句话体现了什么样的哲学思想？",
                summary: "理解真经与假经",
                tags: ["哲学", "思考", "真经"],
                audioDataSuffix: "3",
                enrichedContent: createPhilosophyEnrichedContent()
            ),
            
            createMockRecording(
                timeOffset: -120, // 2分钟前
                duration: 15.3,
                transcription: "今天的会议讨论了产品的下一阶段开发计划，重点关注用户体验的改进。",
                summary: "产品会议记录",
                tags: ["会议", "产品", "规划"],
                audioDataSuffix: "4",
                enrichedContent: createBasicEnrichedContent(title: "会议要点", content: "讨论了产品开发的关键要素和用户反馈")
            ),
            
            createMockRecording(
                timeOffset: -60, // 1分钟前
                duration: 33.7,
                transcription: "关于技术架构的重构，我们需要考虑性能优化、代码可维护性以及扩展性等多个方面。",
                summary: "技术架构讨论",
                tags: ["技术", "架构", "重构"],
                audioDataSuffix: "5",
                enrichedContent: createTechEnrichedContent()
            )
        ]
    }
    
    /// 创建单个Mock录音记录
    private func createMockRecording(
        timeOffset: TimeInterval,
        duration: TimeInterval,
        transcription: String,
        summary: String,
        tags: [String],
        audioDataSuffix: String,
        enrichedContent: String
    ) -> AudioRecording {
        return AudioRecording(
            timestamp: Date().addingTimeInterval(timeOffset),
            duration: duration,
            transcription: transcription,
            summary: summary,
            tags: tags,
            audioData: generateMockAudioData(suffix: audioDataSuffix),
            enrichedContent: enrichedContent
        )
    }
    
    // MARK: - 音频数据Mock
    
    /// 生成Mock音频数据
    func generateMockAudioData(suffix: String = "") -> Data {
        let identifier = suffix.isEmpty ? UUID().uuidString : suffix
        return "\(MockConfiguration.mockDataIdentifier) \(identifier)".data(using: .utf8) ?? Data()
    }
    
    /// 检查是否为Mock音频数据
    func isMockAudioData(_ data: Data) -> Bool {
        if let dataString = String(data: data, encoding: .utf8) {
            return dataString.contains(MockConfiguration.mockDataIdentifier)
        }
        return false
    }
    
    /// 获取Mock音频数据的描述信息
    func getMockAudioDataInfo(_ data: Data) -> String? {
        if let dataString = String(data: data, encoding: .utf8),
           dataString.contains(MockConfiguration.mockDataIdentifier) {
            return "模拟音频数据 - \(data.count) 字节"
        }
        return nil
    }
    
    // MARK: - 增强内容Mock数据
    
    /// 创建基础增强内容
    private func createBasicEnrichedContent(title: String, content: String) -> String {
        return """
## 📝 \(title)

### 内容概述
> \(content)

### 关键信息
- **时间**: \(Date().smartFormatted)
- **类型**: 语音录音
- **状态**: 已处理

### 分析结果
- ✅ 语音识别完成
- ✅ 文本分析完成
- ✅ 内容结构化完成

---
*此为演示模式下的模拟数据*
"""
    }
    
    /// 创建哲学思考的增强内容
    private func createPhilosophyEnrichedContent() -> String {
        return """
## 🤔 核心问题
> 如何理解"大道质简"下"真经一句话，假经万卷书"的本质差异？

## 🔍 逻辑梳理

### 前提
> 大道本质是简洁、直指核心的

### 推理过程
1. **第一步推理**  
> 真经因契合大道本质，故以简洁形式承载核心

2. **第二步推理**  
> 假经因偏离本质，需用大量内容堆砌以"显得完整"

3. **第三步推理**  
> 本质差异：真经重核心，假经重形式冗余

### 综合
> 真经以简显真，假经以繁失真，核心在是否契合大道本质

## 👁️ 多维视角
- **视角A**：从内容与形式关系看，内容价值取决于是否触及本质  
- **视角B**：从认知规律看，认知深化常伴随冗余信息的剥离  
- **视角C**：从真实与虚假标准看，虚假知识需依赖冗余掩盖核心缺失  

## 💎 关键洞察
1. **洞察一**："简"是本质的外在体现，"繁"是偏离的内在表现  
2. **洞察二**：真正核心知识往往简洁，冗余多为非本质信息的堆砌  

## 📝 思考总结
> 理解此句需区分"形式简洁"与"本质真实"，警惕冗余信息对核心的遮蔽

---
*基于AI深度分析生成的思维导图*
"""
    }
    
    /// 创建技术讨论的增强内容
    private func createTechEnrichedContent() -> String {
        return """
## 🏗️ 技术架构重构分析

### 核心要素
1. **性能优化**
   - 代码执行效率
   - 内存使用优化
   - 响应时间改进

2. **可维护性**
   - 代码结构清晰
   - 模块化设计
   - 文档完善

3. **扩展性**
   - 接口设计灵活
   - 插件化架构
   - 向后兼容

### 实施建议
- 🔄 渐进式重构，避免大规模改动
- 📊 建立性能监控体系
- 🧪 完善自动化测试覆盖
- 📚 更新技术文档

### 风险评估
- ⚠️ 重构期间的稳定性风险
- 📅 时间成本和人力投入
- 🔒 向下兼容性保证

---
*技术架构分析报告*
"""
    }
    
    // MARK: - 环境检测
    
    /// 检查是否在演示模式
    var isDemoMode: Bool {
        // 可以基于编译配置或环境变量来判断
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// 获取演示模式提示信息
    var demoModeMessage: String {
        return "当前为演示模式，使用模拟数据进行功能展示"
    }
}

// MARK: - Mock数据统计
extension MockDataService {
    
    /// 获取Mock数据统计信息
    var statistics: MockDataStatistics {
        return MockDataStatistics(
            deviceCount: getMockDevices().count,
            recordingCount: getMockRecordings().count,
            totalDuration: getMockRecordings().reduce(0) { $0 + $1.duration },
            dataSize: getMockRecordings().compactMap { $0.audioData }.reduce(0) { $0 + $1.count }
        )
    }
}

// MARK: - Mock数据统计结构
struct MockDataStatistics {
    let deviceCount: Int
    let recordingCount: Int
    let totalDuration: TimeInterval
    let dataSize: Int
    
    var formattedInfo: String {
        return """
        Mock数据统计：
        - 设备数量：\(deviceCount)个
        - 录音数量：\(recordingCount)条
        - 总时长：\(FormatHelper.formatDuration(totalDuration))
        - 数据大小：\(FormatHelper.formatDataSize(Int64(dataSize)))
        """
    }
}