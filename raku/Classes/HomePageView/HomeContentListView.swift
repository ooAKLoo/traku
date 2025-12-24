//
//  HomeContentListView.swift
//  raku
//

import SwiftUI

struct HomeContentListView: View {
    @ObservedObject var viewModel: HomeContentViewModel

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }

    @State private var selectedRecording: AudioRecording? = nil
    @State private var isNavigating = false

    var body: some View {
        if viewModel.filteredRecordings.isEmpty {
            emptyStateView
                .background(navigationLink)
                .onChange(of: isNavigating) { _ in
                    resetSelection()
                }
        } else {
            recordingListView
        }
    }

    private var recordingListView: some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.ContentList.cardSpacing) {
                ForEach(viewModel.filteredRecordings, id: \.id) { recording in
                    cardView(for: recording)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, UIConstants.ContentList.topPadding)
            .padding(.bottom, UIConstants.ContentList.bottomPadding)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(navigationLink)
        .onChange(of: isNavigating) { _ in
            resetSelection()
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            config: .noRecordings,
            isDarkMode: isDarkMode
        )
        .animation(.easeInOut(duration: 0.6), value: viewModel.filteredRecordings.isEmpty)
    }

    @ViewBuilder
    private func cardView(for recording: AudioRecording) -> some View {
        HomeContentCardView(
            recording: recording,
            onDelete: { viewModel.deleteRecording(recording) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRecording = recording
            isNavigating = true
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity
        ))
        .animation(.easeInOut(duration: 0.2), value: viewModel.filteredRecordings.count)
    }

    private var navigationLink: some View {
        Group {
            if let recording = selectedRecording {
                NavigationLink(
                    destination: RecordingDetailView(recording: recording)
                        .navigationBarHidden(true),
                    isActive: $isNavigating
                ) {
                    EmptyView()
                }
                .onChange(of: isNavigating) { navigating in
                    if !navigating {
                        GlobalPopupManager.shared.hideBatchSelectionImmediately()
                    }
                }
                .hidden()
                .navigationViewStyle(StackNavigationViewStyle())
            } else {
                EmptyView()
            }
        }
    }

    private func resetSelection() {
        if !isNavigating {
            selectedRecording = nil
        }
    }
}
