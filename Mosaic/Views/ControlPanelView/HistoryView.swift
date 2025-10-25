//
//  HistoryView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

public struct HistoryView: View {
    @EnvironmentObject var historyViewModel: HistoryViewModel

    @EnvironmentObject var mainViewModel: MainViewModel

    public var body: some View {
        List(historyViewModel.historyItems) { item in
            VStack(alignment: .leading) {
                Text(item.path)
                    .font(.headline)

                Text(item.accessDate, style: .date)
            }

            .onTapGesture {
                mainViewModel.loadHistoryItem(item)
            }
        }

        .onAppear {
            historyViewModel.loadHistory()
        }
    }
}
