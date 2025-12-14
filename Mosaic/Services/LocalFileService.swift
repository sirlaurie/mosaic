// Mosaic/Services/LocalFileService.swift
import Foundation

nonisolated final class LocalFileService: @unchecked Sendable {
    @concurrent
    func scanDirectory(
        at url: URL,
        customLazyDirectories: [String] = [],
        ignoreMatcher: IgnoreMatcher = IgnoreMatcher(patterns: []),
        includeHiddenFiles: Bool = true,
        includePackageContents: Bool = true
    ) async -> (files: [FileData], gitignore: [String]) {
        var files: [FileData] = []
        var gitignoreRules = [".git/**"]

        let skipDirectories = Set(customLazyDirectories)

        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includePackageContents { options.insert(.skipsPackageDescendants) }
        if !includeHiddenFiles { options.insert(.skipsHiddenFiles) }

        guard
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: options
            )
        else {
            return ([], gitignoreRules)
        }

        // 单遍扫描：同时收集文件和 gitignore 规则
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }

            let name = fileURL.lastPathComponent

            // Always skip .git (even if user removes it from ignore list).
            if name == ".git" {
                enumerator.skipDescendants()
                continue
            }

            guard
                let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                let isDirectory = resourceValues.isDirectory
            else { continue }

            // Apply ignore rules (single-component match).
            if ignoreMatcher.matches(name: name) {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }

            let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
            let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath

            // Lazy-load large directories on demand.
            if isDirectory, skipDirectories.contains(name) {
                enumerator.skipDescendants()
                files.append(FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: true))
                continue
            }

            if isDirectory {
                files.append(FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: false))
            } else {
                files.append(FileData(name: cleanPath, url: fileURL, isDirectory: false))
            }

            // Collect .gitignore rules (currently not applied, but preserved for future).
            if name == ".gitignore", let content = try? String(contentsOf: fileURL, encoding: .utf8) {
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

        return (files, gitignoreRules)
    }

    @concurrent
    func scanSubDirectory(at url: URL, rootURL: URL) async -> [FileData] {
        await scanSubDirectory(
            at: url,
            rootURL: rootURL,
            customLazyDirectories: [],
            ignoreMatcher: IgnoreMatcher(patterns: []),
            includeHiddenFiles: true,
            includePackageContents: true
        )
    }

    @concurrent
    func scanSubDirectory(
        at url: URL,
        rootURL: URL,
        customLazyDirectories: [String],
        ignoreMatcher: IgnoreMatcher,
        includeHiddenFiles: Bool,
        includePackageContents: Bool,
        maxFiles: Int = 10_000
    ) async -> [FileData] {
        var files: [FileData] = []

        let skipDirectories = Set(customLazyDirectories)
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]

        var options: FileManager.DirectoryEnumerationOptions = []
        if !includePackageContents { options.insert(.skipsPackageDescendants) }
        if !includeHiddenFiles { options.insert(.skipsHiddenFiles) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }
            if files.count >= maxFiles { break }

            let name = fileURL.lastPathComponent
            if name == ".git" {
                enumerator.skipDescendants()
                continue
            }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues?.isDirectory ?? false

            if ignoreMatcher.matches(name: name) {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }

            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path, with: "")
            let cleanPath = relativePath.starts(with: "/") ? String(relativePath.dropFirst()) : relativePath

            if isDirectory, skipDirectories.contains(name) {
                enumerator.skipDescendants()
                files.append(FileData(name: cleanPath, url: fileURL, isDirectory: true, isLazy: true))
                continue
            }

            files.append(FileData(name: cleanPath, url: fileURL, isDirectory: isDirectory))
        }

        return files
    }

    @concurrent
    func readFileContent(at url: URL) async throws -> String {
        if Task.isCancelled { throw CancellationError() }

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
