//
//  HomeContentCardView.swift
//  raku
//

import SwiftUI

struct HomeContentCardView: View {
    let recording: AudioRecording
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }

    @ObservedObject private var store = RecordingStore.shared

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredHaptic = false
    @State private var isHorizontalDrag = false

    private var weatherType: WeatherType {
        recording.weather ?? .sunny
    }

    private let deleteThreshold: CGFloat = -180
    private let maxSwipeDistance: CGFloat = -220

    private var progress: CGFloat {
        min(abs(offset) / abs(deleteThreshold), 1.0)
    }

    private var trashColor: Color {
        if progress < 0.5 {
            return Color.orange.opacity(0.7 + Double(progress * 0.3))
        } else {
            return Color.red.opacity(0.7 + Double(progress * 0.3))
        }
    }

    // 从 Store 获取处理状态
    private var processingState: RecordingStore.ProcessingState? {
        store.processingStates[recording.id]
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景层 - 删除区域
            HStack {
                Spacer()
                ZStack {
                    if progress < 1 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(trashColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }

                    Image(systemName: progress == 1 ? "checkmark" : "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(progress == 1 ? Color.red : trashColor)
                        .scaleEffect(progress == 1 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
                        .onChange(of: progress == 1) { showingCheckmark in
                            if showingCheckmark && !hasTriggeredHaptic {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                hasTriggeredHaptic = true
                            } else if !showingCheckmark {
                                hasTriggeredHaptic = false
                            }
                        }
                }
                .frame(width: 60)
                .opacity(offset < -10 ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: offset < -10)
            }

            // 卡片内容
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    // 时间戳和处理状态
                    HStack(spacing: 8) {
                        Text(recording.timestamp.smartFormatted)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))

                        // 处理状态显示
                        if let state = processingState, state.stage.isProcessing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: state.stage.color))

                                Text(state.stage.displayText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(state.stage.color)
                            }
                        }

                        Spacer()
                    }

                    Spacer().frame(height: 10)

                    // 标题
                    Text(recording.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer().frame(height: 14)

                    // 标签
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                            TagView(text: tag, isDarkMode: isDarkMode)
                        }
                        if recording.tags.count > 3 {
                            Text("+\(recording.tags.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右侧天气图标
                if offset >= -10 {
                    VStack(spacing: 9) {
                        Spacer().frame(height: 6)

                        WeatherIconView(
                            weatherType: weatherType,
                            isDarkMode: false,
                            size: 28,
                            showBackground: false
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            weatherType.primaryColor.opacity(0.15),
                                            weatherType.primaryColor.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )

                        RoundedRectangle(cornerRadius: 2)
                            .fill(weatherType.primaryColor.opacity(0.6))
                            .frame(width: 20, height: 3)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
            )
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        if !isDragging {
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                            if isHorizontal && value.translation.width < -20 {
                                isHorizontalDrag = true
                                isDragging = true
                            } else {
                                return
                            }
                        }

                        guard isHorizontalDrag else { return }

                        withAnimation(.interactiveSpring(response: 0.3)) {
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, maxSwipeDistance)
                            } else if offset < 0 {
                                offset = min(0, offset + value.translation.width / 3)
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            isHorizontalDrag = false

                            if progress >= 1.0 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete()
                                }
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
    }
}
