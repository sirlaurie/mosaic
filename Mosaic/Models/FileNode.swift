//  Mosaic/Models/FileNode.swift
//
import Combine
import Foundation

struct FileData: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
}

@MainActor
class FileNode: Identifiable, ObservableObject, Hashable {
    let id: UUID
    let data: FileData
    @Published var children: [FileNode]

    @Published var isSelected: Bool {
        didSet {
            if isSelected { isIndeterminate = false }
            parent?.updateSelectionFromChildren()
        }
    }

    @Published var isIndeterminate: Bool
    @Published var isExpanded: Bool = false

    weak var parent: FileNode?

    init(
        data: FileData, children: [FileNode] = [], isSelected: Bool = false, parent: FileNode? = nil
    ) {
        id = data.id
        self.data = data
        self.children = children
        self.isSelected = isSelected
        isIndeterminate = false  // 初始为false
        self.parent = parent
        self.children.forEach { $0.parent = self }
    }

    func propagateSelection(selected: Bool) {
        isSelected = selected
        guard data.isDirectory else { return }
        children.forEach { $0.propagateSelection(selected: selected) }
    }

    func updateSelectionFromChildren() {
        guard data.isDirectory, !children.isEmpty else { return }

        let selectedCount = children.count(where: { $0.isSelected && !$0.isIndeterminate })
        let indeterminateCount = children.count(where: { $0.isIndeterminate })

        if indeterminateCount > 0 || (selectedCount > 0 && selectedCount < children.count) {
            isSelected = false
            isIndeterminate = true
        } else if selectedCount == children.count {
            isSelected = true
            isIndeterminate = false
        } else {  // selectedCount == 0
            isSelected = false
            isIndeterminate = false
        }

        parent?.updateSelectionFromChildren()
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
