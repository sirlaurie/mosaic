
//
//  LocalFileService.swift
//  Mosaic
//
//  Created by Gemini on 2025/10/25.
//

import Foundation

class LocalFileService {
    func scanDirectory(at url: URL) async -> [FileItem] {
        await Task.detached {
            var items: [FileItem] = []
            let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
                return []
            }

            var directoryMap: [URL: FileItem] = [:]

            for fileURL in enumerator.allObjects.compactMap({ $0 as? URL }) {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isDirectory = resourceValues.isDirectory,
                      let name = resourceValues.name
                else {
                    continue
                }

                let item = FileItem(name: name, url: fileURL, children: isDirectory ? [] : nil)

                if fileURL.hasDirectoryPath {
                    directoryMap[fileURL] = item
                }

                let parentURL = fileURL.deletingLastPathComponent()
                if var parentItem = directoryMap[parentURL] {
                    parentItem.children?.append(item)
                    directoryMap[parentURL] = parentItem // Re-assign to update the map
                } else {
                    if parentURL == url { // Direct child of the root
                        items.append(item)
                    }
                }
            }

            // This is a simplified tree construction. For a more robust solution, a dictionary-based approach is better.
            // The current implementation rebuilds the tree structure from a flat list, which is not optimal.
            // A better way is to build a dictionary of URL -> FileItem and then connect the children.
            // Let's try to fix this.

            // Reset and use a better approach
            items = []
            directoryMap = [:]
            var rootItems: [FileItem] = []

            let fileManager = FileManager.default
            guard let fullEnumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
                return []
            }

            var allItems: [URL: FileItem] = [:]

            for fileURL in fullEnumerator.allObjects.compactMap({ $0 as? URL }) {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)),
                      let isDirectory = resourceValues.isDirectory,
                      let name = resourceValues.name
                else {
                    continue
                }
                let newItem = FileItem(name: name, url: fileURL, children: isDirectory ? [] : nil)
                allItems[fileURL] = newItem
            }

            for (fileURL, item) in allItems {
                let parentURL = fileURL.deletingLastPathComponent()
                if let parentItem = allItems[parentURL] {
                    // This is a child item
                    var mutableParent = parentItem
                    mutableParent.children?.append(item)
                    allItems[parentURL] = mutableParent
                } else {
                    // This is a root item
                    rootItems.append(item)
                }
            }

            return rootItems

        }.value
    }

    func readFileContent(at url: URL) async throws -> String {
        try await Task.detached {
            try String(contentsOf: url, encoding: .utf8)
        }.value
    }
}
