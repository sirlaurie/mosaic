//
//  HistoryViewModel.swift
//  Mosaic
//
//

import Combine
import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    private let historyService: HistoryService

    init(historyService: HistoryService) {
        self.historyService = historyService

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleHistoryUpdate), name: .didUpdateHistory, object: nil
        )
    }

    func loadHistory() {
        Task {
            self.historyItems = await historyService.loadHistory()
        }
    }

    func clearHistory() {
        Task {
            do {
                try await historyService.clearHistory()
                self.historyItems = []
            } catch {
                print("Failed to clear history: \(error)")
            }
        }
    }

    @objc private func handleHistoryUpdate() {
        loadHistory()
    }
}

extension Notification.Name {
    static let didUpdateHistory = Notification.Name("didUpdateHistory")
}
