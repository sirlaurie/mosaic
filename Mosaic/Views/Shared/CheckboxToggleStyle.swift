// Mosaic/Views/Shared/CheckboxToggleStyle.swift
import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    @ObservedObject var node: FileNode

    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            node.propagateSelection(
                selected: node.isSelected || node.isIndeterminate ? false : true)
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
            "checkmark.square.fill"
        } else if node.isIndeterminate {
            "minus.square.fill"
        } else {
            "square"
        }
    }
}
