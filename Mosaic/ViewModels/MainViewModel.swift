
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

    @Published var fileTree: [FileItem] = []
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

    // MARK: - Initialization

    init(
        gitHubAPIService: GitHubAPIService,
        localFileService: LocalFileService,
        historyService: HistoryService
    ) {
        self.gitHubAPIService = gitHubAPIService
        self.localFileService = localFileService
        self.historyService = historyService
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
        // This would typically use NSOpenPanel, which is a UI concern.
        // For the view model, we'll assume the URL is passed in.
        guard !localPath.isEmpty, let url = URL(string: "file://\(localPath)") else { return }

        Task {
            isLoading = true
            errorMessage = nil
            let tree = await localFileService.scanDirectory(at: url)
            self.fileTree = tree
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
        // This will be implemented in a later stage, likely involving FormatterService
        let selectedItems = collectSelectedItems(from: fileTree)
        // For now, just list the selected file paths
        outputText = selectedItems.map(\.url.path).joined(separator: "\n")
    }

    // MARK: - Private Helper Methods

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

    private func collectSelectedItems(from items: [FileItem]) -> [FileItem] {
        var selected: [FileItem] = []
        for item in items {
            if item.isSelected {
                selected.append(item)
            }
            if let children = item.children {
                selected.append(contentsOf: collectSelectedItems(from: children))
            }
        }
        return selected
    }
}
