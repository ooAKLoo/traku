////
////  SpaceInspirationCard.swift
////  raku
////
////  Created by Claude on 2025/1/7.
////
//
//import SwiftUI
//
//// MARK: - 空间数据模型
//struct SpaceCategory: Identifiable {
//    let id = UUID()
//    let name: String
//    let subcategories: [String]
//}
//
//// MARK: - 极简空间卡片
//struct SpaceInspirationCard: View {
//    let space: SpaceCategory
//    let isDarkMode: Bool
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    @State private var isHovered = false
//    
//    var body: some View {
//        Button(action: {
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                isPressed = false
//                onTap()
//            }
//        }) {
//            ZStack {
//                // 背景层
//                RoundedRectangle(cornerRadius: 16)
//                    .fill(isDarkMode ? Color.white.opacity(0.04) : Color.white)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 16)
//                            .strokeBorder(
//                                isDarkMode
//                                    ? Color.white.opacity(isHovered ? 0.08 : 0.05)
//                                    : Color.black.opacity(isHovered ? 0.06 : 0.03),
//                                lineWidth: 0.5
//                            )
//                    )
//                
//                // 内容
//                VStack(spacing: 0) {
//                    // 空间名称 - 唯一的内容
//                    Text(space.name)
//                        .font(.system(size: 16, weight: .regular))
//                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
//                        .tracking(0.3)
//                        .lineLimit(2)
//                        .multilineTextAlignment(.center)
//                        .frame(maxWidth: .infinity)
//                    
//                    // 极简指示器 - 可选的细节
//                    if isHovered {
//                        Circle()
//                            .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
//                            .frame(width: 3, height: 3)
//                            .padding(.top, 12)
//                            .transition(.opacity.combined(with: .scale))
//                    }
//                }
//                .padding(.horizontal, 20)
//                .padding(.vertical, 32)
//            }
//            .aspectRatio(1.0, contentMode: .fit) // 保持正方形
//        }
//        .buttonStyle(PlainButtonStyle())
//        .scaleEffect(isPressed ? 0.95 : 1.0)
//        .animation(.easeInOut(duration: 0.15), value: isPressed)
//        .onHover { hovering in
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isHovered = hovering
//            }
//        }
//    }
//}
//
//// MARK: - 极简空间卡片 - 替代版本（更加极简）
//struct UltraMinimalSpaceCard: View {
//    let space: SpaceCategory
//    let isDarkMode: Bool
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    
//    var body: some View {
//        Button(action: {
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                isPressed = false
//                onTap()
//            }
//        }) {
//            Text(space.name)
//                .font(.system(size: 15, weight: .light))
//                .foregroundColor(isDarkMode ? .white.opacity(0.85) : .black.opacity(0.8))
//                .tracking(0.5)
//                .lineLimit(2)
//                .multilineTextAlignment(.center)
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .padding(24)
//                .background(
//                    Rectangle()
//                        .fill(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
//                        .overlay(
//                            Rectangle()
//                                .strokeBorder(
//                                    isDarkMode
//                                        ? Color.white.opacity(0.06)
//                                        : Color.black.opacity(0.04),
//                                    lineWidth: 0.5
//                                )
//                        )
//                )
//                .aspectRatio(1.0, contentMode: .fit)
//        }
//        .buttonStyle(PlainButtonStyle())
//        .scaleEffect(isPressed ? 0.96 : 1.0)
//        .animation(.easeInOut(duration: 0.12), value: isPressed)
//    }
//}
//
//// MARK: - 横向长条卡片版本
//struct HorizontalSpaceCard: View {
//    let space: SpaceCategory
//    let isDarkMode: Bool
//    let onTap: () -> Void
//    
//    @State private var isPressed = false
//    
//    var body: some View {
//        Button(action: {
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                isPressed = false
//                onTap()
//            }
//        }) {
//            HStack {
//                Text(space.name)
//                    .font(.system(size: 15, weight: .regular))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
//                    .tracking(0.3)
//                
//                Spacer()
//                
//                // 极简箭头
//                Image(systemName: "arrow.right")
//                    .font(.system(size: 12, weight: .light))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.2) : .black.opacity(0.2))
//            }
//            .padding(.horizontal, 20)
//            .padding(.vertical, 18)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .strokeBorder(
//                                isDarkMode
//                                    ? Color.white.opacity(0.05)
//                                    : Color.black.opacity(0.03),
//                                lineWidth: 0.5
//                            )
//                    )
//            )
//        }
//        .buttonStyle(PlainButtonStyle())
//        .scaleEffect(isPressed ? 0.98 : 1.0)
//        .opacity(isPressed ? 0.8 : 1.0)
//        .animation(.easeInOut(duration: 0.1), value: isPressed)
//    }
//}
//
//// MARK: - Mock数据
//extension SpaceCategory {
//    static let mockSpaces = [
//        SpaceCategory(
//            name: "XXX APP",
//            subcategories: ["slogan", "运营", "产品", "其它"]
//        ),
//        SpaceCategory(
//            name: "工作项目",
//            subcategories: ["会议", "想法", "计划", "总结"]
//        ),
//        SpaceCategory(
//            name: "个人成长",
//            subcategories: ["学习", "思考", "目标", "反思"]
//        ),
//        SpaceCategory(
//            name: "生活记录",
//            subcategories: ["日常", "感悟", "旅行", "美食"]
//        ),
//        SpaceCategory(
//            name: "创意灵感",
//            subcategories: ["设计", "写作", "音乐", "艺术"]
//        ),
//        SpaceCategory(
//            name: "健康运动",
//            subcategories: ["锻炼", "饮食", "睡眠", "心理"]
//        )
//    ]
//}
//
//// MARK: - Color Extension
//
//
//// MARK: - Preview
//struct SpaceInspirationCard_Previews: PreviewProvider {
//    static var previews: some View {
//        let sampleSpaces = SpaceCategory.mockSpaces
//        
//        ScrollView {
//            VStack(spacing: 40) {
//                // 版本1: 圆角卡片网格
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("版本1: 圆角卡片")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                        .padding(.horizontal, 20)
//                    
//                    LazyVGrid(columns: [
//                        GridItem(.flexible(), spacing: 12),
//                        GridItem(.flexible(), spacing: 12)
//                    ], spacing: 12) {
//                        ForEach(Array(sampleSpaces.prefix(4).enumerated()), id: \.offset) { index, space in
//                            SpaceInspirationCard(
//                                space: space,
//                                isDarkMode: false,
//                                onTap: { print("Space tapped: \(space.name)") }
//                            )
//                        }
//                    }
//                    .padding(.horizontal, 20)
//                }
//                
//                // 版本2: 超极简方形卡片
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("版本2: 超极简方形")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                        .padding(.horizontal, 20)
//                    
//                    LazyVGrid(columns: [
//                        GridItem(.flexible(), spacing: 1),
//                        GridItem(.flexible(), spacing: 1)
//                    ], spacing: 1) {
//                        ForEach(Array(sampleSpaces.prefix(4).enumerated()), id: \.offset) { index, space in
//                            UltraMinimalSpaceCard(
//                                space: space,
//                                isDarkMode: false,
//                                onTap: { print("Space tapped: \(space.name)") }
//                            )
//                        }
//                    }
//                    .padding(.horizontal, 20)
//                }
//                
//                // 版本3: 横向列表
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("版本3: 横向列表")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//                        .padding(.horizontal, 20)
//                    
//                    VStack(spacing: 8) {
//                        ForEach(Array(sampleSpaces.prefix(4).enumerated()), id: \.offset) { index, space in
//                            HorizontalSpaceCard(
//                                space: space,
//                                isDarkMode: false,
//                                onTap: { print("Space tapped: \(space.name)") }
//                            )
//                        }
//                    }
//                    .padding(.horizontal, 20)
//                }
//            }
//            .padding(.vertical, 40)
//        }
//        .background(Color(hex: "FAFAFA"))
//        .previewDisplayName("All Versions - Light")
//        
//        // 暗黑模式预览
//        ScrollView {
//            LazyVGrid(columns: [
//                GridItem(.flexible(), spacing: 12),
//                GridItem(.flexible(), spacing: 12)
//            ], spacing: 12) {
//                ForEach(Array(sampleSpaces.prefix(6).enumerated()), id: \.offset) { index, space in
//                    SpaceInspirationCard(
//                        space: space,
//                        isDarkMode: true,
//                        onTap: { print("Space tapped: \(space.name)") }
//                    )
//                }
//            }
//            .padding(20)
//        }
//        .background(Color.black)
//        .previewDisplayName("Grid - Dark Mode")
//    }
//}
