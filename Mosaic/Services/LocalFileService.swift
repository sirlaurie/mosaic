// File: /Mosaic/Services/LocalFileService.swift
import Foundation

// Using the simpler, more robust approach from the repo2txt web version.
// This service now returns a flat list of file data and parsed gitignore rules.
class LocalFileService {

    func scanDirectory(at url: URL) async -> (files: [FileData], gitignore: [String]) {
        return await Task.detached(priority: .userInitiated) {
            var files: [FileData] = []
            var gitignoreRules: [String] = [".git/**"] // Start with a default rule

            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to start accessing security-scoped resource.")
                return ([], [])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                return ([], gitignoreRules)
            }

            let allURLs = enumerator.allObjects as? [URL] ?? []

            // First, find all .gitignore files and parse their rules
            for fileURL in allURLs {
                if fileURL.lastPathComponent == ".gitignore" {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let lines = content.split(whereSeparator: \.isNewline)
                        let gitignorePath = fileURL.deletingLastPathComponent().path.replacingOccurrences(of: url.path, with: "").dropFirst()
                        
                        for line in lines {
                            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                            if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") {
                                if !gitignorePath.isEmpty {
                                    gitignoreRules.append("\(gitignorePath)/\(trimmedLine)")
                                } else {
                                    gitignoreRules.append(String(trimmedLine))
                                }
                            }
                        }
                    }
                }
            }
            
            // Second, create the flat list of all files
            for fileURL in allURLs {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isDirectory = resourceValues.isDirectory,
                      let name = resourceValues.name
                else { continue }
                
                // The path should be relative to the root URL
                let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath

                // We only care about files for the flat list, not directories
                if !isDirectory {
                    let data = FileData(name: cleanPath, url: fileURL, isDirectory: isDirectory)
                    files.append(data)
                }
            }
            
            return (files, gitignoreRules)
        }.value
    }

    func readFileContent(at url: URL) async throws -> String {
        try await Task.detached {
            try String(contentsOf: url, encoding: .utf8)
        }.value
    }
}