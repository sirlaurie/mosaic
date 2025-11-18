//
//  HistoryStore.swift
//  Mosaic
//
//

import Foundation

actor HistoryStore {
    private let storageURL: URL

    init() {
        // 尝试获取Application Support目录，如果失败则使用临时目录
        let appSupportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let bundleID = Bundle.main.bundleIdentifier ?? "com.example.Mosaic"
        let appDir = appSupportDir.appendingPathComponent(bundleID)

        // Create directory if it does not exist
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(
                at: appDir, withIntermediateDirectories: true, attributes: nil
            )
        }

        storageURL = appDir.appendingPathComponent("history.json")
    }

    func load() async throws -> [HistoryItem] {
        do {
            let data = try await Task {
                try Data(contentsOf: storageURL)
            }.value
            let items = try JSONDecoder().decode([HistoryItem].self, from: data)
            return items
        } catch {
            return []
        }
    }

    func save(items: [HistoryItem]) async throws {
        let data = try JSONEncoder().encode(items)
        try await Task {
            try data.write(to: storageURL, options: .atomic)
        }.value
    }
}
