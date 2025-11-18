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
        let _ = {
            let timestamp = Date().timeIntervalSince1970
            print("🌲 [\(timestamp)] FileTreeContainerView: body evaluated")
            print("   - fileTree.count: \(mainViewModel.fileTree.count)")
        }()
        VStack(spacing: 8) {
            HStack {
                Text("Selected Files")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()

                Button("Clear") {
                    mainViewModel.fileTree = []
                    mainViewModel.outputText = ""
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
                    ForEach(mainViewModel.fileTree) { rootNode in
                        FileTreeView(node: rootNode, level: 0)
                    }
                }
                .padding(.horizontal, 8)
            }
            .drawingGroup()

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
