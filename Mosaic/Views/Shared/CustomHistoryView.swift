//
//  CustomHistoryView.swift
//  Mosaic
//
//

import Combine
import SwiftUI

struct CustomHistoryView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if historyViewModel.historyItems.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(historyViewModel.historyItems.prefix(10)) { item in
                                HistoryItemView(item: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    HStack {
                        Spacer()
                        ClearHistoryButton()
                        Spacer()
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Recent Items")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Local directories and GitHub repositories you've opened will appear here")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct HistoryItemView: View {
    let item: HistoryItem
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        Button(action: {
            mainViewModel.loadHistoryItem(item)
        }) {
            HStack(spacing: 8) {
                imageView

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayPath)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(formatDate(item.accessDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(itemTypeDisplay)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.black.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
            .scaleEffect(1.0)
        }
        .buttonStyle(.plain)
        .onHover { _ in
        }
    }

    private var displayPath: String {
        switch item.type {
        case .local:
            URL(fileURLWithPath: item.path).lastPathComponent
        case .github:
            item.path
        case .zip:
            URL(fileURLWithPath: item.path).lastPathComponent
        }
    }

    private var itemTypeDisplay: String {
        switch item.type {
        case .local:
            "Local"
        case .github:
            "GitHub"
        case .zip:
            "ZIP"
        }
    }

    private var imageView: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 24, height: 24)

            Image(systemName: iconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch item.type {
        case .local:
            "folder"
        case .github:
            "github"
        case .zip:
            "archivebox"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .local:
            .blue
        case .github:
            .gray
        case .zip:
            .orange
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let _ = Calendar.current

        let timeInterval = now.timeIntervalSince(date)
        let minutes = Int(timeInterval / 60)
        let hours = Int(timeInterval / 3600)
        let days = Int(timeInterval / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days < 7 {
            return "\(days)d ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

struct ClearHistoryButton: View {
    @EnvironmentObject var historyViewModel: HistoryViewModel
    @State private var showingClearConfirmation = false

    var body: some View {
        Button(action: {
            showingClearConfirmation = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.caption2)
                Text("Clear")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Clear History", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("Are you sure you want to clear all history? This action cannot be undone.")
        }
    }

    private func clearHistory() {
        historyViewModel.clearHistory()
    }
}

struct HistoryLoadingView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)

            Text("Loading history...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }
}
