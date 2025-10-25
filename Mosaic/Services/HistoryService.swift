
//
//  HistoryService.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

class HistoryService {
    private let historyStore: HistoryStore

    init(historyStore: HistoryStore = HistoryStore()) {
        self.historyStore = historyStore
    }

    func loadHistory() async -> [HistoryItem] {
        do {
            return try await historyStore.load()
        } catch {
            // If loading fails, return an empty array.
            return []
        }
    }

    func addHistoryItem(path: String, type: HistoryItem.HistoryType) async throws {
        let newItem = HistoryItem(id: UUID(), path: path, type: type, accessDate: Date())

        var currentHistory = await loadHistory()
        currentHistory.removeAll { $0.path == newItem.path && $0.type == newItem.type }
        currentHistory.insert(newItem, at: 0)

        try await historyStore.save(items: currentHistory)
    }
}
