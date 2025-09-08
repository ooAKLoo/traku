//
//  YahooMailIcon.swift
//  raku
//
//  Created by 杨东举 on 2025/9/8.
//


import SwiftUI

struct YahooMailIcon: View {
    var body: some View {
        ZStack {
            // 背景光晕效果
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 80,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 20)
            
            // 主圆形渐变背景
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.5, green: 0.3, blue: 1.0), // 紫色
                            Color(red: 0.2, green: 0.5, blue: 1.0), // 蓝色
                            Color(red: 0.3, green: 0.7, blue: 1.0)  // 浅蓝色
                        ]),
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 200, height: 200)
                .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.5), 
                       radius: 30, x: 0, y: 10)
            
            // 添加内部光泽效果
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 5,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
            
            // Yahoo! Mail 文字
            VStack(spacing: -5) {
                Text("YAHOO!")
                    .font(.system(size: 40, weight: .medium, design: .default))
                    .foregroundColor(.white)
                
                Text("MAIL")
                    .font(.system(size: 26, weight: .regular, design: .default))
                    .foregroundColor(.white)
                    .tracking(3) // 增加字母间距
            }
        }
        .frame(width: 300, height: 300)
    }
}

// 可调整大小的版本
struct ScalableYahooMailIcon: View {
    let size: CGFloat
    
    init(size: CGFloat = 200) {
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: size * 0.4,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: size * 0.1)
            
            // 主圆形
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.5, green: 0.3, blue: 1.0),
                            Color(red: 0.2, green: 0.5, blue: 1.0),
                            Color(red: 0.3, green: 0.7, blue: 1.0)
                        ]),
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.5),
                       radius: size * 0.15, x: 0, y: size * 0.05)
            
            // 内部光泽
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: size * 0.025,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
            
            // 文字
            VStack(spacing: -size * 0.025) {
                Text("YAHOO!")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(.white)
                
                Text("MAIL")
                    .font(.system(size: size * 0.13, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(size * 0.015)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
    }
}

// 预览
struct ContentViewqqq_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // 标准大小
            YahooMailIcon()
            
            // 可调整大小的版本
            HStack(spacing: 20) {
                ScalableYahooMailIcon(size: 100)
                ScalableYahooMailIcon(size: 150)
                ScalableYahooMailIcon(size: 80)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
