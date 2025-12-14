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
final class MainViewModel: ObservableObject {
    @Published var fileTree: [FileNode] = [] {
        didSet { scheduleSearchVisibilityUpdate() }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var githubURL: String = ""
    @Published var githubToken: String = ""
    @Published var localPath: String = ""

    @Published var outputText: String = ""
    @Published var isShowingFileExporter = false

    @Published var fileSearchQuery: String = "" {
        didSet { scheduleSearchVisibilityUpdate() }
    }
    @Published private(set) var visibleFileNodeIDs: Set<UUID>? = nil

    private var rootDirectoryURL: URL?
    nonisolated(unsafe) private var securityScopedURL: URL?  // 持有security-scoped resource，使用 nonisolated(unsafe) 以便在 deinit 中访问

    @Published var currentTabType: TabType = .local

    private let gitHubAPIService: GitHubAPIService
    private let localFileService: LocalFileService
    private let historyService: HistoryService
    private let formatterService: FormatterService
    private let userPreferences = UserPreferences.shared

    private var loadTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var generateTask: Task<Void, Never>?
    private var searchVisibilityTask: Task<Void, Never>?

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

    func clearWorkspace() {
        loadTask?.cancel()
        fetchTask?.cancel()
        generateTask?.cancel()
        searchVisibilityTask?.cancel()

        stopAccessingSecurityScopedResource()
        rootDirectoryURL = nil

        isLoading = false
        errorMessage = nil
        fileSearchQuery = ""
        fileTree = []
        outputText = ""
    }

    /// User-initiated source switching from the toolbar picker.
    /// We defer cleanup to the next runloop to avoid "Publishing changes from within view updates" warnings.
    func userDidSelectSource(_ newValue: TabType) {
        guard currentTabType != newValue else { return }
        currentTabType = newValue
        clearWorkspace()
    }

    private func scheduleSearchVisibilityUpdate() {
        searchVisibilityTask?.cancel()
        searchVisibilityTask = Task { @MainActor in
            // Avoid publishing derived state during a view update cycle.
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
            if Task.isCancelled { return }
            self.updateSearchVisibility()
        }
    }

    private func updateSearchVisibility() {
        let query = fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            visibleFileNodeIDs = nil
            return
        }

        var visible: Set<UUID> = []

        func markAncestorsVisible(_ node: FileNode) {
            var current = node.parent
            while let parent = current {
                visible.insert(parent.id)
                current = parent.parent
            }
        }

        func walk(_ node: FileNode, inheritedVisible: Bool) {
            let name = node.data.name.lowercased()
            let matchesSelf = name.contains(query)
            let directoryMatches = matchesSelf && node.data.isDirectory
            let shouldShow = inheritedVisible || matchesSelf

            if shouldShow { visible.insert(node.id) }
            if matchesSelf { markAncestorsVisible(node) }

            let nextInherited = inheritedVisible || directoryMatches
            for child in node.children {
                walk(child, inheritedVisible: nextInherited)
            }
        }

        for root in fileTree {
            walk(root, inheritedVisible: false)
        }

        visibleFileNodeIDs = visible
    }
    func fetchGitHubRepository() {
        fetchTask?.cancel()
        loadTask?.cancel()
        generateTask?.cancel()

        isLoading = true
        errorMessage = nil
        fileSearchQuery = ""

        let inputURL = githubURL
        let token = githubToken

        let (owner, repo): (String, String)
        do {
            (owner, repo) = try parseGitHubURL(inputURL)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        let ignoreMatcher = IgnoreMatcher(patterns: userPreferences.ignoredNamePatterns)
        let repoHTMLURL = URL(string: "https://github.com/\(owner)/\(repo)")!

        fetchTask = Task { @MainActor in
            do {
                let (_, items) = try await gitHubAPIService.fetchRepositoryFileData(
                    owner: owner,
                    repo: repo,
                    token: token,
                    ignoreMatcher: ignoreMatcher
                )

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                let rootNodes = await MainViewModel.buildIntermediateTree(from: items, rootURL: repoHTMLURL)

                guard !Task.isCancelled else {
                    isLoading = false
                    return
                }

                rootDirectoryURL = repoHTMLURL
                fileTree = convertIntermediateToVM(nodes: rootNodes)
                isLoading = false

                do {
                    try await historyService.addHistoryItem(path: inputURL, type: .github)
                NotificationCenter.default.post(name: .didUpdateHistory, object: nil)
                } catch {
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func selectLocalDirectory(url: URL) {
        loadTask?.cancel()
        generateTask?.cancel()

        isLoading = true
        errorMessage = nil
        fileSearchQuery = ""

        let lazyDirectories = userPreferences.customLazyDirectories
        let ignoreMatcher = IgnoreMatcher(patterns: userPreferences.ignoredNamePatterns)
        let includeHiddenFiles = userPreferences.includeHiddenFiles
        let includePackageContents = userPreferences.includePackageContents

        loadTask = Task { @MainActor in
            let (files, _) = await localFileService.scanDirectory(
                at: url,
                customLazyDirectories: lazyDirectories,
                ignoreMatcher: ignoreMatcher,
                includeHiddenFiles: includeHiddenFiles,
                includePackageContents: includePackageContents
            )

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            let rootNodes = await MainViewModel.buildIntermediateTree(from: files, rootURL: url)

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            fileTree = convertIntermediateToVM(nodes: rootNodes)
            rootDirectoryURL = url
            isLoading = false

            do {
                try await historyService.addHistoryItem(url: url, type: .local)
                NotificationCenter.default.post(name: .didUpdateHistory, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Background Tree Building Helpers

    private struct IntermediateFileNode {
        let data: FileData
        var children: [IntermediateFileNode]
    }

    @concurrent
    nonisolated private static func buildIntermediateTree(from files: [FileData], rootURL: URL) async -> [IntermediateFileNode] {
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
                        name: currentPath, url: rootURL.appendingPathComponent(currentPath), isDirectory: true
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
        guard let rootURL = rootDirectoryURL else { return }

        isLoading = true

        let nodeID = node.id
        let nodeURL = node.data.url

        let lazyDirectories = userPreferences.customLazyDirectories
        let ignoreMatcher = IgnoreMatcher(patterns: userPreferences.ignoredNamePatterns)
        let includeHiddenFiles = userPreferences.includeHiddenFiles
        let includePackageContents = userPreferences.includePackageContents

        Task { @MainActor in
            let subFiles = await localFileService.scanSubDirectory(
                at: nodeURL,
                rootURL: rootURL,
                customLazyDirectories: lazyDirectories,
                ignoreMatcher: ignoreMatcher,
                includeHiddenFiles: includeHiddenFiles,
                includePackageContents: includePackageContents
            )

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            guard let parentNode = findNode(with: nodeID, in: fileTree) else {
                isLoading = false
                return
            }

            let nodes = buildSubTree(from: subFiles, parentNode: parentNode)
            parentNode.children = nodes
            parentNode.hasLoadedChildren = true
            isLoading = false
        }
    }

    private func findNode(with id: UUID, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(with: id, in: node.children) { return found }
        }
        return nil
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
            currentTabType = .github
            githubURL = item.path
            fetchGitHubRepository()
        case .local:
            currentTabType = .local
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
        generateTask?.cancel()

        isLoading = true
        errorMessage = nil

        let selectedFiles = collectSelectedItems(from: fileTree)

        guard let rootURL = rootDirectoryURL else {
            errorMessage = "No root directory selected"
            isLoading = false
            return
        }

        let token = githubToken
        generateTask = Task { @MainActor in
            let result = await formatterService.format(
                selectedItems: selectedFiles,
                rootDirectoryURL: rootURL,
                githubToken: token
            )

            guard !Task.isCancelled else {
                isLoading = false
                return
            }

            outputText = result
            isLoading = false
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
