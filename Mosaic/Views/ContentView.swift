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

    var body: some View {
        NavigationSplitView {
                VStack(spacing: 0) {
                    CustomTabView()
                        .frame(height: 56, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)

                    if mainViewModel.fileTree.isEmpty {
                        CustomInputView()
                            .frame(height: 80, alignment: .top)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if !mainViewModel.fileTree.isEmpty {
                        FileTreeContainerView()
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else if mainViewModel.currentTabType == .local {
                        CustomHistoryView()
                            .frame(maxHeight: .infinity)
                    } else {
                        Color.clear
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .fixedSize(horizontal: false, vertical: false)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)

            } detail: {
                VStack(spacing: 0) {
                    CustomOutputView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 6) {
                            Button(action: {
                                mainViewModel.copyToClipboard()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCopySuccess = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showCopySuccess = false
                                    }
                                }
                            }) {
                                Image(systemName: showCopySuccess ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(showCopySuccess ? .green : .primary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(showCopySuccess ? Color.green.opacity(0.3) : Color.black.opacity(0.08), lineWidth: 0.5)
                                    )
                            )

                            Spacer()

                            Button(action: {
                                mainViewModel.isShowingFileExporter = true
                            }) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(.black.opacity(0.08), lineWidth: 0.5)
                                    )
                            )
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 12)
                        .opacity(mainViewModel.fileTree.isEmpty ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: mainViewModel.fileTree.isEmpty)
                        .disabled(mainViewModel.fileTree.isEmpty)
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .fileExporter(
            isPresented: $mainViewModel.isShowingFileExporter,
            document: TextDocument(text: mainViewModel.outputText),
            contentType: .plainText,
            defaultFilename: "mosaic-output.txt"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                mainViewModel.errorMessage = "Error saving file: \(error.localizedDescription)"
            }
        }
        .onAppear {
            historyViewModel.loadHistory()
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
