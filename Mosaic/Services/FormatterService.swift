import Foundation

class FormatterService {
    private let localFileService: LocalFileService
    private let gitHubAPIService: GitHubAPIService

    init(localFileService: LocalFileService, gitHubAPIService: GitHubAPIService) {
        self.localFileService = localFileService
        self.gitHubAPIService = gitHubAPIService
    }

    func format(selectedItems: [FileData], rootDirectoryURL: URL, githubToken: String?) async
        -> String
    {
        guard !selectedItems.isEmpty else {
            return "Directory Structure:\n\n(No items selected)"
        }

        let rootDirectoryName = extractRootDirectoryName(from: rootDirectoryURL)

        let (directories, files) = separateDirectoriesAndFiles(from: selectedItems)

        let directoryStructure = buildDirectoryStructure(
            rootName: rootDirectoryName,
            directories: directories,
            files: files
        )

        let fileContents = await fetchFileContents(from: files, githubToken: githubToken)

        let output = """
        Directory Structure:

        \(directoryStructure)

        \(fileContents)
        """

        return output
    }

    private func separateDirectoriesAndFiles(from items: [FileData]) -> (
        directories: [FileData], files: [FileData]
    ) {
        let directories = items.filter(\.isDirectory)
        let files = items.filter { !$0.isDirectory }
        return (directories, files)
    }

    private func extractRootDirectoryName(from rootDirectoryURL: URL) -> String {
        if rootDirectoryURL.host?.contains("github.com") == true {
            let pathComponents = rootDirectoryURL.pathComponents.filter { !$0.isEmpty }
            if pathComponents.count >= 2 {
                return pathComponents[1]
            }
            return "Repository"
        }

        let lastPathComponent = rootDirectoryURL.lastPathComponent
        return lastPathComponent.isEmpty ? "Root" : lastPathComponent
    }

    private func buildDirectoryStructure(
        rootName: String,
        directories: [FileData],
        files: [FileData]
    ) -> String {
        let rootNode = buildTreeStructure(directories: directories, files: files)

        var result = "\(rootName)/\n"
        result += generateTreeText(from: rootNode.children, prefix: "")

        return result
    }

    private func buildTreeStructure(directories: [FileData], files: [FileData]) -> DirectoryNode {
        let root = DirectoryNode(name: "", isDirectory: true)

        for dir in directories {
            addPathToTree(root, path: dir.name, isDirectory: true)
        }

        for file in files {
            addPathToTree(root, path: file.name, isDirectory: false)
        }

        return root
    }

    private func addPathToTree(_ root: DirectoryNode, path: String, isDirectory: Bool) {
        let pathComponents = path.components(separatedBy: "/")
        var currentNode = root

        for (index, component) in pathComponents.enumerated() {
            let isLastComponent = (index == pathComponents.count - 1)

            if currentNode.children[component] == nil {
                let nodeIsDirectory = isLastComponent ? isDirectory : true
                currentNode.children[component] = DirectoryNode(
                    name: component, isDirectory: nodeIsDirectory
                )
            }

            currentNode = currentNode.children[component]!
        }
    }

    private func generateTreeText(from children: [String: DirectoryNode], prefix: String) -> String {
        var result = ""

        let directories = children.filter(\.value.isDirectory)
        let files = children.filter { !$0.value.isDirectory }

        let sortedDirectories = directories.sorted { $0.key.lowercased() < $1.key.lowercased() }
        let sortedFiles = files.sorted { $0.key.lowercased() < $1.key.lowercased() }

        let sortedChildren = sortedDirectories + sortedFiles

        for (index, (name, node)) in sortedChildren.enumerated() {
            let isLast = (index == sortedChildren.count - 1)
            let connector = isLast ? "└── " : "├── "
            let nextPrefix = prefix + (isLast ? "    " : "│   ")

            result += "\(prefix)\(connector)\(name)\n"

            if node.isDirectory, !node.children.isEmpty {
                result += generateTreeText(from: node.children, prefix: nextPrefix)
            }
        }

        return result
    }

    private func fetchFileContents(from files: [FileData], githubToken: String?) async -> String {
        var fileContents: [String: String] = [:]

        // 限制并发数量，避免请求风暴
        let maxConcurrentTasks = 20

        await withTaskGroup(of: (String, String).self) { group in
            var fileIterator = files.makeIterator()
            var activeTasks = 0

            // 初始化：启动前N个任务
            while activeTasks < maxConcurrentTasks, let file = fileIterator.next() {
                group.addTask {
                    await self.fetchSingleFile(file, githubToken: githubToken)
                }
                activeTasks += 1
            }

            // 处理结果并启动新任务
            for await (path, content) in group {
                fileContents[path] = content

                // 当一个任务完成，启动下一个
                if let nextFile = fileIterator.next() {
                    group.addTask {
                        await self.fetchSingleFile(nextFile, githubToken: githubToken)
                    }
                }
            }
        }

        var result = ""
        for file in files {
            if let content = fileContents[file.name] {
                result += "\n\n---\nFile: \(file.name)\n---\n\n\(content)\n"
            }
        }

        return result
    }

    private func fetchSingleFile(_ file: FileData, githubToken: String?) async -> (String, String) {
        do {
            let content: String = if file.url.scheme == "file" {
                try await self.localFileService.readFileContent(at: file.url)
            } else {
                try await self.gitHubAPIService.fetchFileContent(
                    from: file.url, token: githubToken
                )
            }
            return (file.name, content)
        } catch {
            return (file.name, "Error reading file: \(error.localizedDescription)")
        }
    }
}

private class DirectoryNode {
    let name: String
    var isDirectory: Bool
    var children: [String: DirectoryNode] = [:]

    init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }
}
