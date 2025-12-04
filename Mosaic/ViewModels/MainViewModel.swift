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
    @Published var fileTree: [FileNode] = [] {
        didSet {
            let timestamp = Date().timeIntervalSince1970
            print("🌳 [\(timestamp)] MainViewModel: fileTree changed")
            print("   - Old count: \(oldValue.count), New count: \(fileTree.count)")
            print("   - isEmpty: \(fileTree.isEmpty)")
            print("   - Thread: \(Thread.isMainThread ? "Main" : "Background")")
        }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var githubURL: String = ""
    @Published var githubToken: String = ""
    @Published var localPath: String = ""

    @Published var outputText: String = ""
    @Published var isShowingFileExporter = false

    private var rootDirectoryURL: URL?
    nonisolated(unsafe) private var securityScopedURL: URL?  // 持有security-scoped resource，使用 nonisolated(unsafe) 以便在 deinit 中访问

    @Published var selectedTab: Int = 0
    @Published var currentTabType: TabType = .local

    private let gitHubAPIService: GitHubAPIService
    private let localFileService: LocalFileService
    private let historyService: HistoryService
    private let formatterService: FormatterService
    private let userPreferences = UserPreferences.shared

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
// ... (existing code) ...
    func fetchGitHubRepository() {
        Task {
            self.isLoading = true
            self.errorMessage = nil
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
            self.isLoading = false
        }
    }

    func selectLocalDirectory(url: URL) {
        Task {
            self.isLoading = true
            self.errorMessage = nil

            // 1. Scan files (IO Bound, already async)
            let (files, gitignoreRules) = await localFileService.scanDirectory(at: url, customLazyDirectories: userPreferences.customLazyDirectories)

            // 2. Process files in background (CPU Bound)
            let rootNodes = await Task.detached(priority: .userInitiated) {
                // Define Matcher locally to ensure no MainActor isolation leakage
                struct GitIgnoreMatcher {
                    private let regexCache: [NSRegularExpression]
                    
                    init(rules: [String]) {
                        self.regexCache = rules.compactMap { rule in
                            var pattern = rule.trimmingCharacters(in: .whitespaces)
                            guard !pattern.isEmpty, !pattern.hasPrefix("#") else { return nil }
                            
                            let isAnchored = pattern.hasPrefix("/")
                            if isAnchored { pattern = String(pattern.dropFirst()) }
                            
                            let isDirectory = pattern.hasSuffix("/")
                            if isDirectory { pattern = String(pattern.dropLast()) }
                            
                            pattern = pattern
                                .replacingOccurrences(of: ".", with: "\\.")
                                .replacingOccurrences(of: "*", with: "[^/]*")
                                .replacingOccurrences(of: "?", with: ".")
                            
                            if !isAnchored { pattern = "(^|/)" + pattern }
                            else { pattern = "^" + pattern }
                            
                            if isDirectory { pattern += "(/.*)?$" }
                            else { pattern += "$" }
                            
                            return try? NSRegularExpression(pattern: pattern)
                        }
                    }
                    
                    func matches(filePath: String) -> Bool {
                        let range = NSRange(location: 0, length: filePath.utf16.count)
                        return regexCache.contains { regex in
                            regex.firstMatch(in: filePath, options: [], range: range) != nil
                        }
                    }
                }
                
                // Initialize matcher with pre-compiled regexes
                // let matcher = GitIgnoreMatcher(rules: gitignoreRules)
                
                // Filter files
                // User requested NO filtering by default.
                // .gitignore rules are ignored. Only manually "lazy" directories (handled in scanDirectory) are treated specially.
                let filteredFiles = files
                
                // Build intermediate tree structure
                return self.buildIntermediateTree(from: filteredFiles, rootURL: url)
            }.value

            // 3. Update UI on Main Thread
            self.fileTree = self.convertIntermediateToVM(nodes: rootNodes)
            
            do {
                try await historyService.addHistoryItem(url: url, type: .local)
                NotificationCenter.default.post(name: .didUpdateHistory, object: nil)
            } catch {
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }
    
    // MARK: - Background Tree Building Helpers
    
    private struct IntermediateFileNode {
        let data: FileData
        var children: [IntermediateFileNode]
    }
    
    nonisolated private func buildIntermediateTree(from files: [FileData], rootURL: URL) -> [IntermediateFileNode] {
        let rootName = rootURL.lastPathComponent
        let rootData = FileData(name: rootName, url: rootURL, isDirectory: true)
        
        // Use a class for reference semantics during build, then convert to struct or just use it
        // Actually, using a temporary class is easier for the map logic
        class TempNode {
            let data: FileData
            var children: [TempNode] = []
            init(data: FileData) { self.data = data }
        }
        
        let root = TempNode(data: rootData)
        var nodeMap: [String: TempNode] = ["": root]
        
        let sortedFiles = files.sorted(by: { $0.name < $1.name })
        
        for file in sortedFiles {
            let pathComponents = file.name.split(separator: "/").map(String.init)
            var currentPath = ""
            
            // Ensure parent directories exist
            for i in 0..<(pathComponents.count - 1) {
                let component = pathComponents[i]
                let parentPath = currentPath
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                
                if nodeMap[currentPath] == nil {
                    let dirData = FileData(
                        name: currentPath, url: URL(fileURLWithPath: currentPath), isDirectory: true
                    )
                    let newNode = TempNode(data: dirData)
                    nodeMap[currentPath] = newNode
                    nodeMap[parentPath]?.children.append(newNode)
                }
            }
            
            let fileNode = TempNode(data: file)
            let parentPath = pathComponents.dropLast().joined(separator: "/")
            
            if let parent = nodeMap[parentPath] {
                parent.children.append(fileNode)
            }
            
            if file.isDirectory {
                nodeMap[file.name] = fileNode
            }
        }
        
        // Recursive convert TempNode to IntermediateFileNode and sort children
        func convert(_ node: TempNode) -> IntermediateFileNode {
            let sortedChildren = node.children
                .sorted { $0.data.name < $1.data.name }
                .map { convert($0) }
            return IntermediateFileNode(data: node.data, children: sortedChildren)
        }
        
        return [convert(root)]
    }
    
    private func convertIntermediateToVM(nodes: [IntermediateFileNode], parent: FileNode? = nil) -> [FileNode] {
        return nodes.map { nodeData in
            let hasLoadedChildren = !nodeData.data.isLazy
            let node = FileNode(
                data: nodeData.data,
                children: [], // will fill recursively
                parent: parent,
                hasLoadedChildren: hasLoadedChildren
            )
            
            if nodeData.data.isLazy {
                 node.onExpand = { [weak self] n in self?.handleNodeExpansion(n) }
            }
            
            node.children = convertIntermediateToVM(nodes: nodeData.children, parent: node)
            
            if parent == nil {
                node.isExpanded = true // Expand root
            }
            
            return node
        }
    }
    
    private func handleNodeExpansion(_ node: FileNode) {
        print("🔄 Lazy loading node: \(node.data.name)")
        guard let rootURL = rootDirectoryURL else { return }
        
        Task {
            await MainActor.run { self.isLoading = true }
            
            let subFiles = await localFileService.scanSubDirectory(at: node.data.url, rootURL: rootURL)
            
            await MainActor.run {
                let nodes = self.buildSubTree(from: subFiles, parentNode: node)
                node.children = nodes
                node.hasLoadedChildren = true
                self.isLoading = false
            }
        }
    }
    
    // Helper to build subtree for lazy loading
    private func buildSubTree(from files: [FileData], parentNode: FileNode) -> [FileNode] {
        // This is similar to buildFileTree but we need to attach it to the parent
        // files contain paths relative to ROOT, so we need to reconstruct the structure under parentNode
        
        // Since 'files' list comes from scanSubDirectory, it contains relative paths from ROOT.
        // E.g. parent is "node_modules", file is "node_modules/foo.js".
        
        // We can reuse the logic from buildFileTree but focusing on the children of parentNode.
        // However, buildFileTree builds from scratch.
        
        // Simpler approach for subtree:
        // The files list is flat. We need to turn it into a tree.
        // The parent node is the root of THIS subtree.
        
        var nodeMap: [String: FileNode] = [parentNode.data.name: parentNode]
        
        for file in files.sorted(by: { $0.name < $1.name }) {
            let pathComponents = file.name.split(separator: "/").map(String.init)
            var currentPath = ""
            
            // We need to find where this file attaches to.
            // Since file.name starts with parentNode.data.name (e.g. node_modules/...),
            // we traverse down.
            
            for i in 0..<(pathComponents.count - 1) {
                let component = pathComponents[i]
                let parentPath = currentPath
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                
                if nodeMap[currentPath] == nil {
                    // Create directory node
                    // Note: Check if this is the parentNode itself?
                    if currentPath == parentNode.data.name {
                        // Should be in map already
                        continue
                    }
                    
                    let dirData = FileData(
                        name: currentPath,
                        url: rootDirectoryURL!.appendingPathComponent(currentPath),
                        isDirectory: true,
                        isLazy: false // Sub-directories are not lazy by default unless specifically handled?
                    )
                    // Attach handler just in case
                    let newNode = FileNode(data: dirData, hasLoadedChildren: true)
                    newNode.onExpand = { [weak self] n in self?.handleNodeExpansion(n) }
                    
                    nodeMap[currentPath] = newNode
                    
                    // Attach to parent
                    if let parent = nodeMap[parentPath] {
                        parent.children.append(newNode)
                        newNode.parent = parent
                    }
                }
            }
            
            // Create the file/leaf node
            let fileNode = FileNode(data: file, hasLoadedChildren: !file.isLazy)
            if file.isLazy {
                 fileNode.onExpand = { [weak self] n in self?.handleNodeExpansion(n) }
            }
            
            let parentPath = pathComponents.dropLast().joined(separator: "/")
            
            if let parent = nodeMap[parentPath] {
                parent.children.append(fileNode)
                fileNode.parent = parent
            }
        }
        
        // Sort children of all affected nodes
        for (_, node) in nodeMap {
             node.children.sort { $0.data.name < $1.data.name }
        }
        
        return parentNode.children
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
                selectLocalDirectory(url: url)
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
            loadLocalDirectory(from: item)
        case .zip:
            break
        }
    }

    private func loadLocalDirectory(from item: HistoryItem) {
        // Try to restore URL from bookmark data
        if let bookmarkData = item.bookmarkData {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                // 释放之前的security-scoped resource
                stopAccessingSecurityScopedResource()

                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Failed to access directory: \(item.path). Please select it again."
                    return
                }

                securityScopedURL = url
                localPath = url.path
                rootDirectoryURL = url
                selectLocalDirectory(url: url)
                return
            } catch {
                // Bookmark is invalid, show error
                errorMessage = "Cannot access directory: \(item.path). The directory may have been moved or deleted."
            }
        } else {
            // No bookmark data, show error
            errorMessage = "Cannot access directory: \(item.path). Please select it again from the file browser."
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
}
