//
//  RepoError.swift
//  Mosaic
//
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
