//
//  ASRStage.swift
//  raku
//
//  语音识别阶段
//

import Foundation

final class ASRStage: ProcessingStage {
    let name = "语音识别"
    private let speechService: VolcEngineSpeechService

    init(speechService: VolcEngineSpeechService = VolcEngineSpeechService()) {
        self.speechService = speechService
    }

    func process(_ context: ProcessingContext) async throws -> ProcessingContext {
        print("🎤 [\(name)] 开始处理音频数据，大小: \(context.audioData.count / 1024) KB")

        return try await withCheckedThrowingContinuation { continuation in
            // 创建临时delegate来接收结果
            let handler = ASRResultHandler { result in
                var updatedContext = context
                updatedContext.transcription = result.text
                print("🎤 [\(self.name)] 识别完成: \(result.text.prefix(50))...")
                continuation.resume(returning: updatedContext)
            } onError: { error in
                print("❌ [\(self.name)] 识别失败: \(error?.localizedDescription ?? "未知错误")")
                continuation.resume(throwing: ProcessingStageError.asrFailed(error ?? NSError(domain: "ASR", code: -1)))
            }

            // 设置handler为delegate
            self.speechService.delegate = handler
            // 保持handler引用
            objc_setAssociatedObject(self.speechService, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

            // 处理音频
            self.speechService.processRecordingAudio(context.audioData, duration: context.duration)
        }
    }
}

// MARK: - ASR结果处理器
private class ASRResultHandler: NSObject, VolcEngineSpeechServiceDelegate {
    private let onResult: (SpeechRecognitionResult) -> Void
    private let onError: (Error?) -> Void
    private var hasCompleted = false

    init(onResult: @escaping (SpeechRecognitionResult) -> Void, onError: @escaping (Error?) -> Void) {
        self.onResult = onResult
        self.onError = onError
        super.init()
    }

    func speechService(_ service: VolcEngineSpeechService, didReceiveResult result: SpeechRecognitionResult) {
        guard !hasCompleted else { return }
        hasCompleted = true
        onResult(result)
    }

    func speechService(_ service: VolcEngineSpeechService, didCompleteWithError error: Error?) {
        guard !hasCompleted else { return }
        if let error = error {
            hasCompleted = true
            onError(error)
        }
    }

    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService) {}
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService) {}
}
