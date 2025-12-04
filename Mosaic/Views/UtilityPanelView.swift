//
//  UtilityPanelView.swift
//  Mosaic
//
//

import SwiftUI

struct UtilityPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabNavigationView()

            if mainViewModel.fileTree.isEmpty {
                InputPanelView()
            } else {
                FileSelectionPanelView()
            }
            
            Spacer()
            
            SettingsButtonView()
        }
        .frame(width: 180)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct TabNavigationView: View {
    var body: some View {
        HStack(spacing: 0) {
            tabButton(title: "Local", isSelected: true)
            tabButton(title: "Github", isSelected: false)
        }
        .padding(4)
        .background(.clear)
    }

    private func tabButton(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity, maxHeight: 28)
            .background(isSelected ? Color.black.opacity(0.2) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct InputPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub URL")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("https://github.com/username/repo", text: $mainViewModel.githubURL)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                    .onSubmit {
                        fetchGitHubRepo()
                    }
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Token (Optional)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField("Enter token", text: $mainViewModel.githubToken)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)

            Button(action: {
                fetchGitHubRepo()
            }) {
                Text("Fetch")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical, 20)
    }
    
    private func fetchGitHubRepo() {
        // Explicitly unwrap to avoid dynamic member lookup ambiguity
        _mainViewModel.wrappedValue.fetchGitHubRepository()
    }
}

struct FileSelectionPanelView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Selected Files")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    mainViewModel.fileTree = []
                    mainViewModel.outputText = ""
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top])

            List(mainViewModel.fileTree) { rootNode in
                FileTreeView(node: rootNode, level: 0)
            }
            .listStyle(.plain)
        }
    }
}

struct SettingsButtonView: View {
    @State private var isShowingSettings = false
    
    var body: some View {
        Button(action: { isShowingSettings = true }) {
            HStack {
                Image(systemName: "gearshape")
                Text("Settings")
            }
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .padding()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var userPreferences = UserPreferences.shared
    @State private var newDirectoryName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ignored / Lazy Directories")
                .font(.headline)
            
            Text("Directories added here will be loaded lazily (on expand).")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("Directory Name (e.g. node_modules)", text: $newDirectoryName)
                    .textFieldStyle(.roundedBorder)
                
                Button("Add") {
                    if !newDirectoryName.isEmpty {
                        userPreferences.addDirectory(newDirectoryName)
                        newDirectoryName = ""
                    }
                }
            }
            
            List {
                ForEach(userPreferences.customLazyDirectories, id: \.self) { dir in
                    HStack {
                        Text(dir)
                        Spacer()
                        Button(action: {
                            userPreferences.removeDirectory(dir)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 200)
            .listStyle(.bordered(alternatesRowBackgrounds: true))
        }
        .padding()
        .frame(width: 300)
    }
}
