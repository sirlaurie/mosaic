// File: /Mosaic/Views/Shared/FileTreeView.swift
import SwiftUI

struct FileTreeView: View {
    // 改为 @ObservedObject，因为 FileNode 是一个 class
    @ObservedObject var node: FileNode

    var body: some View {
        if node.data.isDirectory {
            DisclosureGroup(isExpanded: $node.isExpanded) {
                ForEach(node.children) { childNode in
                    FileTreeView(node: childNode)
                }
            } label: {
                // 目录的 label 不包含复选框，避免点击冲突
                HStack(spacing: 4) {
                    checkboxView
                    Image(systemName: "folder")
                    Text(URL(fileURLWithPath: node.data.name).lastPathComponent)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        } else {
            // 文件的显示包含复选框
            HStack(spacing: 4) {
                checkboxView
                Image(systemName: "doc")
                Text(URL(fileURLWithPath: node.data.name).lastPathComponent)
                Spacer()
            }
            .contentShape(Rectangle())
        }
    }

    // 复选框视图，独立出来避免与折叠按钮冲突
    private var checkboxView: some View {
        Button(action: {
            if node.data.isDirectory {
                let shouldSelect = !node.isSelected && !node.isIndeterminate
                node.propagateSelection(selected: shouldSelect)
            } else {
                node.isSelected.toggle()
            }
        }) {
            Image(systemName: node.isSelected ? "checkmark.square.fill" : (node.isIndeterminate ? "minus.square.fill" : "square"))
                .resizable()
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}

// 移除不再使用的 CheckboxModifier
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