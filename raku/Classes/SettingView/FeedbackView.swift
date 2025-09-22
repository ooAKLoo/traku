//
//  FeedbackView.swift
//  raku
//
//  Created by 杨东举 on 2025/9/17.
//

import SwiftUI
import Lottie

// MARK: - 用户反馈视图
struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    
    @State private var selectedCategory: FeedbackCategory = .feature
    @State private var feedbackText: String = ""
    @State private var contactEmail: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingSuccessAnimation: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 反馈类别选择
                        VStack(alignment: .leading, spacing: 12) {
                            Text("反馈类别")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 8) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    CategoryRowView(
                                        category: category,
                                        isSelected: selectedCategory == category,
                                        isDarkMode: isDarkMode
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // 反馈内容输入
                        VStack(alignment: .leading, spacing: 12) {
                            Text("反馈内容")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(.horizontal, 20)
                            
                            TextEditor(text: $feedbackText)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(.horizontal, 20)
                        }
                        
                        // 联系方式（可选）
                        VStack(alignment: .leading, spacing: 12) {
                            Text("联系方式（可选）")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(.horizontal, 20)
                            
                            TextField("请输入您的联系方式", text: $contactEmail)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(isDarkMode ? .white : .black)
                                .autocapitalization(.none)
                                .padding(.horizontal, 20)
                        }
                        
                        // 提示信息
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                
                                Text("请点击右上角\"提交\"按钮发送反馈")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(L("user_feedback_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitFeedback) {
                        HStack(spacing: 4) {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            }
                            Text(isSubmitting ? "提交中" : "提交")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .foregroundColor(canSubmit ? .blue : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .overlay(
            Group {
                if showingSuccessAnimation {
                    FeedbackSuccessView(
                        isDarkMode: isDarkMode,
                        onDismiss: {
                            showingSuccessAnimation = false
                            dismiss()
                        }
                    )
                }
            }
        )
        .alert("提交失败", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var canSubmit: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitFeedback() {
        guard canSubmit else { return }
        
        isSubmitting = true
        
        let feedback = UserFeedback(
            category: selectedCategory,
            content: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date()
        )
        
        // 提交到后端服务器
        submitToBackend(feedback: feedback)
    }
    
    private func saveFeedbackLocally(_ feedback: UserFeedback) -> Bool {
        // 保存到本地存储
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(feedback)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let feedbacksPath = documentsPath.appendingPathComponent("feedbacks")
            
            if !FileManager.default.fileExists(atPath: feedbacksPath.path) {
                try FileManager.default.createDirectory(at: feedbacksPath, withIntermediateDirectories: true)
            }
            
            let filename = "feedback_\(Int(Date().timeIntervalSince1970)).json"
            let filePath = feedbacksPath.appendingPathComponent(filename)
            
            try data.write(to: filePath)
            return true
        } catch {
            print("保存反馈失败: \(error)")
            return false
        }
    }
    
    private func submitToBackend(feedback: UserFeedback) {
        // Submit feedback directly to Echo app using app name
        let echoAppName = "Echo"
        
        Task {
            do {
                let success = try await submitFeedbackToEchoApp(
                    appName: echoAppName,
                    category: feedback.category.rawValue,
                    content: feedback.content,
                    contactEmail: feedback.contactEmail ?? ""
                )
                
                await MainActor.run {
                    self.isSubmitting = false
                    
                    if success {
                        // 同时保存到本地作为备份
                        _ = self.saveFeedbackLocally(feedback)
                        self.showingSuccessAnimation = true
                    } else {
                        self.errorMessage = "服务器处理失败"
                        self.showingErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    // 网络失败时保存到本地
                    if self.saveFeedbackLocally(feedback) == true {
                        self.errorMessage = "网络连接失败，反馈已保存到本地，将在网络恢复时重试"
                    } else {
                        self.errorMessage = "提交失败: \(error.localizedDescription)"
                    }
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    private func submitFeedbackToEchoApp(appName: String, category: String, content: String, contactEmail: String) async throws -> Bool {
        let url = URL(string: "http://43.143.210.156:5433/api/feedback/\(appName)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "category": category,
            "content": content,
            "contact_email": contactEmail
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        if let responseData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = responseData["success"] as? Bool {
            return success
        }
        
        return false
    }
}

// MARK: - 反馈类别行视图
struct CategoryRowView: View {
    let category: FeedbackCategory
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(category.description)
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.blue.opacity(0.3) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 反馈类别枚举
enum FeedbackCategory: String, CaseIterable, Codable {
    case feature = "feature"
    case bug = "bug"
    case performance = "performance"
    case ui = "ui"
    case other = "other"
    
    var title: String {
        switch self {
        case .feature:
            return "功能建议"
        case .bug:
            return "问题反馈"
        case .performance:
            return "性能问题"
        case .ui:
            return "界面体验"
        case .other:
            return "其他"
        }
    }
    
    var description: String {
        switch self {
        case .feature:
            return "建议新功能或改进现有功能"
        case .bug:
            return "报告应用中的错误或异常"
        case .performance:
            return "反馈应用运行速度或性能问题"
        case .ui:
            return "界面设计或用户体验相关建议"
        case .other:
            return "其他类型的反馈或建议"
        }
    }
    
    var icon: String {
        switch self {
        case .feature:
            return "lightbulb"
        case .bug:
            return "exclamationmark.triangle"
        case .performance:
            return "speedometer"
        case .ui:
            return "paintbrush"
        case .other:
            return "ellipsis.circle"
        }
    }
}

// MARK: - 用户反馈数据模型
struct UserFeedback: Codable {
    let id: UUID
    let category: FeedbackCategory
    let content: String
    let contactEmail: String?
    let timestamp: Date
    
    init(category: FeedbackCategory, content: String, contactEmail: String?, timestamp: Date) {
        self.id = UUID()
        self.category = category
        self.content = content
        self.contactEmail = contactEmail
        self.timestamp = timestamp
    }
}
