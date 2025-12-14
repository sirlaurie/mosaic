//
//  FileTreeContainerView.swift
//  Mosaic
//
//

import Combine
import SwiftUI

struct FileTreeContainerView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Selected Files")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()

                Button("Clear") {
                    mainViewModel.clearWorkspace()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .font(.caption)
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    let visibleIDs = mainViewModel.visibleFileNodeIDs
                    let query = mainViewModel.fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    let roots = mainViewModel.fileTree.filter { node in
                        visibleIDs?.contains(node.id) ?? true
                    }

                    if !query.isEmpty, roots.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(roots) { rootNode in
                            FileTreeView(
                                node: rootNode,
                                level: 0,
                                query: query,
                                visibleNodeIDs: visibleIDs
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Button(action: {
                mainViewModel.generateOutputText()
            }) {
                HStack(spacing: 6) {
                    if mainViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                            .frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Text(mainViewModel.isLoading ? "Generating..." : "Generate Text")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mainViewModel.isLoading ? Color.gray.opacity(0.5) : Color.blue)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(mainViewModel.isLoading)
            .padding(.horizontal, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03) as Color)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.08) as Color, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}
