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

    enum HistoryType: String, Codable {
        case github
        case local
        case zip
    }
}
