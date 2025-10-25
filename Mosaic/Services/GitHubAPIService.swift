
//
//  GitHubAPIService.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

private struct GitHubTreeResponse: Codable {
    let tree: [GitHubTreeItem]
}

private struct GitHubTreeItem: Codable {
    let path: String
    let type: String // "blob" or "tree"
    let url: String
}

@MainActor
class GitHubAPIService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRepositoryTree(owner: String, repo: String, branch: String = "main", token: String?) async throws -> [FileNode] {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(GitHubTreeResponse.self, from: data)

        // The GitHub API returns a flat list, so we need to build the tree structure.
        return buildTree(from: response.tree)
    }

    func fetchFileContent(from url: URL, token: String?) async throws -> String {
        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.addValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        // Assuming the content is base64 encoded, which it is for the git/blobs API.
        // A more robust implementation would check the encoding type.
        guard let content = String(data: data, encoding: .utf8) else {
            throw RepoError.decodingError(NSError(domain: "GitHubAPIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode file content"]))
        }
        return content
    }

    private func buildTree(from items: [GitHubTreeItem]) -> [FileNode] {
        var nodeDict: [String: FileNode] = [:]
        var rootItems: [FileNode] = []

        // Create all nodes
        for item in items {
            guard let url = URL(string: item.url) else { continue }
            let isDirectory = item.type == "tree"
            let data = FileData(name: (item.path as NSString).lastPathComponent, url: url, isDirectory: isDirectory)
            let newNode = FileNode(data: data, children: isDirectory ? [] : [])
            nodeDict[item.path] = newNode
        }

        // Link nodes
        for item in items {
            let path = item.path
            let parentPath = (path as NSString).deletingLastPathComponent

            if parentPath.isEmpty {
                if let node = nodeDict[path] {
                    rootItems.append(node)
                }
            } else {
                if let parentNode = nodeDict[parentPath], let childNode = nodeDict[path] {
                    childNode.parent = parentNode
                    parentNode.children.append(childNode)
                }
            }
        }

        return rootItems
    }
}
