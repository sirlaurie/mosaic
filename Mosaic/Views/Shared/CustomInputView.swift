//
//  CustomInputView.swift
//  Mosaic
//
//

import SwiftUI

struct CustomInputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack(spacing: 12) {
            switch mainViewModel.currentTabType {
            case .local:
                LocalInputView()
            case .github:
                GitHubInputView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

struct LocalInputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    @State private var buttonSize: CGSize = .init(width: 120, height: 36)

    var body: some View {
        VStack {
            Button(action: {
                mainViewModel.openPanel()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .frame(width: buttonSize.width, height: buttonSize.height)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            )
        }
    }
}

struct GitHubInputView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub Repository URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                CustomTextField(
                    placeholder: "https://github.com/username/repo",
                    text: $mainViewModel.githubURL
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub Token (Optional)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                CustomSecureField(
                    placeholder: "Enter your GitHub token",
                    text: $mainViewModel.githubToken
                )
            }

            ActionButton(
                icon: "arrow.clockwise",
                title: "Fetch",
                action: {
                    mainViewModel.fetchGitHubRepository()
                }
            )
            .disabled(mainViewModel.githubURL.isEmpty)
        }
    }
}

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.black.opacity(0.08), lineWidth: 1)
                    )
            )
            .textFieldStyle(.plain)
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.black.opacity(0.08), lineWidth: 1)
                    )
            )
            .textFieldStyle(.plain)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    var size: ButtonSize = .medium
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            }
        }) {
            HStack(spacing: size.iconTextSpacing) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: size.fontSize, weight: .medium))
                }
                Image(systemName: icon)
                    .font(.system(size: size.iconFontSize, weight: .medium))
            }
            .foregroundColor(isDisabled ? .secondary : .primary)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .scaleEffect(isPressed && !isDisabled ? 0.95 : 1.0)
            .background(
                Group {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(.clear)
                    } else {
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: size.cornerRadius)
                                    .stroke(.black.opacity(0.08), lineWidth: size.borderWidth)
                            )
                            .shadow(
                                color: .black.opacity(0.1),
                                radius: size.shadowRadius,
                                x: 0,
                                y: size.shadowOffset
                            )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(isDisabled)
    }
}

enum ButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small:
            20
        case .medium:
            24
        case .large:
            32
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small:
            4
        case .medium:
            6
        case .large:
            8
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small:
            11
        case .medium:
            13
        case .large:
            15
        }
    }

    var iconFontSize: CGFloat {
        switch self {
        case .small:
            10
        case .medium:
            13
        case .large:
            16
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            8
        case .medium:
            12
        case .large:
            16
        }
    }

    var iconTextSpacing: CGFloat {
        switch self {
        case .small:
            2
        case .medium:
            4
        case .large:
            6
        }
    }

    var borderWidth: CGFloat {
        0.5
    }

    var shadowRadius: CGFloat {
        switch self {
        case .small:
            1
        case .medium:
            2
        case .large:
            4
        }
    }

    var shadowOffset: CGFloat {
        1
    }
}
