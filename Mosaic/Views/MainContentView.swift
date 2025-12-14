//
//  MainContentView.swift
//  Mosaic
//
//

import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        HStack(spacing: 0) {
            UtilityPanelView()

            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(width: 0.5)

            ContentAreaView()
        }
        .frame(maxHeight: .infinity)
    }
}

struct ContentAreaView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 10) {
            if mainViewModel.fileTree.isEmpty {
                EmptyStateView()
            } else {
                VStack(spacing: 10) {
                    FileTreeHeaderView()
                    OutputView()
                    GenerateButtonView()
                }
            }
        }
        .frame(width: 655, height: 551)
        .background(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 8)
        .padding(.top, 10)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.secondary)

                Text("Select a local directory or enter a GitHub repository URL to get started")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var titleText: String {
        if !mainViewModel.outputText.isEmpty {
            "Generated Text"
        } else if !mainViewModel.githubURL.isEmpty {
            "GitHub Repository"
        } else if !mainViewModel.localPath.isEmpty {
            "Local Directory"
        } else {
            "Folder"
        }
    }
}

struct FileTreeHeaderView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        HStack {
            Text("Selected Files")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") {
                mainViewModel.clearWorkspace()
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

struct GenerateButtonView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        Button(action: {
            mainViewModel.generateOutputText()
        }) {
            HStack {
                Image(systemName: "text.alignleft")
                Text("Generate Text")
            }
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .padding()
    }
}
