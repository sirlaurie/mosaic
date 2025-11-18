//
//  HistoryItem.swift
//  Mosaic
//
//

import Foundation

struct HistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let path: String
    let type: HistoryType
    let accessDate: Date
    let bookmarkData: Data?  // Security-scoped bookmark for local directories

    enum HistoryType: String, Codable {
        case github
        case local
        case zip
    }

    init(id: UUID, path: String, type: HistoryType, accessDate: Date, bookmarkData: Data? = nil) {
        self.id = id
        self.path = path
        self.type = type
        self.accessDate = accessDate
        self.bookmarkData = bookmarkData
    }
}
