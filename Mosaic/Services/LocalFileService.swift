// Mosaic/Services/LocalFileService.swift
import Foundation

class LocalFileService {
    func scanDirectory(at url: URL, customLazyDirectories: [String] = []) async -> (files: [FileData], gitignore: [String]) {
        await Task.detached(priority: .userInitiated) {
            let startTime = Date()
            print("📂 [LocalFileService] Starting to scan directory: \(url.lastPathComponent)")

            var files: [FileData] = []
            var gitignoreRules = [".git/**"]
            // let maxFiles = 50000  // Removed limit to allow full scanning of large directories like Homebrew

            // Convert custom list to Set for fast lookup
            let skipDirectories = Set(customLazyDirectories)

            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]
            guard
                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: []  // 移除所有默认跳过选项，包括 skipsPackageDescendants
                )
            else {
                return ([], gitignoreRules)
            }

            var fileCount = 0
            var dirCount = 0
            var skippedCount = 0

            // 单遍扫描：同时收集文件和 gitignore 规则
            while let fileURL = enumerator.nextObject() as? URL {
                // Removed maxFiles check
                
                let dirName = fileURL.lastPathComponent

                // 只跳过 .git 目录，允许显示其他隐藏文件（如 .config, .github 等）
                if dirName == ".git" {
                    enumerator.skipDescendants()
                    skippedCount += 1
                    continue
                }

                // 检查是否是目录
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isDirectory = resourceValues.isDirectory
                else { continue }

                // 跳过大型依赖目录，但作为懒加载节点添加到列表中
                if isDirectory && skipDirectories.contains(dirName) {
                    enumerator.skipDescendants()
                    skippedCount += 1
                    
                    // Add as lazy directory
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                    let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                    let data = FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: true)
                    files.append(data)
                    
                    continue
                }

                if isDirectory {
                    dirCount += 1
                    
                    // Explicitly add the directory to files list so it shows up even if empty or files are ignored
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                    let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                    let data = FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: false)
                    files.append(data)
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
    
    func scanSubDirectory(at url: URL, rootURL: URL) async -> [FileData] {
        await Task.detached(priority: .userInitiated) {
            print("📂 [LocalFileService] Scanning subdirectory: \(url.lastPathComponent)")
            var files: [FileData] = []
            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            
            // For subdirectories, we perform a shallow scan (or one level deep recursive? or fully recursive?)
            // Usually "expand" means showing immediate children. But FileTreeView handles recursive structure.
            // If we want to show the full tree inside `node_modules` when expanded, we should probably scan recursively
            // BUT `node_modules` can be DEEP.
            // Let's use the same logic as main scan, but without the "skipDirectories" check for the root itself.
            
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants, .skipsHiddenFiles] // Skip hidden files in sub-scan for cleanliness
            ) else {
                return []
            }
            
            let maxFiles = 10000
            
            while let fileURL = enumerator.nextObject() as? URL {
                if files.count >= maxFiles { break }
                
                // Calculate path relative to the PROJECT ROOT, not the subdirectory
                // This is crucial because FileNode structure relies on full relative paths
                let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path, with: "")
                let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath
                
                let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues?.isDirectory ?? false
                
                // Simple filtering for subdirectory scan
                // We might want to still skip nested node_modules to avoid infinite death
                if fileURL.lastPathComponent == "node_modules" || fileURL.lastPathComponent.hasPrefix(".") {
                    enumerator.skipDescendants()
                    // We could add them as lazy nodes too if we want infinite recursion capability!
                    // For now, let's just skip nested node_modules to keep it sane.
                     if fileURL.lastPathComponent == "node_modules" {
                        let data = FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: true)
                        files.append(data)
                     }
                    continue
                }
                
                let data = FileData(name: cleanPath, url: fileURL, isDirectory: isDirectory)
                files.append(data)
            }
            
            return files
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