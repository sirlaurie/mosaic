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
        class IndexNode {
            var children: [String: IndexNode] = [:]
        }

        let sortedItems = selectedItems.sorted { $0.name < $1.name }
        let root = IndexNode()

        // 1. Build the tree, correctly distinguishing files from directories
        for item in sortedItems {
            let pathComponents = item.name.split(separator: "/")
            var currentNode = root

            // Create nodes for directory components
            for i in 0..<(pathComponents.count - 1) {
                let componentName = String(pathComponents[i])
                if currentNode.children[componentName] == nil {
                    currentNode.children[componentName] = IndexNode()
                }
                currentNode = currentNode.children[componentName]!
            }

            // Create a leaf node for the file component
            if let filename = pathComponents.last {
                currentNode.children[String(filename)] = IndexNode() // Files are nodes with no children
            }
        }

        // 2. Build the string index from the tree
        func buildIndex(node: IndexNode, prefix: String = "") -> String {
            var result = ""
            let entries = node.children.keys.sorted()
            for (i, key) in entries.enumerated() {
                let childNode = node.children[key]!
                let isLastItem = i == entries.count - 1
                let linePrefix = isLastItem ? "└── " : "├── "
                let childPrefix = isLastItem ? "    " : "│   "

                result += "\(prefix)\(linePrefix)\(key)\n"
                
                // Only recurse if the child node is a directory (i.e., has children)
                if !childNode.children.isEmpty {
                    result += buildIndex(node: childNode, prefix: "\(prefix)\(childPrefix)")
                }
            }
            return result
        }

        let index = buildIndex(node: root)
        var output = "Directory Structure:\n\n\(index)"

        // 3. Fetch and append file contents
        var fileContentsText = ""
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
                    fileContentsText += "\n\n---\nFile: \(item.name)\n---\n\n\(content)\n"
                }
            }
        }

        output += fileContentsText
        return output
    }
}
