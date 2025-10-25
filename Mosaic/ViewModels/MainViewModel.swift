//
//  MainViewModel.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import AppKit
import Combine
import Foundation

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var fileTree: [FileNode] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var githubURL: String = ""
    @Published var githubToken: String = ""
    @Published var localPath: String = ""

    @Published var outputText: String = ""

    // MARK: - Services

    private let gitHubAPIService: GitHubAPIService
    private let localFileService: LocalFileService
    private let historyService: HistoryService
    private let formatterService: FormatterService

    // MARK: - Initialization

    init(
        gitHubAPIService: GitHubAPIService,
        localFileService: LocalFileService,
        historyService: HistoryService
    ) {
        self.gitHubAPIService = gitHubAPIService
        self.localFileService = localFileService
        self.historyService = historyService
        formatterService = FormatterService(localFileService: localFileService, gitHubAPIService: gitHubAPIService)
    }

    // MARK: - Public Methods

    func fetchGitHubRepository() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let (owner, repo) = try parseGitHubURL(githubURL)
                let tree = try await gitHubAPIService.fetchRepositoryTree(owner: owner, repo: repo, token: githubToken)
                self.fileTree = tree
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
            
            // 1. Get the flat list of files and gitignore rules from the service
            let (files, gitignoreRules) = await localFileService.scanDirectory(at: url)
            
            // 2. Filter the files using the gitignore rules
            let filteredFiles = files.filter { !isIgnored(filePath: $0.name, gitignoreRules: gitignoreRules) }

            // 3. Build the nested FileNode tree from the filtered flat list
            self.fileTree = buildFileTree(from: filteredFiles)

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
                _ = url.startAccessingSecurityScopedResource()
                localPath = url.path
                selectLocalDirectory()
            }
        }
    }

    func loadHistoryItem(_ item: HistoryItem) {
        switch item.type {
        case .github:
            githubURL = item.path
            fetchGitHubRepository()
        case .local:
            localPath = item.path
            selectLocalDirectory()
        case .zip:
            // Not implemented yet
            break
        }
    }

    func generateOutputText() {
        isLoading = true
        errorMessage = nil

        let selectedFiles = collectSelectedItems(from: fileTree)

        Task {
            let result = await formatterService.format(selectedItems: selectedFiles, githubToken: self.githubToken)

            await MainActor.run {
                self.outputText = result
                self.isLoading = false
            }
        }
    }

    // MARK: - Private Helper Methods
    
        private func isIgnored(filePath: String, gitignoreRules: [String]) -> Bool {
    
            return gitignoreRules.contains(where: { rule in
    
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
    
    
    
                // Convert glob to regex
    
                pattern = pattern
    
                    .replacingOccurrences(of: ".", with: "\\.")
    
                    .replacingOccurrences(of: "*", with: "[^/]*") // More correct glob-to-regex for *
    
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
    
    private func buildFileTree(from files: [FileData]) -> [FileNode] {
        // Ported from the logic in repo2txt/js/utils.js displayDirectoryStructure
        let root = FileNode(data: FileData(name: "", url: URL(fileURLWithPath: ""), isDirectory: true))
        var nodeMap: [String: FileNode] = ["": root]

        for file in files.sorted(by: { $0.name < $1.name }) {
            let pathComponents = file.name.split(separator: "/").map(String.init)
            var currentPath = ""

            for i in 0..<(pathComponents.count - 1) {
                let component = pathComponents[i]
                let parentPath = currentPath
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

                if nodeMap[currentPath] == nil {
                    let dirData = FileData(name: component, url: URL(fileURLWithPath: currentPath), isDirectory: true)
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
        
        // Sort all children alphabetically
        for (_, node) in nodeMap {
            node.children.sort { $0.data.name < $1.data.name }
        }

        return root.children
    }

    private func parseGitHubURL(_ urlString: String) throws -> (owner: String, repo: String) {
        guard let url = URL(string: urlString), url.host == "github.com" else {
            throw RepoError.invalidURL
        }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else {
            throw RepoError.invalidURL
        }
        return (owner: pathComponents[0], repo: pathComponents[1])
    }

    private func collectSelectedItems(from nodes: [FileNode]) -> [FileData] {
        var selected: [FileData] = []
        for node in nodes {
            if !node.data.isDirectory, node.isSelected {
                selected.append(node.data)
            }
            if node.children.isEmpty == false {
                selected.append(contentsOf: collectSelectedItems(from: node.children))
            }
        }
        return selected
    }
}
