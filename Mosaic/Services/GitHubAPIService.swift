//
//  GitHubAPIService.swift
//  Mosaic
//
//

import Foundation

private struct GitHubTreeResponse: Codable {
    let tree: [GitHubTreeItem]
}

private struct GitHubTreeItem: Codable {
    let path: String
    let type: String
    let url: String
}

private struct GitHubRepositoryResponse: Codable {
    let default_branch: String
}

class GitHubAPIService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRepositoryTree(owner: String, repo: String, branch: String? = nil, token: String?)
        async throws -> [FileNode]
    {
        // 如果没有指定分支，先获取默认分支
        let actualBranch: String
        if let branch = branch {
            actualBranch = branch
        } else {
            actualBranch = try await fetchDefaultBranch(owner: owner, repo: repo, token: token)
        }

        let urlString =
            "https://api.github.com/repos/\(owner)/\(repo)/git/trees/\(actualBranch)?recursive=1"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(GitHubTreeResponse.self, from: data)

        return buildTree(from: response.tree, repoName: repo)
    }

    private func fetchDefaultBranch(owner: String, repo: String, token: String?) async throws
        -> String
    {
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

    func fetchFileContent(from url: URL, token: String?) async throws -> String {
        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)

        // 检查文件大小（限制10MB）
        let maxFileSize = 10 * 1024 * 1024  // 10MB
        if data.count > maxFileSize {
            return "[File too large: \(data.count / 1024 / 1024)MB, skipped]"
        }

        // 检测是否为二进制文件
        if isBinaryData(data) {
            return "[Binary file, skipped]"
        }

        guard let content = String(data: data, encoding: .utf8) else {
            // 尝试其他编码
            if let content = String(data: data, encoding: .ascii) {
                return content
            }
            return "[Unable to decode file content]"
        }
        return content
    }

    private func isBinaryData(_ data: Data) -> Bool {
        // 如果包含大量null字节，认为是二进制文件
        let maxBytesToCheck = min(1024, data.count)
        let subset = data.prefix(maxBytesToCheck)
        let nullBytes = subset.filter { $0 == 0 }.count
        return nullBytes > subset.count / 10  // 超过10%为null字节
    }

    private func buildTree(from items: [GitHubTreeItem], repoName: String) -> [FileNode] {
        // Create root repository node
        let rootURL = URL(string: "https://github.com/\(repoName)")!
        let rootData = FileData(name: repoName, url: rootURL, isDirectory: true)
        let rootNode = FileNode(data: rootData, children: [])

        var nodeDict: [String: FileNode] = ["": rootNode]

        for item in items {
            guard let url = URL(string: item.url) else { continue }
            let isDirectory = item.type == "tree"
            let data = FileData(
                name: (item.path as NSString).lastPathComponent, url: url, isDirectory: isDirectory
            )
            let newNode = FileNode(data: data, children: isDirectory ? [] : [])
            nodeDict[item.path] = newNode
        }

        for item in items {
            let path = item.path
            let parentPath = (path as NSString).deletingLastPathComponent

            if parentPath.isEmpty {
                if let node = nodeDict[path] {
                    node.parent = rootNode
                    rootNode.children.append(node)
                }
            } else {
                if let parentNode = nodeDict[parentPath], let childNode = nodeDict[path] {
                    childNode.parent = parentNode
                    parentNode.children.append(childNode)
                }
            }
        }

        return [rootNode]
    }
}
