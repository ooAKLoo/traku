//
//  SettingsView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/29.
//

import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("appLanguage") private var appLanguage = "zh-CN"
    @State private var showingDatabaseDebug = false
    @State private var showingAboutView = false
    @State private var showingLanguageSelector = false
    @State private var showingHelpView = false
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 设置选项列表
                    VStack(spacing: 15) {
                        // 外观设置
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                .frame(width: 30)
                            
                            Text(L("settings_appearance_title"))
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Spacer()
                            
                            Picker("", selection: $isDarkMode) {
                                Text(L("settings_theme_dark")).tag(true)
                                Text(L("settings_theme_light")).tag(false)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                        )
                        
                        // 语言设置
                        Button(action: {
                            showingLanguageSelector = true
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text(L("settings_language"))
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Text(getLanguageDisplayName(appLanguage))
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                        }
                        
                        SettingsRowView(icon: "person.circle", title: L("settings_account"), isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "bell", title: L("settings_notifications"), isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "lock", title: L("settings_privacy_title"), isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "questionmark.circle", title: L("common_help"), isDarkMode: isDarkMode, action: {
                            showingHelpView = true
                        })
                        SettingsRowView(icon: "info.circle", title: L("settings_about_title"), isDarkMode: isDarkMode, action: {
                            showingAboutView = true
                        })
                        SettingsRowView(icon: "cylinder", title: L("settings_database_debug"), isDarkMode: isDarkMode, action: {
                            showingDatabaseDebug = true
                        })
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(L("settings_title"))
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
        .sheet(isPresented: $showingDatabaseDebug) {
            DatabaseDebugView()
        }
        .sheet(isPresented: $showingAboutView) {
            AboutWebView(isDarkMode: isDarkMode)
        }
        .sheet(isPresented: $showingLanguageSelector) {
            LanguageSelectorView(
                isPresented: $showingLanguageSelector,
                currentLanguage: $appLanguage,
                isDarkMode: isDarkMode
            )
        }
        .sheet(isPresented: $showingHelpView) {
            HelpView(isDarkMode: isDarkMode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            // 当语言变更时，强制刷新视图
        }
        .onChange(of: appLanguage) { newLanguage in
            LocalizationManager.shared.switchLanguage(to: newLanguage)
        }
    }
    
    // MARK: - Helper Methods
    private func getLanguageDisplayName(_ languageCode: String) -> String {
        switch languageCode {
        case "zh-CN":
            return "简体中文"
        case "en-US":
            return "English"
        default:
            return languageCode
        }
    }
}

// MARK: - 帮助页面
struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        IntroductionSection(isDarkMode: isDarkMode)
                        FeaturesSection(isDarkMode: isDarkMode)
                        TipsSection(isDarkMode: isDarkMode)
                        QuickStartSection(isDarkMode: isDarkMode)
                        
                        Text("我们相信，好的工具应该是透明的 - 你只需要专注于思考本身。")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
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

struct IntroductionSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📝 我们的设计理念")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("这个APP诞生于一个简单的想法：让每一个闪念都不被遗忘，让每一次思考都能沉淀。")
                .font(.system(size: 15))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct FeaturesSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎯 核心功能")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureItem(title: "最近", description: "所有新增内容的聚合地", isDarkMode: isDarkMode)
                FeatureItem(title: "笔记", description: "深度思考的归档，AI帮你结构化整理", isDarkMode: isDarkMode)
                FeatureItem(title: "灵感", description: "碎片创意的集合，围绕项目/主题自动组织", isDarkMode: isDarkMode)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct TipsSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 使用建议")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            VStack(alignment: .leading, spacing: 12) {
                TipItem(number: "1", title: "别纠结分类", description: "直接记录你的想法，系统会自动判断", isDarkMode: isDarkMode)
                TipItem(number: "2", title: "相信AI建议", description: "自动生成的标签和分类通常很准确", isDarkMode: isDarkMode)
                TipItem(number: "3", title: "善用最近", description: "如果不确定内容去哪了，先看最近页面", isDarkMode: isDarkMode)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

struct QuickStartSection: View {
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 快速开始")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
            
            Text("只需点击右下角的 + 按钮，说出或写下你的想法，剩下的交给我们。")
                .font(.system(size: 15))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05))
        )
    }
}

struct FeatureItem: View {
    let title: String
    let description: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
        }
    }
}

struct TipItem: View {
    let number: String
    let title: String
    let description: String
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
        }
    }
}

// MARK: - 语言选择器视图
struct LanguageSelectorView: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    let isDarkMode: Bool
    
    private let availableLanguages = [
        ("zh-CN", "简体中文", "🇨🇳"),
        ("en-US", "English", "🇺🇸")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ForEach(availableLanguages, id: \.0) { (code, name, flag) in
                            Button(action: {
                                currentLanguage = code
                                isPresented = false
                            }) {
                                HStack {
                                    Text(flag)
                                        .font(.system(size: 24))
                                        .frame(width: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(isDarkMode ? .white : .black)
                                        
                                        Text(code)
                                            .font(.system(size: 14))
                                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    if currentLanguage == code {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    currentLanguage == code ? Color.blue.opacity(0.3) : Color.clear,
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .animation(.easeInOut(duration: 0.2), value: currentLanguage)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(L("settings_language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common_done")) {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 关于页面 WebView
struct AboutWebView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    
    var body: some View {
        NavigationView {
            WebView(url: URL(string: "https://ooakloo.top/en/about")!)
                .navigationTitle(L("settings_about_title"))
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

// MARK: - WebView 组件
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - 设置行视图
struct SettingsRowView: View {
    let icon: String
    let title: String
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
            )
        }
    }
}