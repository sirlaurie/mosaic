//  Mosaic/Models/FileNode.swift
//
import Combine
import Foundation

struct FileData: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var isLazy: Bool = false
}

@MainActor
class FileNode: Identifiable, ObservableObject, Hashable {
    let id: UUID
    let data: FileData
    @Published var children: [FileNode]

    private var isBatchUpdating = false

    @Published var isSelected: Bool {
        didSet {
            if isSelected { isIndeterminate = false }
            if !isBatchUpdating {
                parent?.updateSelectionFromChildren()
            }
        }
    }

    @Published var isIndeterminate: Bool
    @Published var isExpanded: Bool = false {
        didSet {
            if isExpanded && !hasLoadedChildren {
                onExpand?(self)
            }
        }
    }
    
    var hasLoadedChildren: Bool
    var onExpand: ((FileNode) -> Void)?

    weak var parent: FileNode?

    init(
        data: FileData,
        children: [FileNode] = [],
        isSelected: Bool = false,
        parent: FileNode? = nil,
        hasLoadedChildren: Bool = true,
        onExpand: ((FileNode) -> Void)? = nil
    ) {
        id = data.id
        self.data = data
        self.children = children
        self.isSelected = isSelected
        isIndeterminate = false  // 初始为false
        self.parent = parent
        self.hasLoadedChildren = hasLoadedChildren
        self.onExpand = onExpand
        self.children.forEach { $0.parent = self }
    }
    
    /// Toggles selection initiated by user interaction.
    /// This efficiently propagates changes down and triggers a single upward update chain.
    func toggleSelection() {
        if data.isDirectory {
            let shouldSelect = !isSelected && !isIndeterminate
            // 1. Propagate down efficiently (without triggering parent updates)
            propagateSelection(selected: shouldSelect)
            
            // 2. Trigger upward update ONCE from this node's parent
            parent?.updateSelectionFromChildren()
        } else {
            isSelected.toggle()
            // Normal didSet handles upward propagation for leaf nodes
        }
    }

    /// Recursively sets selection state downwards.
    /// Uses batch flag to prevent O(N^2) upward notifications during recursion.
    func propagateSelection(selected: Bool) {
        isBatchUpdating = true
        defer { isBatchUpdating = false }
        
        if isSelected != selected || isIndeterminate {
            isSelected = selected
            isIndeterminate = false
        }
        
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
