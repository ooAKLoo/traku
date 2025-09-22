//
//  FeedbackSuccessView.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//

import SwiftUI
import Lottie

struct FeedbackSuccessView: View {
    let isDarkMode: Bool
    let onDismiss: () -> Void
    @State private var showAnimation = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 24) {
                // Lottie动画
                if showAnimation {
                    LottieView(animation: .named("confetti on transparent background"))
                        .playing(loopMode: .playOnce)
                        .animationDidFinish { completed in
                            if completed {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onDismiss()
                                }
                            }
                        }
                        .frame(width: 200, height: 200)
                }
                
                // 成功文字
                VStack(spacing: 8) {
                    Text("反馈提交成功!")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("感谢您的宝贵建议")
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isDarkMode ? Color(white: 0.1) : Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 20)
            )
            .scaleEffect(showAnimation ? 1 : 0.8)
            .opacity(showAnimation ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showAnimation)
        }
        .onAppear {
            withAnimation {
                showAnimation = true
            }
        }
    }
}
