//
//  homepageListView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音列表内容视图
struct HomepageListView: View {
    let filteredRecordings: [AudioRecording]
    let isDarkMode: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(Array(filteredRecordings.enumerated()), id: \.element.id) { index, recording in
                    NavigationLink(destination:
                        RecordingDetailView(recording: recording)
                            .navigationBarHidden(true)
                    ) {
                        RecordingCardView(recording: recording, isDarkMode: isDarkMode)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale)
                    ))
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
            .background(.white)
        }
    }
}