//
//  MicButtonShowcase 2.swift
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
                    .font(.system(size: 36, weight: .thin, design: .default))
                    .foregroundColor(.black)
                    .padding(.top, 30)
                
                // 磨砂玻璃风格
                VStack(spacing: 15) {
                    Text("磨砂玻璃")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    FrostedGlassMicButton()
                }
                
                // 暗黑新拟态
                VStack(spacing: 15) {
                    Text("暗黑新拟态")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    DarkNeumorphismMicButton()
                }
                
                // 极简呼吸
                VStack(spacing: 15) {
                    Text("极简呼吸")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    MinimalBreathingMicButton()
                }
                
                // 线性动态
                VStack(spacing: 15) {
                    Text("线性动态")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    LinearDynamicMicButton()
                }
                
                // 深度阴影
                VStack(spacing: 15) {
                    Text("深度阴影")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    DeepShadowMicButton()
                }
                
                // 墨水扩散
                VStack(spacing: 15) {
                    Text("墨水扩散")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                    InkSpreadMicButton()
                }
                
                Spacer(minLength: 50)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(white: 0.97))
    }
}

// MARK: - 1. 磨砂玻璃风格
struct FrostedGlassMicButton: View {
    @State private var isRecording = false
    @State private var rippleScale: CGFloat = 1
    @State private var rippleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景波纹
            ForEach(0..<2) { index in
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    .scaleEffect(isRecording ? 1 + CGFloat(index) * 0.4 : 1)
                    .opacity(isRecording ? 0 : 0.3)
                    .animation(
                        isRecording ?
                        Animation.easeOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.5) :
                        .default,
                        value: isRecording
                    )
            }
            
            // 主按钮
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    isRecording.toggle()
                }
            }) {
                ZStack {
                    // 毛玻璃背景
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.8),
                                            Color.gray.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                    
                    // 内部渐变
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black.opacity(isRecording ? 0.15 : 0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                    
                    // 录音指示灯
                    if isRecording {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .offset(y: -28)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 麦克风图标
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundColor(isRecording ? .black : Color.black.opacity(0.7))
                        .scaleEffect(isRecording ? 1.1 : 1)
                }
                .frame(width: 76, height: 76)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 120, height: 120)
    }
}

// MARK: - 2. 暗黑新拟态
struct DarkNeumorphismMicButton: View {
    @State private var isRecording = false
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 40)
                .fill(Color(white: 0.15))
                .frame(width: 100, height: 100)
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isRecording.toggle()
                }
            }) {
                ZStack {
                    // 外层阴影
                    Circle()
                        .fill(Color(white: 0.15))
                        .shadow(
                            color: isPressed ? .clear : Color.black.opacity(0.8),
                            radius: isPressed ? 3 : 8,
                            x: isPressed ? 3 : 6,
                            y: isPressed ? 3 : 6
                        )
                        .shadow(
                            color: isPressed ? .clear : Color(white: 0.25).opacity(0.7),
                            radius: isPressed ? 3 : 8,
                            x: isPressed ? -3 : -6,
                            y: isPressed ? -3 : -6
                        )
                    
                    // 内层边框
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.3).opacity(isPressed ? 0.2 : 0.5),
                                    Color.black.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isPressed ? 0.5 : 1
                        )
                    
                    // 中心光点
                    if isRecording {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: 2)
                    }
                    
                    // 麦克风图标
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isRecording ? .black : Color(white: 0.7))
                        .scaleEffect(isPressed ? 0.9 : 1)
                }
                .frame(width: 76, height: 76)
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
}

// MARK: - 3. 极简呼吸
struct MinimalBreathingMicButton: View {
    @State private var isRecording = false
    @State private var breatheAnimation = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isRecording.toggle()
                breatheAnimation.toggle()
            }
        }) {
            ZStack {
                // 外圈呼吸效果
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .scaleEffect(breatheAnimation ? 1.2 : 1)
                    .opacity(breatheAnimation ? 0 : 1)
                    .animation(
                        breatheAnimation ?
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: false) :
                        .default,
                        value: breatheAnimation
                    )
                
                // 主圆
                Circle()
                    .fill(isRecording ? Color.black : Color.white)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // 内部圆环
                Circle()
                    .stroke(
                        Color.gray.opacity(isRecording ? 0.3 : 0.1),
                        lineWidth: isRecording ? 2 : 1
                    )
                    .frame(width: 50, height: 50)
                    .scaleEffect(breatheAnimation ? 1.1 : 1)
                    .animation(
                        breatheAnimation ?
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                        .default,
                        value: breatheAnimation
                    )
                
                // 麦克风图标
                Image(systemName: "mic")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(isRecording ? .white : .black)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 4. 线性动态
struct LinearDynamicMicButton: View {
    @State private var isRecording = false
    @State private var lineOffset: CGFloat = -40
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isRecording.toggle()
            }
        }) {
            ZStack {
                // 扫描线效果
                if isRecording {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 3, height: 76)
                        .offset(x: lineOffset)
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                            ) {
                                lineOffset = 40
                            }
                        }
                        .onDisappear {
                            lineOffset = -40
                        }
                }
                
                // 主体边框
                RoundedRectangle(cornerRadius: isRecording ? 20 : 38)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color.gray
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecording)
                
                // 四角标记
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 2, height: 10)
                        .offset(
                            x: index % 2 == 0 ? -30 : 30,
                            y: index < 2 ? -30 : 30
                        )
                        .rotationEffect(.degrees(isRecording ? 90 : 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecording)
                }
                
                // 麦克风图标
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.black)
                    .scaleEffect(isRecording ? 1.1 : 1)
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 5. 深度阴影
struct DeepShadowMicButton: View {
    @State private var isRecording = false
    @State private var isHovering = false
    @State private var shadowDepth: CGFloat = 15
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isRecording.toggle()
                shadowDepth = isRecording ? 5 : 15
            }
        }) {
            ZStack {
                // 多层阴影
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.black.opacity(0.1 - Double(index) * 0.03))
                        .frame(width: 76, height: 76)
                        .offset(
                            x: CGFloat(index + 1) * (isRecording ? 1 : 3),
                            y: CGFloat(index + 1) * (isRecording ? 1 : 3)
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecording)
                }
                
                // 主体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: isRecording ? 0.2 : 0.95),
                                Color(white: isRecording ? 0.1 : 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // 顶部高光
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isRecording ? 0.1 : 0.5),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 60, height: 30)
                            .offset(y: -18)
                    )
                    .overlay(
                        // 边缘描边
                        Circle()
                            .stroke(
                                Color(white: isRecording ? 0.3 : 0.7).opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
                
                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(isRecording ? .white : Color(white: 0.2))
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            }
            .frame(width: 76, height: 76)
            .rotation3DEffect(
                .degrees(isHovering ? 5 : 0),
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

// MARK: - 6. 墨水扩散
struct InkSpreadMicButton: View {
    @State private var isRecording = false
    @State private var inkScale: CGFloat = 0
    @State private var inkOpacity: Double = 1
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isRecording.toggle()
                if isRecording {
                    inkScale = 1.2
                    inkOpacity = 0.1
                } else {
                    inkScale = 0
                    inkOpacity = 1
                }
            }
        }) {
            ZStack {
                // 墨水扩散效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.gray.opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .scaleEffect(inkScale)
                    .opacity(isRecording ? inkOpacity : 0)
                    .animation(
                        isRecording ?
                        Animation.easeOut(duration: 1.5) :
                        Animation.easeIn(duration: 0.3),
                        value: isRecording
                    )
                
                // 主按钮
                ZStack {
                    // 外圈
                    Circle()
                        .stroke(
                            Color.black.opacity(0.8),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: isRecording ? [5, 5] : [],
                                dashPhase: isRecording ? 10 : 0
                            )
                        )
                        .animation(
                            isRecording ?
                            Animation.linear(duration: 0.5).repeatForever(autoreverses: false) :
                            .default,
                            value: isRecording
                        )
                    
                    // 内圈填充
                    Circle()
                        .fill(isRecording ? Color.black : Color.white)
                        .scaleEffect(isRecording ? 0.9 : 0.7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isRecording)
                    
                    // 点状装饰
                    if !isRecording {
                        ForEach(0..<8) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 3, height: 3)
                                .offset(y: -30)
                                .rotationEffect(.degrees(Double(index) * 45))
                        }
                    }
                    
                    // 麦克风图标
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(isRecording ? .white : .black)
                        .scaleEffect(isRecording ? 1 : 0.9)
                }
                .frame(width: 76, height: 76)
            }
            .frame(width: 100, height: 100)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预览
struct MicButtonShowcase_Previews: PreviewProvider {
    static var previews: some View {
        MicButtonShowcase()
    }
}