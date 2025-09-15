//
//  GlobalPopupManager.swift
//  raku
//
//  Created by Assistant on 2025/1/16.
//  全局浮窗管理器 - 用于管理应用中的全局浮窗状态
//

import SwiftUI
import Combine

// MARK: - 浮窗数据模型
public struct PopupItem: Identifiable {
    public let id = UUID()
    public let message: String
    public let type: PopupType
    public var duration: TimeInterval = 3.0
    public var action: (() -> Void)?
    
    public init(message: String, type: PopupType = .info, duration: TimeInterval = 3.0, action: (() -> Void)? = nil) {
        self.message = message
        self.type = type
        self.duration = duration
        self.action = action
    }
}

// MARK: - 浮窗类型
public enum PopupType {
    case success
    case error
    case warning
    case info
    case custom(icon: String, color: Color)
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .custom(let icon, _):
            return icon
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        case .custom(_, let color):
            return color
        }
    }
}

// MARK: - 批量选择数据模型
public struct BatchSelectionData {
    public let selectedCount: Int
    public let totalCount: Int
    public let actionTitle: String
    public let actionIcon: String
    public let onSelectAll: () -> Void
    public let onDeselectAll: () -> Void
    public let onAction: () -> Void
    
    public init(
        selectedCount: Int,
        totalCount: Int,
        actionTitle: String = "添加到空间",
        actionIcon: String = "plus.circle.fill",
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void,
        onAction: @escaping () -> Void
    ) {
        self.selectedCount = selectedCount
        self.totalCount = totalCount
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.onSelectAll = onSelectAll
        self.onDeselectAll = onDeselectAll
        self.onAction = onAction
    }
}

// MARK: - 全局浮窗管理器
class GlobalPopupManager: ObservableObject {
    // 单例实例
    static let shared = GlobalPopupManager()
    
    // 当前显示的浮窗
    @Published var currentPopup: PopupItem?
    @Published var isShowing: Bool = false
    
    // 批量选择工具栏状态
    @Published var batchSelectionData: BatchSelectionData?
    @Published var isBatchSelectionShowing: Bool = false
    
    // 浮窗队列（可选功能）
    private var popupQueue: [PopupItem] = []
    private var dismissTimer: Timer?
    
    private init() {}
    
    // MARK: - 通用浮窗方法
    func show(
        message: String,
        type: PopupType = .info,
        duration: TimeInterval = 3.0,
        action: (() -> Void)? = nil
    ) {
        DispatchQueue.main.async {
            self.currentPopup = PopupItem(
                message: message,
                type: type,
                duration: duration,
                action: action
            )
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                self.isShowing = true
            }
            
            // 自动消失计时器
            self.dismissTimer?.invalidate()
            if duration > 0 {
                self.dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                    self.dismiss()
                }
            }
        }
    }
    
    func dismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            self.isShowing = false
        }
        
        // 延迟清理数据，让动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentPopup = nil
        }
        
        self.dismissTimer?.invalidate()
    }
    
    // MARK: - 批量选择工具栏方法
    func showBatchSelection(_ data: BatchSelectionData) {
        DispatchQueue.main.async {
            self.batchSelectionData = data
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0)) {
                self.isBatchSelectionShowing = true
            }
        }
    }
    
    
    func hideBatchSelection() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            self.isBatchSelectionShowing = false
        }
        
        // 延迟清理数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.batchSelectionData = nil
        }
    }
    
    // MARK: - 便捷方法
    func showSuccess(_ message: String, duration: TimeInterval = 2.0) {
        show(message: message, type: .success, duration: duration)
    }
    
    func showError(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .error, duration: duration)
    }
    
    func showWarning(_ message: String, duration: TimeInterval = 2.5) {
        show(message: message, type: .warning, duration: duration)
    }
    
    func showInfo(_ message: String, duration: TimeInterval = 2.0) {
        show(message: message, type: .info, duration: duration)
    }
}