// File: /Mosaic/Views/Shared/CheckboxToggleStyle.swift
import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    // 接收 FileNode
    @ObservedObject var node: FileNode

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            // 直接调用向下传播的命令
            node.propagateSelection(selected: node.isSelected || node.isIndeterminate ? false : true)
        }) {
            HStack {
                Image(systemName: imageName)
                    .resizable()
                    .frame(width: 16, height: 16)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }

    private var imageName: String {
        if node.isSelected {
            return "checkmark.square.fill"
        } else if node.isIndeterminate {
            return "minus.square.fill"
        } else {
            return "square"
        }
    }
}