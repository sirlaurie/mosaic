
//
//  RepoError.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

enum RepoError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case fileSystemError(Error)
    case zipError(Error)
    case unknown
}
