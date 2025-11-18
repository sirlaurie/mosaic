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
    @State private var previousFileTreeState = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: columnVisibility)
        .onChange(of: columnVisibility) { oldValue, newValue in
            logSidebarToggle(oldValue, newValue)
        }
        .onChange(of: mainViewModel.fileTree.isEmpty) { oldValue, newValue in
            logFileTreeChange(oldValue, newValue)
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
            CustomTabView()
                .frame(height: 56, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    print("🏷️  CustomTabView appeared")
                }

            inputOrTreeView

            historyOrEmptyView
        }
        .id("sidebar-content")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: false)
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        .onAppear {
            print("📦 Sidebar VStack appeared")
        }
    }

    @ViewBuilder
    private var inputOrTreeView: some View {
        if mainViewModel.fileTree.isEmpty {
            CustomInputView()
                .frame(height: 80, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    let timestamp = Date().timeIntervalSince1970
                    print("✅ [\(timestamp)] CustomInputView appeared")
                }
                .onDisappear {
                    let timestamp = Date().timeIntervalSince1970
                    print("❌ [\(timestamp)] CustomInputView disappeared")
                }
        } else {
            FileTreeContainerView()
                .frame(maxHeight: .infinity)
                .onAppear {
                    let timestamp = Date().timeIntervalSince1970
                    print("✅ [\(timestamp)] FileTreeContainerView appeared")
                }
                .onDisappear {
                    let timestamp = Date().timeIntervalSince1970
                    print("❌ [\(timestamp)] FileTreeContainerView disappeared")
                }
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
        .onAppear {
            print("📄 Detail VStack appeared")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toolbarButtons
            }
        }
    }

    // MARK: - Toolbar Buttons

    private var toolbarButtons: some View {
        HStack(spacing: 6) {
            copyButton
            Spacer()
            saveButton
        }
        .padding(.leading, 12)
        .padding(.trailing, 12)
        .opacity(mainViewModel.fileTree.isEmpty ? 0 : 1)
        .animation(nil, value: mainViewModel.fileTree.isEmpty)
        .disabled(mainViewModel.fileTree.isEmpty)
        .onChange(of: mainViewModel.fileTree.isEmpty) { oldValue, newValue in
            let timestamp = Date().timeIntervalSince1970
            print("🎯 [\(timestamp)] Toolbar: fileTree.isEmpty changed from \(oldValue) to \(newValue)")
        }
    }

    private var copyButton: some View {
        Button(action: handleCopyAction) {
            Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(showCopySuccess ? .green : .primary)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(copyButtonBackground)
    }

    private var copyButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        showCopySuccess ? Color.green.opacity(0.3) : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
    }

    private var saveButton: some View {
        Button(action: {
            mainViewModel.isShowingFileExporter = true
        }) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 15, weight: .medium))
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(saveButtonBackground)
    }

    private var saveButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
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

    private func disableAnimationIfNeeded(_ transaction: inout Transaction, label: String) {
        let timestamp = Date().timeIntervalSince1970
        if transaction.animation != nil {
            print("⚠️ [\(timestamp)] \(label): Unwanted animation detected, disabling it")
            transaction.animation = nil
        }
    }

    private func logSidebarToggle(_ oldValue: NavigationSplitViewVisibility, _ newValue: NavigationSplitViewVisibility) {
        let timestamp = Date().timeIntervalSince1970
        print("🔄 [\(timestamp)] ========== SIDEBAR TOGGLED ==========")
        print("🔄 [\(timestamp)] Sidebar visibility changed: \(oldValue) -> \(newValue)")
        print("🔄 [\(timestamp)] Thread: \(Thread.isMainThread ? "Main" : "Background")")
    }

    private func logFileTreeChange(_ oldValue: Bool, _ newValue: Bool) {
        let timestamp = Date().timeIntervalSince1970
        print("📱 [\(timestamp)] ContentView: fileTree.isEmpty changed from \(oldValue) to \(newValue)")
        print("📊 [\(timestamp)] ContentView: fileTree.count = \(mainViewModel.fileTree.count)")
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
