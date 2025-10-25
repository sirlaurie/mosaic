
//
//  HistoryStore.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

class HistoryStore {
    private let storageURL: URL

    init() {
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to find application support directory.")
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.example.Mosaic"
        let appDir = appSupportDir.appendingPathComponent(bundleID)

        // Create directory if it does not exist
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
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
            // If the file doesn't exist or there's a decoding error, return an empty array.
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
