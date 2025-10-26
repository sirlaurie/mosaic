//
//  UtilityPanelView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

struct UtilityPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 标签页导航
            TabNavigationView()

            // 工具面板内容
            if mainViewModel.fileTree.isEmpty {
                InputPanelView()
            } else {
                FileSelectionPanelView()
            }
        }
        .frame(width: 180)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// 标签页导航视图
struct TabNavigationView: View {
    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "Local", isSelected: true)
            tabButton(title: "Github", isSelected: false)
        }
        .padding(4)
        .background(.clear)
    }

    private func tabButton(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity, maxHeight: 28)
            .background(isSelected ? Color.black.opacity(0.2) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 输入面板视图
struct InputPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 20) {
            // GitHub URL 输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub URL")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("https://github.com/username/repo", text: $mainViewModel.githubURL)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                    .onSubmit {
                        mainViewModel.fetchGitHubRepository()
                    }
            }
            .padding(.horizontal, 16)

            // GitHub Token 输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Token (Optional)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("Enter token", text: $mainViewModel.githubToken)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)

            // 获取按钮
            Button(action: {
                mainViewModel.fetchGitHubRepository()
            }) {
                Text("Fetch")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical, 20)
    }
}

// 文件选择面板视图
struct FileSelectionPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Selected Files")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    mainViewModel.fileTree = []
                    mainViewModel.outputText = ""
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top])

            List(mainViewModel.fileTree) { rootNode in
                FileTreeView(node: rootNode)
            }
            .listStyle(.plain)
        }
    }
}
