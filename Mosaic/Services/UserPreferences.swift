import Combine
import Foundation

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    // MARK: - Keys

    private enum Keys {
        static let customLazyDirectories = "customLazyDirectories"
        static let ignoredNamePatterns = "ignoredNamePatterns"
        static let includeHiddenFiles = "includeHiddenFiles"
        static let includePackageContents = "includePackageContents"
    }

    // MARK: - Defaults

    static let defaultIgnoredNamePatterns: [String] = [
        ".git",
        ".DS_Store",
        "node_modules",
        "DerivedData",
        ".build",
        "build",
        "*.xcuserstate",
    ]

    // MARK: - Published Preferences

    /// Directory names that will appear in the tree but load their children lazily (on expand).
    @Published var customLazyDirectories: [String] {
        didSet { UserDefaults.standard.set(customLazyDirectories, forKey: Keys.customLazyDirectories) }
    }

    /// Name patterns to ignore (applies to both files and directories). Supports `*` and `?`.
    @Published var ignoredNamePatterns: [String] {
        didSet { UserDefaults.standard.set(ignoredNamePatterns, forKey: Keys.ignoredNamePatterns) }
    }

    /// Whether directory scanning should include hidden files (except those in ignore list).
    @Published var includeHiddenFiles: Bool {
        didSet { UserDefaults.standard.set(includeHiddenFiles, forKey: Keys.includeHiddenFiles) }
    }

    /// Whether directory scanning should descend into package bundles (e.g. `.xcodeproj`).
    @Published var includePackageContents: Bool {
        didSet { UserDefaults.standard.set(includePackageContents, forKey: Keys.includePackageContents) }
    }

    private init() {
        customLazyDirectories = UserDefaults.standard.stringArray(forKey: Keys.customLazyDirectories) ?? []

        if let stored = UserDefaults.standard.stringArray(forKey: Keys.ignoredNamePatterns) {
            ignoredNamePatterns = stored
        } else {
            ignoredNamePatterns = Self.defaultIgnoredNamePatterns
        }

        // Preserve existing behavior by default: include hidden and include package contents.
        includeHiddenFiles = UserDefaults.standard.object(forKey: Keys.includeHiddenFiles) as? Bool ?? true
        includePackageContents = UserDefaults.standard.object(forKey: Keys.includePackageContents) as? Bool ?? true
    }

    // MARK: - Mutations

    func addLazyDirectory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !customLazyDirectories.contains(trimmed) {
            customLazyDirectories.append(trimmed)
        }
    }

    func removeLazyDirectory(_ name: String) {
        customLazyDirectories.removeAll { $0 == name }
    }

    func addIgnoredPattern(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !ignoredNamePatterns.contains(trimmed) {
            ignoredNamePatterns.append(trimmed)
        }
    }

    func removeIgnoredPattern(_ pattern: String) {
        ignoredNamePatterns.removeAll { $0 == pattern }
    }

    func restoreDefaultIgnoredPatterns() {
        ignoredNamePatterns = Self.defaultIgnoredNamePatterns
    }
}
