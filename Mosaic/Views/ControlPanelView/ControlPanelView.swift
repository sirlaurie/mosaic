//
//  ControlPanelView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

public struct ControlPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    public var body: some View {
        VStack {
            if mainViewModel.fileTree.isEmpty {
                InputView()
                HistoryView()
            } else {
                HStack {
                    Text("Selected Files")
                        .font(.headline)
                    Spacer()
                    Button("Select All") {
                        mainViewModel.selectAll()
                    }
                    .font(.system(size: 12))

                    Button("Deselect All") {
                        mainViewModel.deselectAll()
                    }
                    .font(.system(size: 12))

                    Button("Clear") {
                        mainViewModel.fileTree = []
                        mainViewModel.outputText = ""
                    }
                }
                .padding([.horizontal, .top])

                List(mainViewModel.fileTree) { rootNode in
                    FileTreeView(node: rootNode)
                }

                Button(action: {
                    mainViewModel.generateOutputText()
                }) {
                    HStack {
                        Image(systemName: "text.alignleft")
                        Text("Generate Text")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
