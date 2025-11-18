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

                // Selection control buttons
                HStack(spacing: 8) {
                    Button(action: {
                        selectAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 11, weight: .medium))
                            Text("All")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(.blue)

                    Button(action: {
                        deselectAll()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square")
                                .font(.system(size: 11, weight: .medium))
                            Text("None")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(.blue)

                    Button(action: {
                        invertSelection()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                            Text("Invert")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(.blue)

                    Divider()
                        .frame(height: 12)

                    Button("Clear") {
                        mainViewModel.fileTree = []
                        mainViewModel.outputText = ""
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(mainViewModel.fileTree) { rootNode in
                        FileTreeView(node: rootNode, level: 0)
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
                            .scaleEffect(0.7)
                            .tint(.white)
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
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func selectAll() {
        for node in mainViewModel.fileTree {
            node.propagateSelection(selected: true)
        }
    }

    private func deselectAll() {
        for node in mainViewModel.fileTree {
            node.propagateSelection(selected: false)
        }
    }

    private func invertSelection() {
        for node in mainViewModel.fileTree {
            invertNodeSelection(node)
        }
    }

    private func invertNodeSelection(_ node: FileNode) {
        if !node.data.isDirectory {
            node.isSelected.toggle()
        } else {
            for child in node.children {
                invertNodeSelection(child)
            }
            node.updateSelectionFromChildren()
        }
    }
}
