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
    @State private var showingDataImport = false
    @State private var showingDataExport = false
    @State private var showingTagManagement = false
    @State private var showingFeedback = false
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
                                
                                Text(LocalizationData.getDisplayName(for: appLanguage))
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
                        
                        SettingsRowView(icon: "tag", title: L("settings_tag_management"), isDarkMode: isDarkMode, action: {
                            showingTagManagement = true
                        })
                        SettingsRowView(icon: "square.and.arrow.down", title: L("settings_data_import"), isDarkMode: isDarkMode, action: {
                            showingDataImport = true
                        })
                        SettingsRowView(icon: "square.and.arrow.up", title: L("settings_data_export"), isDarkMode: isDarkMode, action: {
                            showingDataExport = true
                        })
                        SettingsRowView(icon: "questionmark.circle", title: L("common_help"), isDarkMode: isDarkMode, action: {
                            showingHelpView = true
                        })
                        SettingsRowView(icon: "window.ceiling", title: L("settings_feedback"), isDarkMode: isDarkMode, action: {
                            showingFeedback = true
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
        .sheet(isPresented: $showingDataImport) {
            DataImportProgressView(isDarkMode: isDarkMode, isPresented: $showingDataImport)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView(isDarkMode: isDarkMode, isPresented: $showingDataExport)
        }
        .sheet(isPresented: $showingTagManagement) {
            TagManagementView(isDarkMode: isDarkMode)
        }
        .sheet(isPresented: $showingFeedback) {
            FeedbackView(isDarkMode: isDarkMode)
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            // 当语言变更时，强制刷新视图
        }
        .onChange(of: appLanguage) { newLanguage in
            LocalizationManager.shared.switchLanguage(to: newLanguage)
        }
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
