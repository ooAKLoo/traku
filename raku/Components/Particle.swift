//
//  Particle.swift
//  raku
//
//  Created by 杨东举 on 2025/9/8.
//

import SwiftUI
import Foundation  // 确保导入 Foundation 以使用数学函数

// MARK: - 粒子模型
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var scale: CGFloat
    var opacity: Double
    var color: Color
    var lifespan: Double
    var age: Double = 0
}

// MARK: - 粒子发射器视图
struct ParticleEmitterView: View {
    @State private var particles: [Particle] = []
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var animationTrigger = false
    
    // 配置参数
    let particleCount = 20
    let emissionRadius: CGFloat = 100
    let baseColor = Color.purple
    
    var body: some View {
        ZStack {
            // 粒子层
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 4 * particle.scale, height: 4 * particle.scale)
                    .opacity(particle.opacity)
                    .position(particle.position)
                    .blur(radius: particle.scale > 1.5 ? 1 : 0)
                    .animation(.linear(duration: 0.1), value: particle.position)
            }
        }
        .onReceive(timer) { _ in
            updateParticles()
            emitNewParticles()
        }
        .onAppear {
            initializeParticles()
        }
    }
    
    // 初始化粒子
    private func initializeParticles() {
        for _ in 0..<particleCount {
            particles.append(createParticle())
        }
    }
    
    // 创建新粒子
    private func createParticle() -> Particle {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 0...emissionRadius)
        
        // 修复1: 明确使用 Foundation.cos 和 Foundation.sin
        let position = CGPoint(
            x: 200 + Foundation.cos(angle) * distance,
            y: 200 + Foundation.sin(angle) * distance
        )
        
        let velocity = CGVector(
            dx: CGFloat.random(in: -2...2),
            dy: CGFloat.random(in: -2...2)
        )
        
        return Particle(
            position: position,
            velocity: velocity,
            scale: CGFloat.random(in: 1...3),
            opacity: 0,
            color: baseColor.opacity(Double.random(in: 0.5...1)),
            lifespan: Double.random(in: 2...4)
        )
    }
    
    // 更新粒子状态
    private func updateParticles() {
        particles = particles.compactMap { particle in
            var updatedParticle = particle
            
            // 更新位置
            updatedParticle.position.x += updatedParticle.velocity.dx
            updatedParticle.position.y += updatedParticle.velocity.dy
            
            // 更新年龄
            updatedParticle.age += 0.1
            
            // 更新透明度（淡入淡出效果）
            let normalizedAge = updatedParticle.age / updatedParticle.lifespan
            if normalizedAge < 0.2 {
                updatedParticle.opacity = normalizedAge * 5
            } else if normalizedAge > 0.7 {
                updatedParticle.opacity = (1 - normalizedAge) * 3.33
            } else {
                updatedParticle.opacity = 1
            }
            
            // 如果粒子生命结束，返回nil以移除
            if updatedParticle.age > updatedParticle.lifespan {
                return nil
            }
            
            return updatedParticle
        }
    }
    
    // 发射新粒子
    private func emitNewParticles() {
        let particlesToEmit = particleCount - particles.count
        for _ in 0..<particlesToEmit {
            particles.append(createParticle())
        }
    }
}

// MARK: - 主光晕效果视图
struct GlowEffectView: View {
    @State private var isAnimating = false
    @State private var glowIntensity: Double = 0.5
    @State private var rotationAngle: Double = 0
    
    // 颜色配置
    let gradientColors = [
        Color(red: 0.48, green: 0.41, blue: 0.93),
        Color(red: 0.29, green: 0.57, blue: 0.89)
    ]
    
    var body: some View {
        ZStack {
            // 背景光晕层
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                gradientColors[0].opacity(0.6 / Double(index + 1)),
                                gradientColors[1].opacity(0.3 / Double(index + 1)),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 50,
                            endRadius: 100 + CGFloat(index * 30)
                        )
                    )
                    .frame(width: 300 + CGFloat(index * 60),
                           height: 300 + CGFloat(index * 60))
                    .blur(radius: CGFloat(index * 10 + 20))
                    .scaleEffect(isAnimating ? 1.1 + Double(index) * 0.05 : 1.0)
                    .rotationEffect(.degrees(rotationAngle + Double(index * 30)))
                    .animation(
                        Animation.easeInOut(duration: 3 + Double(index))
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            // 主体圆形
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 150)
                .overlay(
                    Text("GLOW")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // 粒子效果层
            ParticleEmitterView()
                .allowsHitTesting(false)
        }
        .frame(width: 400, height: 400)
        .onAppear {
            isAnimating = true
            // 持续旋转动画
            withAnimation(
                Animation.linear(duration: 20)
                    .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - 高级光晕效果（使用 Canvas）
struct AdvancedGlowView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // 绘制多层光晕
                for i in 0..<5 {
                    let radius = 60 + CGFloat(i) * 30
                    let opacity = 0.3 / CGFloat(i + 1)
                    let scale = 1.0 + Foundation.sin(time * 2 + Double(i)) * 0.1
                    
                    context.opacity = opacity
                    
                    // 创建渐变
                    let gradient = Gradient(stops: [
                        .init(color: Color.purple, location: 0),
                        .init(color: Color.blue, location: 0.5),
                        .init(color: Color.clear, location: 1)
                    ])
                    
                    let path = Path(ellipseIn: CGRect(
                        x: center.x - radius * scale,
                        y: center.y - radius * scale,
                        width: radius * 2 * scale,
                        height: radius * 2 * scale
                    ))
                    
                    context.fill(path, with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius * scale
                    ))
                }
                
                // 绘制中心球体
                context.opacity = 1
                let corePath = Path(ellipseIn: CGRect(
                    x: center.x - 60,
                    y: center.y - 60,
                    width: 120,
                    height: 120
                ))
                
                context.fill(corePath, with: .linearGradient(
                    Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: CGPoint(x: center.x - 60, y: center.y - 60),
                    endPoint: CGPoint(x: center.x + 60, y: center.y + 60)
                ))
                
                // 添加文字
                let text = Text("CANVAS")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                context.draw(text, at: center)
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - 控制面板
struct GlowControlsView: View {
    @Binding var intensity: Double
    @Binding var primaryColor: Color
    @Binding var secondaryColor: Color
    @Binding var animationSpeed: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("光晕控制面板")
                .font(.title2)
                .fontWeight(.bold)
            
            // 强度控制
            VStack(alignment: .leading) {
                Text("光晕强度: \(Int(intensity * 100))%")
                    .font(.caption)
                Slider(value: $intensity, in: 0...1)
                    .tint(.purple)  // iOS 15+ 使用 tint 替代 accentColor
            }
            
            // 颜色选择
            HStack {
                ColorPicker("主色", selection: $primaryColor)
                ColorPicker("副色", selection: $secondaryColor)
            }
            
            // 动画速度
            VStack(alignment: .leading) {
                Text("动画速度: \(String(format: "%.1f", animationSpeed))x")
                    .font(.caption)
                Slider(value: $animationSpeed, in: 0.5...3)
                    .tint(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - 主应用视图
struct ContentViewwww: View {
    @State private var selectedTab = 0
    @State private var intensity: Double = 0.5
    @State private var primaryColor = Color.purple
    @State private var secondaryColor = Color.blue
    @State private var animationSpeed: Double = 1.0
    
    var body: some View {
        VStack(spacing: 30) {
            Text("SwiftUI 光晕效果展示")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // 标签选择器
            Picker("效果类型", selection: $selectedTab) {
                Text("粒子光晕").tag(0)
                Text("Canvas光晕").tag(1)
                Text("多层混合").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // 效果展示区域
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
                    .frame(height: 450)
                
                switch selectedTab {
                case 0:
                    GlowEffectView()
                case 1:
                    AdvancedGlowView()
                case 2:
                    CombinedEffectView()
                default:
                    GlowEffectView()
                }
            }
            .padding(.horizontal)
            
            // 控制面板
            GlowControlsView(
                intensity: $intensity,
                primaryColor: $primaryColor,
                secondaryColor: $secondaryColor,
                animationSpeed: $animationSpeed
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - 组合效果视图（简化版，移除 Metal Shader）
struct CombinedEffectView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 传统光晕效果
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.4),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 20)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            
            // 核心元素
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple, .blue]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 150)
                .overlay(
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("MIXED")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                )
                .rotationEffect(.degrees(isAnimating ? 5 : -5))
            
            // 装饰粒子
            ForEach(0..<8) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(x: 0, y: -80)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 400, height: 400)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 高级 Metal Shader 实现（需要单独的 .metal 文件）
// 如果你想使用 Metal Shader，需要：
// 1. 创建一个新的 .metal 文件
// 2. 在文件中定义着色器函数
// 3. 然后使用下面的代码

/*
// 示例 .metal 文件内容（保存为 GlowShader.metal）：
#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 glowEffect(float2 position [[position]],
                                  half4 color,
                                  float intensity) {
    // 光晕效果算法
    half4 outputColor = color;
    outputColor.rgb *= (1.0 + intensity * 0.5);
    return outputColor;
}
*/

// 如果你有 .metal 文件，可以这样使用：
@available(iOS 17.0, *)
struct MetalGlowView: View {
    @State private var intensity: Float = 1.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(.purple)
            .frame(width: 150, height: 150)
            // 只有在有对应的 .metal 文件时才取消注释
            // .colorEffect(
            //     ShaderLibrary.glowEffect(
            //         .float(intensity)
            //     )
            // )
    }
}

// MARK: - 预览
struct ContentViewwww_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewwww()
    }
}
