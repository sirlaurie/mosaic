//
//  MosaicApp.swift
//  Mosaic
//
//

import SwiftUI

@main
struct MosaicApp: App {
    private let historyService = HistoryService()
    private let gitHubAPIService = GitHubAPIService()
    private let localFileService = LocalFileService()

    @StateObject private var mainViewModel: MainViewModel
    @StateObject private var historyViewModel: HistoryViewModel

    init() {
        let historyService = HistoryService()
        let gitHubAPIService = GitHubAPIService()
        let localFileService = LocalFileService()

        _mainViewModel = StateObject(
            wrappedValue: MainViewModel(
                gitHubAPIService: gitHubAPIService,
                localFileService: localFileService,
                historyService: historyService
            ))
        _historyViewModel = StateObject(
            wrappedValue: HistoryViewModel(historyService: historyService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mainViewModel)
                .environmentObject(historyViewModel)
        }
    }
}
