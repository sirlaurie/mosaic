//
//  OutputView.swift
//  Mosaic
//
//

import SwiftUI

public struct OutputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    public var body: some View {
        VStack {
            TextEditor(text: $mainViewModel.outputText)

            HStack {
                Button("Copy") {}

                Button("Save") {}
            }
        }
    }
}
