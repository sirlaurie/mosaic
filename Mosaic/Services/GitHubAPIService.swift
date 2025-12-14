//
//  GitHubAPIService.swift
//  Mosaic
//
//

import Foundation

private nonisolated struct GitHubTreeResponse: Codable {
    let tree: [GitHubTreeItem]
}

private nonisolated struct GitHubTreeItem: Codable {
    let path: String
    let type: String
    let url: String
    let size: Int?
}

private nonisolated struct GitHubRepositoryResponse: Codable {
    let default_branch: String
}

private nonisolated struct GitHubBlobResponse: Codable {
    let content: String?
    let encoding: String?
    let size: Int?
}

nonisolated final class GitHubAPIService: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches a repository's tree index as a flat list of `FileData` with full relative paths.
    /// - Important: `FileData.url` for files is the GitHub *blob API URL*, which `fetchFileContent(from:)` can decode.
    @concurrent
    func fetchRepositoryFileData(
        owner: String,
        repo: String,
        branch: String? = nil,
        token: String?,
        ignoreMatcher: IgnoreMatcher = IgnoreMatcher(patterns: [])
    ) async throws -> (branch: String, items: [FileData]) {
        let actualBranch = try await resolveBranch(owner: owner, repo: repo, branch: branch, token: token)

        let urlString =
            "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(actualBranch)?recursive=1"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(GitHubTreeResponse.self, from: data)

        let filtered = response.tree.filter { item in
            // Only keep files and directories.
            guard item.type == "blob" || item.type == "tree" else { return false }
            // Apply ignore rules to any path component.
            return !ignoreMatcher.matches(anyPathComponentIn: item.path)
        }

        let items: [FileData] = filtered.compactMap { item in
            guard let apiURL = URL(string: item.url) else { return nil }
            let isDirectory = item.type == "tree"
            return FileData(name: item.path, url: apiURL, isDirectory: isDirectory, isLazy: false)
        }

        return (actualBranch, items)
    }

    private func resolveBranch(owner: String, repo: String, branch: String?, token: String?) async throws -> String {
        if let branch, !branch.isEmpty { return branch }
        return try await fetchDefaultBranch(owner: owner, repo: repo, token: token)
    }

    private func fetchDefaultBranch(owner: String, repo: String, token: String?) async throws -> String {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(GitHubRepositoryResponse.self, from: data)

        return response.default_branch
    }

    @concurrent
    func fetchFileContent(from url: URL, token: String?) async throws -> String {
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)

        // Limit to ~10MB decoded content.
        let maxFileSize = 10 * 1024 * 1024  // 10MB

        // First try decoding GitHub blob JSON (Git Data API).
        if let blob = try? JSONDecoder().decode(GitHubBlobResponse.self, from: data),
           let content = blob.content,
           (blob.encoding ?? "").lowercased() == "base64"
        {
            if let size = blob.size, size > maxFileSize {
                return "[File too large: \(size / 1024 / 1024)MB, skipped]"
            }

            let normalized = content.replacingOccurrences(of: "\n", with: "")
            if let decoded = Data(base64Encoded: normalized) {
                if decoded.count > maxFileSize {
                    return "[File too large: \(decoded.count / 1024 / 1024)MB, skipped]"
                }

                if isBinaryData(decoded) {
                    return "[Binary file, skipped]"
                }

                if let text = String(data: decoded, encoding: .utf8) ?? String(data: decoded, encoding: .ascii) {
                    return text
                }
                return "[Unable to decode file content]"
            }
        }

        // Fallback: treat response as raw text.
        if data.count > maxFileSize {
            return "[File too large: \(data.count / 1024 / 1024)MB, skipped]"
        }

        if isBinaryData(data) {
            return "[Binary file, skipped]"
        }

        if let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            return content
        }
        return "[Unable to decode file content]"
    }

    private func isBinaryData(_ data: Data) -> Bool {
        // 如果包含大量null字节，认为是二进制文件
        let maxBytesToCheck = min(1024, data.count)
        let subset = data.prefix(maxBytesToCheck)
        let nullBytes = subset.filter { $0 == 0 }.count
        return nullBytes > subset.count / 10  // 超过10%为null字节
    }

    // Tree building happens in MainViewModel so we can share the same local/GitHub tree pipeline.
}
