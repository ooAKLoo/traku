//
//  LanguageSelectorView.swift
//  raku
//
//  Created by Claude on 2025/9/21.
//

import SwiftUI

// MARK: - 语言选择器视图
struct LanguageSelectorView: View {
    @Binding var isPresented: Bool
    @Binding var currentLanguage: String
    let isDarkMode: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        ForEach(LocalizationData.supportedLanguages, id: \.code) { language in
                            Button(action: {
                                currentLanguage = language.code
                                isPresented = false
                            }) {
                                HStack {
                                    Text(language.flag)
                                        .font(.system(size: 24))
                                        .frame(width: 40)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(language.nativeName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(isDarkMode ? .white : .black)
                                        
                                        Text(language.code)
                                            .font(.system(size: 14))
                                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    if currentLanguage == language.code {
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
                                                    currentLanguage == language.code ? Color.blue.opacity(0.3) : Color.clear,
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