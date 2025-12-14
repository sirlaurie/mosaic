import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            PreferencesGeneralPane()
                .tabItem { Label("General", systemImage: "gearshape") }

            PreferencesFiltersPane()
                .tabItem { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
        }
        // Narrower and closer to typical macOS Preferences panels.
        .frame(width: 440, height: 520)
    }
}

private struct PreferencesGeneralPane: View {
    @StateObject private var preferences = UserPreferences.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Include hidden files", isOn: $preferences.includeHiddenFiles)
                    Toggle("Scan package contents (e.g. .xcodeproj)", isOn: $preferences.includePackageContents)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .controlSize(.small)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("These options affect local directory scanning. Ignored patterns still apply.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        // GroupBox titles float above their border; give them room so the first title isn't clipped by the tab header.
        .padding(.top, 20)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PreferencesFiltersPane: View {
    @StateObject private var preferences = UserPreferences.shared
    @State private var newIgnoredPattern: String = ""
    @State private var newLazyDirectory: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ignoredNamesGroup
                lazyDirectoriesGroup
            }
            // GroupBox titles float above their border; give them room so the first title isn't clipped by the tab header.
            .padding(.top, 20)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var ignoredNamesGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("e.g. .DS_Store, node_modules, *.log", text: $newIgnoredPattern)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addIgnoredPattern() }

                    Button("Add") { addIgnoredPattern() }
                        .disabled(newIgnoredPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                List {
                    ForEach(preferences.ignoredNamePatterns, id: \.self) { pattern in
                        HStack(spacing: 10) {
                            Text(pattern)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                preferences.removeIgnoredPattern(pattern)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove")
                        }
                    }
                }
                .frame(height: 160)

                HStack {
                    Button("Restore Defaults") { preferences.restoreDefaultIgnoredPatterns() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .controlSize(.small)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ignored names")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Items matching these patterns will be hidden from the file tree. Patterns match a single path component and support `*` and `?`.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lazyDirectoriesGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("e.g. node_modules", text: $newLazyDirectory)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addLazyDirectory() }

                    Button("Add") { addLazyDirectory() }
                        .disabled(newLazyDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                List {
                    ForEach(preferences.customLazyDirectories, id: \.self) { dir in
                        HStack(spacing: 10) {
                            Text(dir)
                            Spacer()
                            Button(role: .destructive) {
                                preferences.removeLazyDirectory(dir)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove")
                        }
                    }
                }
                .frame(height: 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .controlSize(.small)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lazy-loaded directories")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Directories listed here will appear in the tree but load their children only when expanded (useful for very large dependency folders).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func addIgnoredPattern() {
        let trimmed = newIgnoredPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preferences.addIgnoredPattern(trimmed)
        newIgnoredPattern = ""
    }

    private func addLazyDirectory() {
        let trimmed = newLazyDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preferences.addLazyDirectory(trimmed)
        newLazyDirectory = ""
    }
}


