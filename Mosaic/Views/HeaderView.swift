//
//  HeaderView.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        HStack(spacing: 0) {
            // 左侧操作区域 - "Open"按钮
            leftActionsView

            // 中间动态标题区域
            dynamicTitleView

            Spacer()

            // 右侧毛玻璃操作按钮
            rightActionsView

            // 标准macOS窗口控制按钮
            windowControlButtons
        }
        .frame(height: 36)
    }

    // 左侧操作区域
    private var leftActionsView: some View {
        Button(action: {
            mainViewModel.openPanel()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                Text("Open")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(height: 24)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 动态标题视图
    private var dynamicTitleView: some View {
        HStack(spacing: 10) {
            Text(titleText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "#808080"))

            if mainViewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
            }
        }
        .padding(.leading, 21)
        .padding(.top, 5)
        .padding(.bottom, 4)
    }

    // 右侧操作按钮视图
    private var rightActionsView: some View {
        HStack(spacing: 4) {
            // 第一个毛玻璃按钮 - 设置
            glassButton(icon: "gearshape") {
                showSettings()
            }

            // 第二个毛玻璃按钮 - 分享
            glassButton(icon: "square.and.arrow.up") {
                showShare()
            }
        }
        .padding(.trailing, 4)
    }

    // 毛玻璃按钮组件
    private func glassButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                // 毛玻璃背景层
                ZStack {
                    Circle()
                        .fill(.clear)
                        .frame(width: 36, height: 36)
                }
                .glassEffect(.regular, in: .circle)

                // 图标
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#4C4C4C"))
            }
        }
        .buttonStyle(.plain)
    }

    // 窗口控制按钮
    private var windowControlButtons: some View {
        HStack(spacing: 9) {
            // 关闭按钮
            windowControlButton(color: .red) {
                NSApplication.shared.terminate(nil)
            }

            // 最小化按钮
            windowControlButton(color: .yellow) {
                if let window = NSApplication.shared.windows.first {
                    window.miniaturize(nil)
                }
            }

            // 缩放按钮
            windowControlButton(color: .green) {
                if let window = NSApplication.shared.windows.first {
                    window.zoom(nil)
                }
            }
        }
        .padding(.trailing, 1)
    }

    // 单个窗口控制按钮
    private func windowControlButton(color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Window Control")
    }

    // 动态标题文本
    private var titleText: String {
        if !mainViewModel.outputText.isEmpty {
            return "Generated Text"
        } else if !mainViewModel.githubURL.isEmpty {
            // 从GitHub URL提取仓库名
            let components = mainViewModel.githubURL.components(separatedBy: "/")
            if components.count >= 2 {
                return components.last?.replacingOccurrences(of: ".git", with: "") ?? "GitHub"
            }
            return "GitHub"
        } else if !mainViewModel.localPath.isEmpty {
            return URL(fileURLWithPath: mainViewModel.localPath).lastPathComponent
        } else {
            return "Folder"
        }
    }

    // 显示设置
    private func showSettings() {
        print("Settings clicked")
    }

    // 显示分享
    private func showShare() {
        print("Share clicked")
    }
}

// Color扩展，支持十六进制颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
