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

    var body: some View {
        NavigationSplitView {
                VStack(spacing: 0) {
                    CustomTabView()
                        .frame(height: 56, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)

                    CustomInputView()
                        .frame(height: 80, alignment: .top)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)

                    if !mainViewModel.fileTree.isEmpty {
                        FileTreeContainerView()
                            .frame(maxHeight: .infinity)
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
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 13, weight: .medium))
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

                            Spacer()

                            Button(action: {
                                mainViewModel.saveToFile()
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
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            historyViewModel.loadHistory()
        }
    }
}
