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
            InputView()

            HistoryView()
        }
    }
}
