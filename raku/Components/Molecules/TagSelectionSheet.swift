//
//  TagSelectionSheet.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 标签选择半屏 Sheet
struct TagSelectionSheet: View {
    let allTags: [String]
    let allRecordings: [AudioRecording]
    @Binding var selectedTag: String?
    @Binding var isPresented: Bool
    let isDarkMode: Bool
    let getTagCount: (String) -> Int

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // "全部" 选项
                TagGridItem(
                    title: "全部",
                    count: allRecordings.count,
                    isSelected: selectedTag == nil,
                    isDarkMode: isDarkMode
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTag = nil
                        isPresented = false
                    }
                }

                // 各个标签
                ForEach(allTags, id: \.self) { tag in
                    TagGridItem(
                        title: tag,
                        count: getTagCount(tag),
                        isSelected: selectedTag == tag,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTag = tag
                            isPresented = false
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(isDarkMode ? Color.black : Color.appBackground)
    }
}

// MARK: - 标签网格项
struct TagGridItem: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        if isSelected {
            return isDarkMode ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.12)
        } else {
            return isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.96, green: 0.96, blue: 0.97)
        }
    }

    private var textColor: Color {
        if isSelected {
            return isDarkMode ? Color.black : Color.white
        } else {
            return isDarkMode ? Color.white.opacity(0.85) : Color(red: 0.2, green: 0.2, blue: 0.25)
        }
    }

    private var countTextColor: Color {
        if isSelected {
            return isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
        } else {
            return isDarkMode ? Color.white.opacity(0.5) : Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(countTextColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
        }
    }
}
