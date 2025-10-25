// File: /Mosaic/Services/FormatterService.swift
import Foundation

class FormatterService {
    // 依赖注入文件读取服务
    private let localFileService: LocalFileService
    private let gitHubAPIService: GitHubAPIService

    init(localFileService: LocalFileService, gitHubAPIService: GitHubAPIService) {
        self.localFileService = localFileService
        self.gitHubAPIService = gitHubAPIService
    }

    func format(selectedItems: [FileData], githubToken: String?) async -> String {
        // Ported from repo2txt/js/utils.js -> formatRepoContents
        var output = ""
        var index = ""

        // 1. Build the text-based directory index
        let sortedItems = selectedItems.sorted { $0.name < $1.name }
        var tree: [String: Any] = [:]
        for item in sortedItems {
            let pathComponents = item.name.split(separator: "/")
            var currentLevel: [String: Any] = tree
            for i in 0..<pathComponents.count {
                let component = String(pathComponents[i])
                if i == pathComponents.count - 1 {
                    currentLevel[component] = nil // Mark as file
                } else {
                    if currentLevel[component] == nil {
                        currentLevel[component] = [String: Any]()
                    }
                    currentLevel = currentLevel[component] as! [String: Any]
                }
            }
        }
        
        func buildIndex(node: [String: Any], prefix: String = "") -> String {
            var result = ""
            let entries = node.keys.sorted()
            for (i, key) in entries.enumerated() {
                let isLastItem = i == entries.count - 1
                let linePrefix = isLastItem ? "└── " : "├── "
                let childPrefix = isLastItem ? "    " : "│   "
                
                result += "\(prefix)\(linePrefix)\(key)\n"
                if let subNode = node[key] as? [String: Any] {
                    result += buildIndex(node: subNode, prefix: "\(prefix)\(childPrefix)")
                }
            }
            return result
        }

        index = buildIndex(node: tree)
        output += "Directory Structure:\n\n\(index)"

        // 2. Fetch and append file contents
        await withTaskGroup(of: (String, String).self) {
            group in
            for item in sortedItems {
                group.addTask {
                    do {
                        let content: String
                        if item.url.scheme == "file" {
                            content = try await self.localFileService.readFileContent(at: item.url)
                        } else {
                            content = try await self.gitHubAPIService.fetchFileContent(from: item.url, token: githubToken)
                        }
                        return (item.name, content)
                    } catch {
                        return (item.name, "Error reading file: \(error.localizedDescription)")
                    }
                }
            }

            var fileContents: [String: String] = [:]
            for await (path, content) in group {
                fileContents[path] = content
            }

            for item in sortedItems {
                if let content = fileContents[item.name] {
                    output += "\n\n---\nFile: \(item.name)\n---\n\n\(content)\n"
                }
            }
        }

        return output
    }
}
