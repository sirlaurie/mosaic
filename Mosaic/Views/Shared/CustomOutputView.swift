//
//  CustomOutputView.swift
//  Mosaic
//
//

import Combine
import SwiftUI

struct CustomOutputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        let _ = {
            let timestamp = Date().timeIntervalSince1970
            print("📄 [\(timestamp)] CustomOutputView: body evaluated")
            print("   - outputText.count: \(mainViewModel.outputText.count)")
        }()
        VStack(spacing: 0) {
            if mainViewModel.outputText.isEmpty {
                EmptyOutputView()
            } else {
                if #available(macOS 14.0, *) {
                    TextEditor(text: $mainViewModel.outputText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.black.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                        .scrollContentBackground(.hidden)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.5))
                        )
                } else {
                    ScrollView {
                        Text(mainViewModel.outputText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.black.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

struct EmptyOutputView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Content Generated")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Select files from the left panel and click 'Generate Text' to create output.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

struct GenerateButton: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            mainViewModel.generateOutputText()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 8) {
                if mainViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14, weight: .medium))
                }
                Text(mainViewModel.isLoading ? "Generating..." : "Generate Text")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(mainViewModel.isLoading ? .gray.opacity(0.3) : .blue)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isPressed && !mainViewModel.isLoading ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(mainViewModel.isLoading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct TextStatsView: View {
    let text: String
    let isLoading: Bool

    var body: some View {
        HStack {
            Text("\(text.count) characters")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            let lineCount = text.components(separatedBy: .newlines).count
            Text("\(lineCount) lines")
                .font(.caption2)
                .foregroundColor(.secondary)

            if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Processing...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.05))
        )
    }
}
