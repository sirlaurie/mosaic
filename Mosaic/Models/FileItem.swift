
//
//  FileItem.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    var children: [FileItem]?
    var isSelected: Bool = false
}
