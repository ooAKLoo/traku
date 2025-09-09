import SwiftUI

// MARK: - 1. 基础 Zoom-in Animation（渐进放大动效）
struct ZoomInAnimationView: View {
    @State private var isExpanded = false
    @Namespace private var namespace
    
    var body: some View {
        VStack(spacing: 30) {
            if !isExpanded {
                // 卡片视图
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 200, height: 120)
                    .matchedGeometryEffect(id: "card", in: namespace)
                    .overlay(
                        Text("点击展开")
                            .foregroundColor(.white)
                            .font(.headline)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isExpanded.toggle()
                        }
                    }
            } else {
                // 展开后的详情视图
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 350, height: 600)
                    .matchedGeometryEffect(id: "card", in: namespace)
                    .overlay(
                        VStack(spacing: 20) {
                            Text("详情内容")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            
                            Text("这是展开后的详细信息")
                                .foregroundColor(.white.opacity(0.9))
                                .padding()
                            
                            Button("关闭") {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isExpanded.toggle()
                                }
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - 2. Pop-in Animation（弹入动效）
struct PopInAnimationView: View {
    @State private var isShowing = false
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Button("触发弹入动画") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    isShowing = true
                    scale = 1.0
                    opacity = 1.0
                }
                
                // 自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scale = 0.3
                        opacity = 0
                        isShowing = false
                    }
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            if isShowing {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 250, height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                            Text("操作成功!")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - 3. Spring Animation（弹性缩放动画）
struct SpringAnimationView: View {
    @State private var cards: [AnimatedCardModel] = AnimatedCardModel.samples
    @State private var selectedCard: AnimatedCardModel?
    @Namespace private var namespace
    
    var body: some View {
        ZStack {
            // 网格视图
            if selectedCard == nil {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(cards) { card in
                            AnimatedCardView(card: card, namespace: namespace)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        selectedCard = card
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            
            // 展开的详情视图
            if let card = selectedCard {
                AnimatedDetailCardView(card: card, namespace: namespace)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            selectedCard = nil
                        }
                    }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - 4. Material Design Scale Transition
struct ScaleTransitionView: View {
    @State private var isExpanded = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                if isExpanded {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.timingCurve(0.4, 0.0, 0.2, 1, duration: 0.3)) {
                                isExpanded = false
                                dragOffset = .zero
                            }
                        }
                }
                
                // 卡片
                RoundedRectangle(cornerRadius: isExpanded ? 30 : 15)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: isExpanded ? geometry.size.width * 0.9 : 180,
                        height: isExpanded ? 400 : 100
                    )
                    .overlay(
                        VStack(spacing: 20) {
                            if isExpanded {
                                HStack {
                                    Text("详细信息")
                                        .font(.largeTitle)
                                        .bold()
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .onTapGesture {
                                            withAnimation(.timingCurve(0.4, 0.0, 0.2, 1, duration: 0.3)) {
                                                isExpanded = false
                                                dragOffset = .zero
                                            }
                                        }
                                }
                                
                                Text("这是Material Design风格的缩放过渡动画")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                
                                Spacer()
                            } else {
                                Text("点击查看")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(isExpanded ? 30 : 15)
                    )
                    .offset(dragOffset)
                    .scaleEffect(isExpanded ? 1 : 1)
                    .shadow(radius: isExpanded ? 20 : 5)
                    .onTapGesture {
                        if !isExpanded {
                            withAnimation(.timingCurve(0.4, 0.0, 0.2, 1, duration: 0.35)) {
                                isExpanded = true
                            }
                        }
                    }
                    .gesture(
                        isExpanded ? DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 100 {
                                    withAnimation(.timingCurve(0.4, 0.0, 0.2, 1, duration: 0.3)) {
                                        isExpanded = false
                                        dragOffset = .zero
                                    }
                                } else {
                                    withAnimation(.spring()) {
                                        dragOffset = .zero
                                    }
                                }
                            } : nil
                    )
            }
        }
    }
}

// MARK: - 辅助结构和视图
struct AnimatedCardModel: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let icon: String
    
    static let samples = [
        AnimatedCardModel(title: "音乐", color: .red, icon: "music.note"),
        AnimatedCardModel(title: "照片", color: .blue, icon: "photo"),
        AnimatedCardModel(title: "视频", color: .green, icon: "video"),
        AnimatedCardModel(title: "文档", color: .orange, icon: "doc.text")
    ]
}

struct AnimatedCardView: View {
    let card: AnimatedCardModel
    let namespace: Namespace.ID
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(card.color.gradient)
            .frame(height: 150)
            .matchedGeometryEffect(id: card.id, in: namespace)
            .overlay(
                VStack {
                    Image(systemName: card.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text(card.title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            )
    }
}

struct AnimatedDetailCardView: View {
    let card: AnimatedCardModel
    let namespace: Namespace.ID
    
    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(card.color.gradient)
            .matchedGeometryEffect(id: card.id, in: namespace)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                VStack(spacing: 30) {
                    HStack {
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Image(systemName: card.icon)
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                    
                    Text(card.title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("这是 \(card.title) 的详细内容展示区域")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            )
            .ignoresSafeArea()
    }
}

// MARK: - Preview
struct ZoomInAnimation_Previews: PreviewProvider {
    static var previews: some View {
        ZoomInAnimationView()
            .previewDisplayName("Zoom-in Animation")
    }
}

struct PopInAnimation_Previews: PreviewProvider {
    static var previews: some View {
        PopInAnimationView()
            .previewDisplayName("Pop-in Animation")
    }
}

struct SpringAnimation_Previews: PreviewProvider {
    static var previews: some View {
        SpringAnimationView()
            .previewDisplayName("Spring Animation")
    }
}

struct ScaleTransition_Previews: PreviewProvider {
    static var previews: some View {
        ScaleTransitionView()
            .previewDisplayName("Scale Transition")
    }
}
