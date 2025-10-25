//
//  InputView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

public struct InputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    public var body: some View {
        TabView {
            VStack {
                TextField("GitHub URL", text: $mainViewModel.githubURL)

                TextField("GitHub Token (Optional)", text: $mainViewModel.githubToken)

                Button("Fetch") {
                    mainViewModel.fetchGitHubRepository()
                }
            }

            .tabItem {
                Text("GitHub")
            }

            VStack {
                Text(mainViewModel.localPath)

                Button("Select Directory") {
                    mainViewModel.openPanel()
                }
            }

            .tabItem {
                Text("Local Directory")
            }
        }
    }
}
