//
//  OutputView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

public struct OutputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    public var body: some View {
        VStack {
            TextEditor(text: $mainViewModel.outputText)

            HStack {
                Button("Copy") {
                    // Not implemented yet
                }

                Button("Save") {
                    // Not implemented yet
                }
            }
        }
    }
}
