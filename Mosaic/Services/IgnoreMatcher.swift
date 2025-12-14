import Foundation

/// Matches file/directory names against a small set of ignore patterns.
/// Patterns support `*` (any sequence) and `?` (single character), and match against a single path component.
nonisolated struct IgnoreMatcher: Sendable {
    private let exactLowercased: Set<String>
    private let wildcardPatternsLowercased: [String]

    init(patterns: [String]) {
        var exact: Set<String> = []
        var wildcards: [String] = []

        for raw in patterns {
            let pattern = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pattern.isEmpty, !pattern.hasPrefix("#") else { continue }

            if pattern.contains("*") || pattern.contains("?") {
                wildcards.append(pattern.lowercased())
            } else {
                exact.insert(pattern.lowercased())
            }
        }

        exactLowercased = exact
        wildcardPatternsLowercased = wildcards
    }

    func matches(name: String) -> Bool {
        let lower = name.lowercased()
        if exactLowercased.contains(lower) { return true }
        guard !wildcardPatternsLowercased.isEmpty else { return false }
        return wildcardPatternsLowercased.contains { Self.globMatch(pattern: $0, string: lower) }
    }

    func matches(anyPathComponentIn path: String) -> Bool {
        let comps = path.split(separator: "/").map(String.init)
        return comps.contains(where: matches(name:))
    }

    /// Simple glob matching that supports `*` and `?`.
    private static func globMatch(pattern: String, string: String) -> Bool {
        let p = Array(pattern)
        let s = Array(string)

        var i = 0
        var j = 0
        var starIndex: Int? = nil
        var matchIndex = 0

        while j < s.count {
            if i < p.count, (p[i] == "?" || p[i] == s[j]) {
                i += 1
                j += 1
            } else if i < p.count, p[i] == "*" {
                starIndex = i
                matchIndex = j
                i += 1
            } else if let star = starIndex {
                i = star + 1
                matchIndex += 1
                j = matchIndex
            } else {
                return false
            }
        }

        while i < p.count, p[i] == "*" {
            i += 1
        }

        return i == p.count
    }
}


