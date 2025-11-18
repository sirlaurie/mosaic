//
//  FileTreeView.swift
//  Mosaic
//
//

import SwiftUI

struct FileTreeView: View {
    @ObservedObject var node: FileNode
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(width: CGFloat(level * 20), height: 1)

                // Expand/collapse button with larger hit area
                if node.data.isDirectory {
                    Button(action: { node.isExpanded.toggle() }) {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 24, height: 24)
                }

                // Selection indicator and file info in a separate clickable area
                HStack(spacing: 4) {
                    selectionIndicator
                    fileIcon

                    let displayName = {
                        let components = node.data.name.split(separator: "/")
                        return components.last.map(String.init) ?? node.data.name
                    }()
                    Text(displayName)
                        .font(.system(size: 13, weight: node.data.isDirectory ? .medium : .regular))
                        .foregroundColor(node.isSelected ? .blue : .primary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(node.isSelected ? Color.blue.opacity(0.1) : .clear)
                )
                .contentShape(Rectangle())
                .onTapGesture { toggleSelection() }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)

            if node.data.isDirectory, node.isExpanded {
                let sortedChildren = getSortedChildren()
                ForEach(sortedChildren, id: \.id) { childNode in
                    FileTreeView(node: childNode, level: level + 1)
                }
            }
        }
    }

    private var selectionIndicator: some View {
        Button(action: { toggleSelection() }) {
            Image(systemName: selectionIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(selectionColor)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }

    private var selectionIcon: String {
        switch (node.isSelected, node.isIndeterminate) {
        case (true, false):
            "checkmark.circle.fill"
        case (false, true):
            "minus.circle.fill"
        default:
            "circle"
        }
    }

    private var selectionColor: Color {
        switch (node.isSelected, node.isIndeterminate) {
        case (true, false):
            .blue
        case (false, true):
            .orange
        default:
            .secondary
        }
    }

    private var fileIcon: some View {
        Image(systemName: node.data.isDirectory ? "folder.fill" : getFileIcon())
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(node.data.isDirectory ? .blue : getFileIconColor())
            .frame(width: 16, height: 16)
    }

    private func getFileIcon() -> String {
        let fileExtension = node.data.name.components(separatedBy: ".").last?.lowercased() ?? ""

        switch fileExtension {
        case "swift":
            return "swift"
        case "js", "ts", "jsx", "tsx":
            return "square.and.arrow.down"
        case "py":
            return "hare"
        case "java":
            return "cup.and.saucer"
        case "c", "cpp", "h", "hpp":
            return "cpu"
        case "go":
            return "bolt"
        case "rs":
            return "gearshape"
        case "kt":
            return "gearshape.2"
        case "dart":
            return "dial.low.fill"
        case "rb":
            return "gem"
        case "php":
            return "flask"
        case "html", "htm":
            return "globe"
        case "css", "scss", "sass":
            return "paintbrush"
        case "md", "markdown":
            return "doc.text"
        case "json", "xml", "yaml", "yml":
            return "curlybraces"
        case "sql":
            return "database"
        case "sh":
            return "terminal"
        case "dockerfile":
            return "shippingbox"
        case "txt", "text":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }

    private func getFileIconColor() -> Color {
        let fileExtension = node.data.name.components(separatedBy: ".").last?.lowercased() ?? ""

        switch fileExtension {
        case "swift":
            return .orange
        case "js", "ts":
            return .yellow
        case "py":
            return .blue
        case "java":
            return .red
        case "go":
            return .cyan
        case "rs":
            return .black
        case "kt":
            return .purple
        case "dart":
            return .teal
        case "rb":
            return .red
        case "php":
            return .indigo
        case "html", "css":
            return .orange
        case "md":
            return .blue
        case "json", "xml":
            return .green
        case "sql", "sh":
            return .gray
        default:
            return .secondary
        }
    }

    private func toggleSelection() {
        if node.data.isDirectory {
            let shouldSelect = !node.isSelected && !node.isIndeterminate
            node.propagateSelection(selected: shouldSelect)
        } else {
            node.isSelected.toggle()
        }
    }

    private func getSortedChildren() -> [FileNode] {
        node.children.sorted { left, right in
            let leftIsDir = left.data.isDirectory
            let rightIsDir = right.data.isDirectory

            if leftIsDir != rightIsDir {
                return leftIsDir
            }

            return left.data.name.lowercased() < right.data.name.lowercased()
        }
    }
}
