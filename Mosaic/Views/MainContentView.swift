//
//  MainContentView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        HStack(spacing: 0) {
            // 左侧工具面板 (180px宽度)
            UtilityPanelView()

            // 分隔线
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(width: 0.5)

            // 主内容区域
            ContentAreaView()
        }
        .frame(maxHeight: .infinity)
    }
}

// 内容区域视图
struct ContentAreaView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 10) {
            if mainViewModel.fileTree.isEmpty {
                // 空状态视图
                EmptyStateView()
            } else {
                // 文件树和输出视图
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

// 空白状态视图
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
            return "Generated Text"
        } else if !mainViewModel.githubURL.isEmpty {
            return "GitHub Repository"
        } else if !mainViewModel.localPath.isEmpty {
            return "Local Directory"
        } else {
            return "Folder"
        }
    }
}

// 文件树头部视图
struct FileTreeHeaderView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        HStack {
            Text("Selected Files")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") {
                mainViewModel.fileTree = []
                mainViewModel.outputText = ""
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

// 生成按钮视图
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
