// File: /Mosaic/Views/Shared/FileTreeView.swift
import SwiftUI

struct FileTreeView: View {
    // 改为 @ObservedObject，因为 FileNode 是一个 class
    @ObservedObject var node: FileNode

    var body: some View {
        if node.data.isDirectory {
            DisclosureGroup(isExpanded: .constant(true)) {
                ForEach(node.children) { childNode in
                    FileTreeView(node: childNode)
                }
            } label: {
                labelView
            }
        } else {
            labelView
        }
    }
    
    private var labelView: some View {
        // 我们不再需要 Toggle，因为 CheckboxToggleStyle 已经是一个 Button 了
        HStack {
            Image(systemName: node.data.isDirectory ? "folder" : "doc")
            Text(node.data.name)
        }
        .modifier(CheckboxModifier(node: node))
    }
}

// 创建一个辅助的 ViewModifier 来附加复选框逻辑
struct CheckboxModifier: ViewModifier {
    @ObservedObject var node: FileNode
    
    func body(content: Content) -> some View {
        Button(action: {
            if node.data.isDirectory {
                let shouldSelect = !node.isSelected && !node.isIndeterminate
                node.propagateSelection(selected: shouldSelect)
            } else {
                node.isSelected.toggle()
            }
        }) {
            HStack {
                Image(systemName: node.isSelected ? "checkmark.square.fill" : (node.isIndeterminate ? "minus.square.fill" : "square"))
                    .resizable()
                    .frame(width: 16, height: 16)
                content
            }
        }
        .buttonStyle(.plain)
    }
}