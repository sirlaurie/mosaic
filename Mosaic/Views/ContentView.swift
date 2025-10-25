
//
//  ContentView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        NavigationSplitView {
            ControlPanelView()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            OutputView()
        }
    }
}
