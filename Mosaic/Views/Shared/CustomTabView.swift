//
//  CustomTabView.swift
//  Mosaic
//
//

import SwiftUI

struct CustomTabView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.black.opacity(0.08), lineWidth: 1)
                        )
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 0) {
                        TabButton(
                            title: "Local",
                            isSelected: selectedTab == 0,
                            action: { selectedTab = 0 }
                        )

                        TabButton(
                            title: "GitHub",
                            isSelected: selectedTab == 1,
                            action: { selectedTab = 1 }
                        )
                    }
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
            }

            .onChange(of: selectedTab) { _, newValue in
                mainViewModel.currentTabType = TabType(rawValue: newValue) ?? .local
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color.clear)
        .onAppear {
            mainViewModel.currentTabType = TabType.local
        }
    }
}

enum TabType: Int, CaseIterable {
    case local = 0
    case github = 1
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(white: 0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
