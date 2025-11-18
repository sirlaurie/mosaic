//
//  HistoryService.swift
//  Mosaic
//
//

import Foundation

class HistoryService {
    private let historyStore: HistoryStore
    private let maxHistoryItems = 50  // 最多保存50条历史记录

    init(historyStore: HistoryStore = HistoryStore()) {
        self.historyStore = historyStore
    }

    func loadHistory() async -> [HistoryItem] {
        do {
            return try await historyStore.load()
        } catch {
            return []
        }
    }

    func addHistoryItem(path: String, type: HistoryItem.HistoryType) async throws {
        let newItem = HistoryItem(id: UUID(), path: path, type: type, accessDate: Date())

        var currentHistory = await loadHistory()
        currentHistory.removeAll { $0.path == newItem.path && $0.type == newItem.type }
        currentHistory.insert(newItem, at: 0)

        // 限制历史记录数量
        if currentHistory.count > maxHistoryItems {
            currentHistory = Array(currentHistory.prefix(maxHistoryItems))
        }

        try await historyStore.save(items: currentHistory)
    }
}
