// Mosaic/Services/LocalFileService.swift
import Foundation

class LocalFileService {
    func scanDirectory(at url: URL) async -> (files: [FileData], gitignore: [String]) {
        await Task.detached(priority: .userInitiated) {
            var files: [FileData] = []
            var gitignoreRules = [".git/**"]

            // Security-scoped resource 由调用方管理，不在这里重复访问
            // 因为 Task.detached 会在不同线程执行，重复调用可能导致问题

            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]
            guard
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
            else {
                return ([], gitignoreRules)
            }

            // 第一遍：收集所有.gitignore规则（迭代式处理，避免内存炸弹）
            while let fileURL = enumerator.nextObject() as? URL {
                if fileURL.lastPathComponent == ".gitignore" {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        let lines = content.split(whereSeparator: \.isNewline)
                        let gitignorePath = fileURL.deletingLastPathComponent().path
                            .replacingOccurrences(of: url.path, with: "").dropFirst()

                        for line in lines {
                            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                            if !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") {
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

            // 重新创建enumerator进行第二遍扫描
            guard
                let fileEnumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
            else {
                return ([], gitignoreRules)
            }

            // 第二遍：收集文件（迭代式处理）
            while let fileURL = fileEnumerator.nextObject() as? URL {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                    let isDirectory = resourceValues.isDirectory,
                    resourceValues.name != nil
                else { continue }

                let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                let cleanPath =
                    relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath

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
            // 检查文件大小（限制10MB）
            let maxFileSize = 10 * 1024 * 1024  // 10MB
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int, fileSize > maxFileSize {
                return "[File too large: \(fileSize / 1024 / 1024)MB, skipped]"
            }

            // 检测是否为二进制文件
            if Self.isBinaryFile(at: url) {
                return "[Binary file, skipped]"
            }

            // 尝试读取为UTF-8
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                return content
            }

            // 如果UTF-8失败，尝试其他编码
            let encodings: [String.Encoding] = [.utf16, .ascii, .isoLatin1]
            for encoding in encodings {
                if let content = try? String(contentsOf: url, encoding: encoding) {
                    return content
                }
            }

            return "[Unable to decode file content]"
        }.value
    }

    nonisolated private static func isBinaryFile(at url: URL) -> Bool {
        // 基于扩展名的快速检查
        let binaryExtensions = [
            "png", "jpg", "jpeg", "gif", "bmp", "ico", "svg",
            "mp3", "mp4", "avi", "mov", "wav",
            "zip", "tar", "gz", "7z", "rar",
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "exe", "dll", "so", "dylib",
            "class", "jar", "pyc",
            "db", "sqlite", "mdb"
        ]

        let ext = url.pathExtension.lowercased()
        if binaryExtensions.contains(ext) {
            return true
        }

        // 读取前1024字节检测
        guard let fileHandle = try? FileHandle(forReadingFrom: url),
            let data = try? fileHandle.read(upToCount: 1024)
        else {
            return false
        }
        try? fileHandle.close()

        // 如果包含大量null字节或不可打印字符，认为是二进制文件
        let nullBytes = data.filter { $0 == 0 }.count
        if nullBytes > data.count / 10 {  // 超过10%为null字节
            return true
        }

        return false
    }
}
