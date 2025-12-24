//
//  HomeContentViewModel.swift
//  raku
//

import Foundation
import Combine

@MainActor
class HomeContentViewModel: ObservableObject {
    @Published var showingSettings = false
    @Published var searchText = ""
    @Published var showingSidebar = false
    @Published var selectedTag: String? = nil
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchError: SearchError?

    private let store = RecordingStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 观察 Store 的变化
        store.$recordings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var filteredRecordings: [AudioRecording] {
        var recordings: [AudioRecording]

        if !searchText.isEmpty && !searchResults.isEmpty {
            recordings = searchResults.compactMap { $0.recording }
        } else {
            recordings = store.recordings
        }

        if let selectedTag = selectedTag {
            recordings = recordings.filter { $0.tags.contains(selectedTag) }
        }

        return recordings
    }

    var allRecordings: [AudioRecording] {
        store.recordings
    }

    func onSearchTextChanged(_ newValue: String) {
        performSearch(query: newValue)
    }

    func deleteRecording(_ recording: AudioRecording) {
        store.deleteRecording(recording)
    }

    private func performSearch(query: String) {
        searchError = nil

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        SearchEngine.shared.search(query: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSearching = false

                switch result {
                case .success(let results):
                    self.searchResults = results
                    self.searchError = nil
                case .failure(let error):
                    self.searchResults = []
                    self.searchError = error
                }
            }
        }
    }
}
