// File: /Mosaic/Models/FileNode.swift
import Combine
import Foundation

// 数据模型保持为Struct，纯粹且可哈希
struct FileData: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
}

// 引入一个ObservableObject的包装类
 @MainActor
class FileNode: Identifiable, ObservableObject, Hashable {
    let id: UUID
    let data: FileData
    @Published var children: [FileNode]

    // MARK: - FIX 1: 引入独立的'isIndeterminate'状态
    // 我们需要两个状态来表示三态：'isSelected' (on) 和 'isIndeterminate' (partial)
    @Published var isSelected: Bool {
        didSet {
            // 当isSelected改变时，确保isIndeterminate为false
            if isSelected { isIndeterminate = false }
            parent?.updateSelectionFromChildren()
        }
    }
    @Published var isIndeterminate: Bool
    @Published var isExpanded: Bool = true {
        didSet {
            // 当isIndeterminate改变时，确保isSelected为false
            if isIndeterminate { isSelected = false }
            parent?.updateSelectionFromChildren()
        }
    }

    weak var parent: FileNode?

    init(data: FileData, children: [FileNode] = [], isSelected: Bool = false, parent: FileNode? = nil) {
        self.id = data.id
        self.data = data
        self.children = children
        self.isSelected = isSelected
        self.isIndeterminate = false // 初始为false
        self.parent = parent
        self.children.forEach { $0.parent = self }
    }
    
    // MARK: - FIX 2: 单向状态更新函数
    
    // 向下传播状态
    func propagateSelection(selected: Bool) {
        self.isSelected = selected
        guard data.isDirectory else { return }
        children.forEach { $0.propagateSelection(selected: selected) }
    }

    // 从子节点向上更新自己的状态
    func updateSelectionFromChildren() {
        guard data.isDirectory, !children.isEmpty else { return }

        let selectedCount = children.filter { $0.isSelected && !$0.isIndeterminate }.count
        let indeterminateCount = children.filter { $0.isIndeterminate }.count

        if indeterminateCount > 0 || (selectedCount > 0 && selectedCount < children.count) {
            self.isSelected = false
            self.isIndeterminate = true
        } else if selectedCount == children.count {
            self.isSelected = true
            self.isIndeterminate = false
        } else { // selectedCount == 0
            self.isSelected = false
            self.isIndeterminate = false
        }
        
        // 继续向上传播
        parent?.updateSelectionFromChildren()
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}