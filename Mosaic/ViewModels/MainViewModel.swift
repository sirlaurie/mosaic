//
//  MainViewModel.swift
//  Mosaic
//
//

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
class MainViewModel: ObservableObject {
    @Published var fileTree: [FileNode] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var githubURL: String = ""
    @Published var githubToken: String = ""
    @Published var localPath: String = ""

    @Published var outputText: String = ""

    private var rootDirectoryURL: URL?
    nonisolated(unsafe) private var securityScopedURL: URL?  // 持有security-scoped resource，使用 nonisolated(unsafe) 以便在 deinit 中访问

    @Published var selectedTab: Int = 0
    @Published var currentTabType: TabType = .local

    private let gitHubAPIService: GitHubAPIService
    private let localFileService: LocalFileService
    private let historyService: HistoryService
    private let formatterService: FormatterService

    init(
        gitHubAPIService: GitHubAPIService,
        localFileService: LocalFileService,
        historyService: HistoryService
    ) {
        self.gitHubAPIService = gitHubAPIService
        self.localFileService = localFileService
        self.historyService = historyService
        formatterService = FormatterService(
            localFileService: localFileService, gitHubAPIService: gitHubAPIService
        )
    }

    func fetchGitHubRepository() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let (owner, repo) = try parseGitHubURL(githubURL)
                let tree = try await gitHubAPIService.fetchRepositoryTree(
                    owner: owner, repo: repo, token: githubToken
                )
                self.fileTree = tree

                rootDirectoryURL = URL(string: "https://github.com/\(owner)/\(repo)")!

                try await historyService.addHistoryItem(path: githubURL, type: .github)
                NotificationCenter.default.post(name: .didUpdateHistory, object: nil)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func selectLocalDirectory() {
        guard !localPath.isEmpty, let url = URL(string: "file://\(localPath)") else { return }

        Task {
            isLoading = true
            errorMessage = nil

            let (files, gitignoreRules) = await localFileService.scanDirectory(at: url)

            let filteredFiles = files.filter {
                !isIgnored(filePath: $0.name, gitignoreRules: gitignoreRules)
            }

            self.fileTree = buildFileTree(from: filteredFiles, rootURL: url)

            do {
                try await historyService.addHistoryItem(path: url.path, type: .local)
                NotificationCenter.default.post(name: .didUpdateHistory, object: nil)
            } catch {
                self.errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func openPanel() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                // 释放之前的security-scoped resource
                stopAccessingSecurityScopedResource()

                // 开始访问新的security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Failed to access the selected directory"
                    return
                }

                securityScopedURL = url
                localPath = url.path
                rootDirectoryURL = url
                selectLocalDirectory()
            }
        }
    }

    private func stopAccessingSecurityScopedResource() {
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
    }

    nonisolated deinit {
        // URL.stopAccessingSecurityScopedResource() 是线程安全的
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func loadHistoryItem(_ item: HistoryItem) {
        switch item.type {
        case .github:
            githubURL = item.path
            fetchGitHubRepository()
        case .local:
            localPath = item.path
            rootDirectoryURL = URL(fileURLWithPath: item.path)
            selectLocalDirectory()
        case .zip:
            break
        }
    }

    func generateOutputText() {
        isLoading = true
        errorMessage = nil

        let selectedFiles = collectSelectedItems(from: fileTree)

        guard let rootURL = rootDirectoryURL else {
            errorMessage = "No root directory selected"
            isLoading = false
            return
        }

        Task {
            let result = await formatterService.format(
                selectedItems: selectedFiles,
                rootDirectoryURL: rootURL,
                githubToken: self.githubToken
            )

            await MainActor.run {
                self.outputText = result
                self.isLoading = false
            }
        }
    }

    private func isIgnored(filePath: String, gitignoreRules: [String]) -> Bool {
        gitignoreRules.contains(where: { rule in
            var pattern = rule.trimmingCharacters(in: .whitespaces)

            guard !pattern.isEmpty, !pattern.hasPrefix("#") else { return false }

            let isAnchored = pattern.hasPrefix("/")

            if isAnchored {
                pattern = String(pattern.dropFirst())
            }

            let isDirectory = pattern.hasSuffix("/")

            if isDirectory {
                pattern = String(pattern.dropLast())
            }

            pattern =
                pattern

                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: "[^/]*")
                .replacingOccurrences(of: "?", with: ".")

            if !isAnchored {
                pattern = "(^|/)" + pattern

            } else {
                pattern = "^" + pattern
            }

            if isDirectory {
                pattern += "(/.*)?$"

            } else {
                pattern += "$"
            }

            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: filePath.utf16.count)

                return regex.firstMatch(in: filePath, options: [], range: range) != nil
            }

            return false

        })
    }

    private func buildFileTree(from files: [FileData], rootURL: URL) -> [FileNode] {
        // Create the root directory node with the actual directory name
        let rootName = rootURL.lastPathComponent
        let rootData = FileData(name: rootName, url: rootURL, isDirectory: true)
        let root = FileNode(data: rootData)
        var nodeMap: [String: FileNode] = ["": root]

        for file in files.sorted(by: { $0.name < $1.name }) {
            let pathComponents = file.name.split(separator: "/").map(String.init)
            var currentPath = ""

            for i in 0..<(pathComponents.count - 1) {
                let component = pathComponents[i]
                let parentPath = currentPath
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

                if nodeMap[currentPath] == nil {
                    let dirData = FileData(
                        name: component, url: URL(fileURLWithPath: currentPath), isDirectory: true
                    )
                    let newNode = FileNode(data: dirData)
                    nodeMap[currentPath] = newNode
                    nodeMap[parentPath]?.children.append(newNode)
                    newNode.parent = nodeMap[parentPath]
                }
            }

            let fileNode = FileNode(data: file)
            let parentPath = pathComponents.dropLast().joined(separator: "/")
            nodeMap[parentPath]?.children.append(fileNode)
            fileNode.parent = nodeMap[parentPath]
        }

        for (_, node) in nodeMap {
            node.children.sort { $0.data.name < $1.data.name }
        }

        // Return array containing the root directory node
        return [root]
    }

    private func parseGitHubURL(_ urlString: String) throws -> (owner: String, repo: String) {
        // 支持多种格式的URL
        var cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果没有scheme，添加https://
        if !cleanedURL.hasPrefix("http://") && !cleanedURL.hasPrefix("https://") {
            cleanedURL = "https://" + cleanedURL
        }

        guard let url = URL(string: cleanedURL) else {
            throw RepoError.invalidURL
        }

        // 支持 github.com 和 www.github.com
        guard let host = url.host,
            host == "github.com" || host == "www.github.com"
        else {
            throw RepoError.invalidURL
        }

        // 获取路径组件，过滤掉 "/"
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else {
            throw RepoError.invalidURL
        }

        let owner = pathComponents[0]
        var repo = pathComponents[1]

        // 移除 .git 后缀
        if repo.hasSuffix(".git") {
            repo = String(repo.dropLast(4))
        }

        // 验证owner和repo格式（只包含字母、数字、连字符、下划线和点）
        let validPattern = "^[a-zA-Z0-9._-]+$"
        guard owner.range(of: validPattern, options: .regularExpression) != nil,
            repo.range(of: validPattern, options: .regularExpression) != nil
        else {
            throw RepoError.invalidURL
        }

        return (owner: owner, repo: repo)
    }

    private func collectSelectedItems(from nodes: [FileNode]) -> [FileData] {
        var selected: [FileData] = []

        for node in nodes {
            if !node.data.isDirectory, node.isSelected {
                selected.append(node.data)
            }

            if !node.children.isEmpty {
                selected.append(contentsOf: collectSelectedItems(from: node.children))
            }
        }

        return selected
    }
}

extension MainViewModel {
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }

    func saveToFile() {
        let savePanel = NSSavePanel()
        if #available(macOS 12.0, *) {
            savePanel.allowedContentTypes = [UTType.text]
        } else {
            savePanel.allowedFileTypes = ["txt"]
        }
        savePanel.nameFieldStringValue = "mosaic-output.txt"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try self.outputText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.errorMessage = "Error saving file: \(error.localizedDescription)"
                }
            }
        }
    }
}
