//
//  MicButtonShowcase.swift
//  raku
//
//  Created by 杨东举 on 2025/9/8.
//


import SwiftUI

// MARK: - 主视图
struct MicButtonShowcase: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 50) {
                Text("麦克风按钮设计")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                // 玻璃拟态风格
                VStack(spacing: 15) {
                    Text("玻璃拟态")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    GlassmorphismMicButton()
                }
                
                // 新拟态风格
                VStack(spacing: 15) {
                    Text("新拟态")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    NeumorphismMicButton()
                }
                
                // 渐变脉冲风格
                VStack(spacing: 15) {
                    Text("渐变脉冲")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    GradientPulseMicButton()
                }
                
                // 极简线条风格
                VStack(spacing: 15) {
                    Text("极简线条")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    MinimalLineMicButton()
                }
                
                // 3D质感风格
                VStack(spacing: 15) {
                    Text("3D质感")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    ThreeDMicButton()
                }
                
                // 液态动画风格
                VStack(spacing: 15) {
                    Text("液态动画")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    LiquidMicButton()
                }
                
                Spacer(minLength: 50)
            }
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - 1. 玻璃拟态风格
struct GlassmorphismMicButton: View {
    @State private var isRecording = false
    @State private var rippleScale: CGFloat = 1
    
    var body: some View {
        ZStack {
            // 背景波纹效果
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .scaleEffect(rippleScale)
                .opacity(isRecording ? 0 : 1)
                .animation(
                    isRecording ? Animation.easeOut(duration: 1).repeatForever(autoreverses: false) : .default,
                    value: isRecording
                )
            
            // 主按钮
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    isRecording.toggle()
                    if isRecording {
                        rippleScale = 1.5
                    } else {
                        rippleScale = 1
                    }
                }
            }) {
                ZStack {
                    // 玻璃背景
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    
                    // 内部光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isRecording ? 
                                    [.red.opacity(0.3), .clear] : 
                                    [.blue.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                    
                    // 麦克风图标
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: isRecording ? 
                                    [.red, .orange] : 
                                    [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isRecording ? 1.1 : 1)
                }
                .frame(width: 80, height: 80)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 120, height: 120)
        .onChange(of: isRecording) { newValue in
            if newValue {
                rippleScale = 1.5
            }
        }
    }
}

// MARK: - 2. 新拟态风格
struct NeumorphismMicButton: View {
    @State private var isRecording = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isRecording.toggle()
            }
        }) {
            ZStack {
                // 外层阴影
                Circle()
                    .fill(Color(#colorLiteral(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)))
                    .shadow(
                        color: isPressed ? .clear : Color.black.opacity(0.2),
                        radius: isPressed ? 5 : 10,
                        x: isPressed ? 5 : 10,
                        y: isPressed ? 5 : 10
                    )
                    .shadow(
                        color: isPressed ? .clear : Color.white,
                        radius: isPressed ? 5 : 10,
                        x: isPressed ? -5 : -10,
                        y: isPressed ? -5 : -10
                    )
                
                // 内层装饰
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.1 : 0.5),
                                Color.gray.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 0.5 : 1
                    )
                
                // 录音状态指示器
                if isRecording {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.red.opacity(0.7), .red.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .scaleEffect(isPressed ? 0.9 : 1)
                }
                
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(isRecording ? .white : Color(#colorLiteral(red: 0.5, green: 0.5, blue: 0.6, alpha: 1)))
                    .scaleEffect(isPressed ? 0.9 : 1)
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - 3. 渐变脉冲风格
struct GradientPulseMicButton: View {
    @State private var isRecording = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // 脉冲圈
            ForEach(0..<3) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .scaleEffect(isRecording ? 1 + CGFloat(index) * 0.3 : 1)
                    .opacity(isRecording ? 0 : 1)
                    .animation(
                        isRecording ?
                        Animation.easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.3) :
                        .default,
                        value: isRecording
                    )
            }
            
            // 主按钮
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    isRecording.toggle()
                    pulseAnimation.toggle()
                }
            }) {
                ZStack {
                    // 渐变背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isRecording ? 
                                    [.pink, .purple] : 
                                    [.purple, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    // 高光效果
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 70, height: 70)
                        .offset(y: -10)
                    
                    // 麦克风图标
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(pulseAnimation ? 1.2 : 1)
                        .animation(
                            pulseAnimation ?
                            Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true) :
                            .default,
                            value: pulseAnimation
                        )
                }
                .frame(width: 80, height: 80)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 150, height: 150)
    }
}

// MARK: - 4. 极简线条风格
struct MinimalLineMicButton: View {
    @State private var isRecording = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isRecording.toggle()
                rotation += 180
            }
        }) {
            ZStack {
                // 旋转边框
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.black, .gray, .black],
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            dash: isRecording ? [5, 10] : []
                        )
                    )
                    .rotationEffect(.degrees(rotation))
                    .animation(
                        isRecording ?
                        Animation.linear(duration: 3).repeatForever(autoreverses: false) :
                        .default,
                        value: isRecording
                    )
                
                // 内圈
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    .frame(width: 60, height: 60)
                
                // 中心点
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // 麦克风图标
                Image(systemName: "mic")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.black)
                    .opacity(isRecording ? 0.3 : 1)
            }
            .frame(width: 80, height: 80)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 5. 3D质感风格
struct ThreeDMicButton: View {
    @State private var isRecording = false
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isRecording.toggle()
            }
        }) {
            ZStack {
                // 底层阴影
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.3), Color.black.opacity(0.1)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 85, height: 85)
                    .offset(y: 8)
                    .blur(radius: 8)
                
                // 主体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isRecording ?
                                [Color(#colorLiteral(red: 1, green: 0.2, blue: 0.3, alpha: 1)), Color(#colorLiteral(red: 0.8, green: 0.1, blue: 0.2, alpha: 1))] :
                                [Color(#colorLiteral(red: 0.2, green: 0.2, blue: 0.3, alpha: 1)), Color(#colorLiteral(red: 0.1, green: 0.1, blue: 0.2, alpha: 1))],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // 顶部高光
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 70, height: 35)
                            .offset(y: -20)
                    )
                    .overlay(
                        // 边缘高光
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            }
            .frame(width: 80, height: 80)
            .rotation3DEffect(
                .degrees(isHovering ? 10 : 0),
                axis: (x: -1, y: 1, z: 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.3)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - 6. 液态动画风格
struct LiquidMicButton: View {
    @State private var isRecording = false
    @State private var morphAnimation = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isRecording.toggle()
                morphAnimation.toggle()
            }
        }) {
            ZStack {
                // 液态背景
                LiquidShape(animating: morphAnimation)
                    .fill(
                        LinearGradient(
                            colors: isRecording ?
                                [.orange, .red] :
                                [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: isRecording ? .red.opacity(0.4) : .blue.opacity(0.4), 
                           radius: 15, x: 0, y: 5)
                    .animation(
                        morphAnimation ?
                        Animation.easeInOut(duration: 3).repeatForever(autoreverses: true) :
                        .default,
                        value: morphAnimation
                    )
                
                // 内部光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // 麦克风图标
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(morphAnimation ? 1.1 : 1)
            }
            .frame(width: 85, height: 85)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 液态形状
struct LiquidShape: Shape {
    var animating: Bool
    
    var animatableData: Bool {
        get { animating }
        set { animating = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midX = width / 2
        let midY = height / 2
        
        let controlOffset: CGFloat = animating ? 8 : 2
        
        path.move(to: CGPoint(x: midX, y: 0))
        
        // 右上曲线
        path.addCurve(
            to: CGPoint(x: width, y: midY),
            control1: CGPoint(x: width - controlOffset, y: 0),
            control2: CGPoint(x: width, y: controlOffset)
        )
        
        // 右下曲线
        path.addCurve(
            to: CGPoint(x: midX, y: height),
            control1: CGPoint(x: width, y: height - controlOffset),
            control2: CGPoint(x: width - controlOffset, y: height)
        )
        
        // 左下曲线
        path.addCurve(
            to: CGPoint(x: 0, y: midY),
            control1: CGPoint(x: controlOffset, y: height),
            control2: CGPoint(x: 0, y: height - controlOffset)
        )
        
        // 左上曲线
        path.addCurve(
            to: CGPoint(x: midX, y: 0),
            control1: CGPoint(x: 0, y: controlOffset),
            control2: CGPoint(x: controlOffset, y: 0)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - 预览
struct MicButtonShowcase_Previews: PreviewProvider {
    static var previews: some View {
        MicButtonShowcase()
    }
}