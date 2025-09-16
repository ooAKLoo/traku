//
//  TagManagementView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI

struct TagManagementView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingMergeView = false
    @State private var showingSplitView = false
    @State private var allTags: [String] = []
    @State private var tagUsageCount: [String: Int] = [:]
    
    private let databaseManager = DatabaseManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 15) {
                        // 合并标签
                        Button(action: {
                            showingMergeView = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text("合并标签")
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
                        
                        // 拆分标签
                        Button(action: {
                            showingSplitView = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text("拆分标签")
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
                        
                        // 标签统计
                        TagStatisticsView(
                            allTags: allTags,
                            tagUsageCount: tagUsageCount,
                            isDarkMode: isDarkMode
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("标签管理")
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
        .sheet(isPresented: $showingMergeView) {
            TagMergeView(
                allTags: allTags,
                tagUsageCount: tagUsageCount,
                isDarkMode: isDarkMode,
                isPresented: $showingMergeView,
                onTagsUpdated: loadTagData
            )
        }
        .sheet(isPresented: $showingSplitView) {
            TagSplitView(
                allTags: allTags,
                tagUsageCount: tagUsageCount,
                isDarkMode: isDarkMode,
                isPresented: $showingSplitView,
                onTagsUpdated: loadTagData
            )
        }
        .onAppear {
            loadTagData()
        }
    }
    
    private func loadTagData() {
        let recordings = databaseManager.loadRecordings()
        
        var tagCount: [String: Int] = [:]
        var uniqueTags: Set<String> = []
        
        for recording in recordings {
            for tag in recording.tags {
                uniqueTags.insert(tag)
                tagCount[tag, default: 0] += 1
            }
        }
        
        allTags = Array(uniqueTags).sorted()
        tagUsageCount = tagCount
    }
}

struct TagStatisticsView: View {
    let allTags: [String]
    let tagUsageCount: [String: Int]
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text("标签统计")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            if allTags.isEmpty {
                Text("暂无标签")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Text("\(tagUsageCount[tag] ?? 0)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white.opacity(0.7))
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}