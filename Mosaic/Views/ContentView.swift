//
//  ContentView.swift
//  Mosaic
//
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel
    @State private var showCopySuccess = false
    @State private var sourceSelection: TabType = .local

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .searchable(text: $mainViewModel.fileSearchQuery, prompt: "Search files")
        .onAppear {
            sourceSelection = mainViewModel.currentTabType
        }
        .onChange(of: mainViewModel.currentTabType) { _, newValue in
            // Keep toolbar selection in sync when tab changes via history actions.
            if sourceSelection != newValue {
                sourceSelection = newValue
            }
        }
        .onChange(of: sourceSelection) { _, newValue in
            // Defer publishing to avoid "Publishing changes from within view updates" warnings.
            DispatchQueue.main.async {
                mainViewModel.userDidSelectSource(newValue)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                sourcePicker
            }

            ToolbarItemGroup(placement: .primaryAction) {
                copyToolbarButton
                exportToolbarButton
                clearToolbarButton
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .fileExporter(
            isPresented: $mainViewModel.isShowingFileExporter,
            document: TextDocument(text: mainViewModel.outputText),
            contentType: .plainText,
            defaultFilename: "mosaic-output.txt"
        ) { result in
            handleExportResult(result)
        }
        .onAppear {
            historyViewModel.loadHistory()
        }
    }

    // MARK: - Sidebar Content

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            inputOrTreeView

            historyOrEmptyView
        }
        .id("sidebar-content")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: false)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }

    @ViewBuilder
    private var inputOrTreeView: some View {
        if mainViewModel.fileTree.isEmpty {
            CustomInputView()
                .frame(height: 80, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            FileTreeContainerView()
                .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var historyOrEmptyView: some View {
        if mainViewModel.fileTree.isEmpty && mainViewModel.currentTabType == .local {
            CustomHistoryView()
                .frame(maxHeight: .infinity)
        } else if mainViewModel.fileTree.isEmpty {
            Color.clear
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(spacing: 0) {
            CustomOutputView()
        }
        .id("detail-content")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar Content

    private var sourcePicker: some View {
        Picker("Source", selection: $sourceSelection) {
            Text("Local").tag(TabType.local)
            Text("GitHub").tag(TabType.github)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }

    private var copyToolbarButton: some View {
        Button(action: handleCopyAction) {
            Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
        }
        .help("Copy output")
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .disabled(mainViewModel.outputText.isEmpty)
    }

    private var exportToolbarButton: some View {
        Button(action: { mainViewModel.isShowingFileExporter = true }) {
            Image(systemName: "square.and.arrow.down")
        }
        .help("Export as text…")
        .keyboardShortcut("s", modifiers: [.command])
        .disabled(mainViewModel.outputText.isEmpty)
    }

    private var clearToolbarButton: some View {
        Button(role: .destructive, action: { mainViewModel.clearWorkspace() }) {
            Image(systemName: "trash")
        }
        .help("Clear selection and output")
        .keyboardShortcut("k", modifiers: [.command])
        .disabled(mainViewModel.fileTree.isEmpty && mainViewModel.outputText.isEmpty)
    }

    // MARK: - Helper Methods

    private func handleCopyAction() {
        mainViewModel.copyToClipboard()
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopySuccess = false
            }
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            break
        case .failure(let error):
            mainViewModel.errorMessage = "Error saving file: \(error.localizedDescription)"
        }
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
