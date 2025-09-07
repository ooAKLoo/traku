import SwiftUI

// MARK: - 数据模型
struct CardItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

// MARK: - 主视图
struct CircularProgressTrashView: View {
    @State private var cards = [
        CardItem(title: "购物清单", subtitle: "今天需要买的东西", icon: "cart.fill", color: .blue),
        CardItem(title: "会议笔记", subtitle: "上午10点的产品会议", icon: "note.text", color: .purple),
        CardItem(title: "健身计划", subtitle: "本周训练安排", icon: "figure.run", color: .green),
        CardItem(title: "读书笔记", subtitle: "《SwiftUI入门》第三章", icon: "book.fill", color: .orange),
        CardItem(title: "旅行计划", subtitle: "下个月的日本之旅", icon: "airplane", color: .pink)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(cards) { card in
                        CircularProgressCard(card: card) {
                            deleteCard(card)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("滑动删除")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func deleteCard(_ card: CardItem) {
        withAnimation(.spring()) {
            cards.removeAll { $0.id == card.id }
        }
    }
}

// MARK: - 圆环进度垃圾桶卡片
struct CircularProgressCard: View {
    let card: CardItem
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDeleting = false
    
    // 删除阈值（圆环完全闭合的滑动距离）
    private let deleteThreshold: CGFloat = -120
    private let maxSwipeDistance: CGFloat = -150
    
    // 计算进度 (0 到 1)
    private var progress: CGFloat {
        min(abs(offset) / abs(deleteThreshold), 1.0)
    }
    
    // 根据进度计算颜色深度
    private var trashColor: Color {
        // 从灰色逐渐过渡到红色
        if progress < 0.3 {
            return Color.gray.opacity(0.6 + Double(progress))
        } else if progress < 0.7 {
            return Color.orange.opacity(0.8 + Double(progress * 0.2))
        } else {
            return Color.red.opacity(0.8 + Double(progress * 0.2))
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景层
            HStack {
                Spacer()
                
                // 圆环进度垃圾桶
                ZStack {
                    
                    // 进度圆环
                    if progress < 1 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                trashColor,
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                    
                    // 垃圾桶图标或对勾
                    Image(systemName: progress == 1 ? "checkmark" : "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(progress == 1 ? Color.red : trashColor)
                        .scaleEffect(progress == 1 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
                }
                .frame(width: 80)
                .opacity(offset < -10 ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: offset < -10)
                
            }
            
            // 卡片内容
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(card.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: card.icon)
                        .font(.system(size: 20))
                        .foregroundColor(card.color)
                }
                
                // 文本内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(card.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .opacity(0.3)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: .black.opacity(isDeleting ? 0 : 0.08),
                radius: isDeleting ? 0 : 4,
                x: 0,
                y: 2
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.3)) {
                            isDragging = true
                            // 只允许向左滑动
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, maxSwipeDistance)
                            } else if offset < 0 {
                                // 允许向右恢复，但不超过原点
                                offset = min(0, offset + value.translation.width / 3)
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            
                            // 如果圆环闭合（progress == 1），执行删除
                            if progress >= 1.0 {
                                isDeleting = true
                                // 滑出屏幕动画
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                // 延迟后删除
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete()
                                }
                            } else {
                                // 圆环未闭合，弹回原位
                                offset = 0
                            }
                        }
                    }
            )
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 带说明的演示视图
struct DemoView: View {
    @State private var demoOffset: CGFloat = 0
    @State private var isAnimating = false
    
    private let deleteThreshold: CGFloat = -120
    
    private var progress: CGFloat {
        min(abs(demoOffset) / abs(deleteThreshold), 1.0)
    }
    
    private var trashColor: Color {
        if progress < 0.3 {
            return Color.gray.opacity(0.6 + Double(progress))
        } else if progress < 0.7 {
            return Color.orange.opacity(0.8 + Double(progress * 0.2))
        } else {
            return Color.red.opacity(0.8 + Double(progress * 0.2))
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // 说明文字
            VStack(spacing: 8) {
                Text("交互说明")
                    .font(.headline)
                Text("左滑查看删除效果，圆环闭合后松手删除")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 演示卡片
            ZStack {
                // 圆环进度指示器
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                progress == 1 ? Color.red : trashColor,
                                style: StrokeStyle(
                                    lineWidth: 4,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 4) {
                            Image(systemName: progress == 1 ? "trash.fill" : "trash")
                                .font(.system(size: 32))
                                .foregroundColor(trashColor)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(trashColor)
                        }
                    }
                    .padding(.trailing, 20)
                }
                
                // 卡片
                HStack {
                    Image(systemName: "hand.draw.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("向左滑动试试")
                        .font(.headline)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .offset(x: demoOffset)
            }
            .frame(height: 100)
            .padding(.horizontal)
            
            // 自动演示按钮
            Button(action: {
                startDemo()
            }) {
                Label("自动演示", systemImage: "play.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            // 进度说明
            HStack(spacing: 20) {
                ProgressIndicator(color: .gray, label: "0-30%")
                ProgressIndicator(color: .orange, label: "30-70%")
                ProgressIndicator(color: .red, label: "70-100%")
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        demoOffset = max(value.translation.width, -150)
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        demoOffset = 0
                    }
                }
        )
    }
    
    private func startDemo() {
        isAnimating = true
        
        // 滑动到50%
        withAnimation(.easeInOut(duration: 0.8)) {
            demoOffset = -60
        }
        
        // 返回
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring()) {
                demoOffset = 0
            }
        }
        
        // 滑动到100%
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 1.0)) {
                demoOffset = -120
            }
        }
        
        // 返回
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.spring()) {
                demoOffset = 0
                isAnimating = false
            }
        }
    }
}

struct ProgressIndicator: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct ContentView3432_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 主界面预览
            CircularProgressTrashView()
                .previewDisplayName("主界面")
            
            // 演示视图
            DemoView()
                .previewDisplayName("交互演示")
            
            // 深色模式
            CircularProgressTrashView()
                .preferredColorScheme(.dark)
                .previewDisplayName("深色模式")
        }
    }
}
