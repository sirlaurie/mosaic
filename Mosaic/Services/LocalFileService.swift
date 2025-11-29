// Mosaic/Services/LocalFileService.swift
import Foundation

class LocalFileService {
    func scanDirectory(at url: URL) async -> (files: [FileData], gitignore: [String]) {
        await Task.detached(priority: .userInitiated) {
            let startTime = Date()
            print("📂 [LocalFileService] Starting to scan directory: \(url.lastPathComponent)")

            var files: [FileData] = []
            var gitignoreRules = [".git/**"]
            let maxFiles = 50000  // 限制最大文件数，避免处理过大的目录

            // 需要跳过的大型目录
            let skipDirectories: Set<String> = [
                // JavaScript/Node.js
                "node_modules",
                "bower_components",

                // Python
                "venv",
                "env",
                "__pycache__",
                ".pytest_cache",
                ".tox",
                "site-packages",

                // Java/Kotlin/Scala
                "target",
                "build",
                "out",
                "classes",
                "bin",

                // Ruby
                "vendor",
                "bundle",

                // iOS/macOS
                "Pods",
                "Carthage",
                "DerivedData",

                // .NET
                "obj",
                "packages",

                // Go
                "pkg",

                // Rust
                "debug",
                "release",

                // 通用构建输出
                "dist",
                "output",
                "tmp",
                "temp",
                "cache"
            ]

            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]
            guard
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsPackageDescendants]  // 移除 skipsHiddenFiles，手动处理
                )
            else {
                return ([], gitignoreRules)
            }

            var fileCount = 0
            var dirCount = 0
            var skippedCount = 0

            // 单遍扫描：同时收集文件和 gitignore 规则
            while let fileURL = enumerator.nextObject() as? URL {
                // 限制文件数量，避免内存溢出
                if files.count >= maxFiles {
                    print("⚠️ [LocalFileService] Reached maximum file limit (\(maxFiles)), stopping scan")
                    break
                }

                let dirName = fileURL.lastPathComponent

                // 跳过所有以 "." 开头的目录（包括 .git, .idea, .vscode 等）
                if dirName.hasPrefix(".") {
                    enumerator.skipDescendants()
                    skippedCount += 1
                    continue
                }

                // 跳过大型依赖目录
                if skipDirectories.contains(dirName) {
                    enumerator.skipDescendants()
                    skippedCount += 1
                    continue
                }

                // 检查是否是目录
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isDirectory = resourceValues.isDirectory
                else { continue }

                if isDirectory {
                    dirCount += 1
                } else {
                    fileCount += 1
                    // 收集文件
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                    let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                    let data = FileData(name: cleanPath, url: fileURL, isDirectory: false)
                    files.append(data)
                }

                // 收集 .gitignore 规则
                if dirName == ".gitignore" {
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

            let duration = Date().timeIntervalSince(startTime)
            print("✅ [LocalFileService] Scan completed in \(String(format: "%.2f", duration))s")
            print("   - Files: \(fileCount), Directories: \(dirCount), Skipped: \(skippedCount)")

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
