
import SwiftUI

public struct FileTreeView: View {
    @EnvironmentObject var mainViewModel: MainViewModel

    public var body: some View {
        OutlineGroup(mainViewModel.fileTree, children: \.children) { item in
            Toggle(isOn: binding(for: item)) {
                Text(item.name)
            }
            .toggleStyle(CheckboxToggleStyle())
        }
    }

    private func binding(for item: FileItem) -> Binding<Bool> {
        Binding<Bool>(
            get: { item.isSelected },
            set: { isSelected in
                if let index = mainViewModel.fileTree.firstIndex(where: { $0.id == item.id }) {
                    mainViewModel.fileTree[index].isSelected = isSelected
                }
            }
        )
    }
}
