//
//  OutputView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI
import AppKit

public struct OutputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @State private var isCopied = false

    public var body: some View {
        VStack {
            TextEditor(text: $mainViewModel.outputText)

            HStack {
                Button(action: {
                    copyToClipboard()
                }) {
                    HStack {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied!" : "Copy")
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isCopied)

                Button("Save") {
                    // Not implemented yet
                }
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(mainViewModel.outputText, forType: .string)

        // 显示成功反馈
        isCopied = true

        // 1.5秒后恢复原状
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCopied = false
        }
    }
}
