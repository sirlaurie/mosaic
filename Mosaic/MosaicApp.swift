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
        print(String(repeating: "=", count: 60))
        print("🚀 Mosaic App Starting...")
        print("🔍 Logging is ENABLED")
        print("⏰ Timestamp: \(Date().timeIntervalSince1970)")
        print(String(repeating: "=", count: 60))

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

        print("✅ ViewModels initialized")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(mainViewModel)
                .environmentObject(historyViewModel)
        }
    }
}
