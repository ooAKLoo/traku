//
//  TagSelectionSheet.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 标签排序方式
enum TagSortOption: String, CaseIterable {
    case nameAsc = "名称 A-Z"
    case nameDesc = "名称 Z-A"
    case countDesc = "数量最多"
    case countAsc = "数量最少"

    /// 用于持久化存储的 key
    static let storageKey = "tagSortOption"
}

// MARK: - 标签选择半屏 Sheet
struct TagSelectionSheet: View {
    let allTags: [String]
    let allRecordings: [AudioRecording]
    @Binding var selectedTag: String?
    @Binding var isPresented: Bool
    let isDarkMode: Bool
    let getTagCount: (String) -> Int

    @AppStorage(TagSortOption.storageKey) private var sortOptionRaw: String = TagSortOption.countDesc.rawValue

    private var sortOption: TagSortOption {
        get { TagSortOption(rawValue: sortOptionRaw) ?? .countDesc }
    }

    private func setSortOption(_ option: TagSortOption) {
        sortOptionRaw = option.rawValue
    }

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var sortedTags: [String] {
        switch sortOption {
        case .nameAsc:
            return allTags.sorted { $0.localizedCompare($1) == .orderedAscending }
        case .nameDesc:
            return allTags.sorted { $0.localizedCompare($1) == .orderedDescending }
        case .countDesc:
            return allTags.sorted { getTagCount($0) > getTagCount($1) }
        case .countAsc:
            return allTags.sorted { getTagCount($0) < getTagCount($1) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：标题 + 排序菜单
            HStack {
                Text("标签")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))

                Spacer()

                TagSortMenu(
                    sortOption: sortOption,
                    isDarkMode: isDarkMode,
                    onSelect: setSortOption
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

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

                    // 各个标签（已排序）
                    ForEach(sortedTags, id: \.self) { tag in
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
            }
        }
        .background(isDarkMode ? Color.black : Color.appBackground)
    }
}

// MARK: - 排序菜单按钮
struct TagSortMenu: View {
    let sortOption: TagSortOption
    let isDarkMode: Bool
    let onSelect: (TagSortOption) -> Void

    private var buttonBackground: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.94, green: 0.94, blue: 0.96)
    }

    private var textColor: Color {
        isDarkMode ? Color.white.opacity(0.85) : Color(red: 0.3, green: 0.3, blue: 0.35)
    }

    var body: some View {
        Menu {
            ForEach(TagSortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onSelect(option)
                    }
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .medium))

                Text(sortOption.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(buttonBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.04),
                        lineWidth: 0.5
                    )
            )
        }
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
