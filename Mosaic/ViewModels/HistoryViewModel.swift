
//
//  HistoryViewModel.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Combine
import Foundation

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    private let historyService: HistoryService

    init(historyService: HistoryService) {
        self.historyService = historyService

        // Listen for history updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleHistoryUpdate), name: .didUpdateHistory, object: nil)
    }

    func loadHistory() {
        Task {
            self.historyItems = await historyService.loadHistory()
        }
    }

    @objc private func handleHistoryUpdate() {
        loadHistory()
    }
}

// Define a notification name for history updates
extension Notification.Name {
    static let didUpdateHistory = Notification.Name("didUpdateHistory")
}
