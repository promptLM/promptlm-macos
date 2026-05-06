// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// One row in the quick picker — a prompt plus the project it belongs to.
public struct IndexedPrompt: Equatable, Identifiable {
    public let project: ContextProject
    public let prompt: PromptSpec

    public var id: String { "\(project.id ?? project.name)::\(prompt.id)" }

    public init(project: ContextProject, prompt: PromptSpec) {
        self.project = project
        self.prompt = prompt
    }
}

/// Searchable in-memory index over all prompts surfaced by `MultiRepository`.
///
/// Filtering is intentionally simple — case-insensitive substring match
/// against the fields a user is likely to type. We sort matches by
/// "where did the term hit": name > group > description > project, so the
/// most direct match floats up. Whitespace splits the query into AND'd terms
/// so `"java review"` finds prompts whose combined fields contain both.
public struct PromptIndex {

    public let entries: [IndexedPrompt]

    public init(_ entries: [IndexedPrompt]) {
        self.entries = entries
    }

    public init(from result: MultiRepository.LoadResult) {
        self.entries = result.allPrompts.map { IndexedPrompt(project: $0.project, prompt: $0.prompt) }
    }

    /// Returns matching entries sorted by relevance.
    /// An empty / whitespace-only query returns the full list unfiltered.
    public func search(_ query: String) -> [IndexedPrompt] {
        let terms = query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return entries }

        var scored: [(IndexedPrompt, Int)] = []
        for entry in entries {
            let fields = Self.fields(for: entry)
            var totalScore = 0
            var allMatched = true
            for term in terms {
                let s = Self.score(term: term, fields: fields)
                if s == 0 { allMatched = false; break }
                totalScore += s
            }
            if allMatched { scored.append((entry, totalScore)) }
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.prompt.name.localizedCaseInsensitiveCompare(rhs.0.prompt.name)
                    == .orderedAscending
            }
            .map(\.0)
    }

    private struct Fields {
        let name: String
        let group: String
        let description: String
        let project: String
    }

    private static func fields(for entry: IndexedPrompt) -> Fields {
        Fields(
            name: entry.prompt.name.lowercased(),
            group: (entry.prompt.group ?? "").lowercased(),
            description: (entry.prompt.description ?? "").lowercased(),
            project: entry.project.name.lowercased()
        )
    }

    /// Score a single search term against an entry's fields.
    /// 0 → no match. Higher = better.
    private static func score(term: String, fields: Fields) -> Int {
        var score = 0
        if fields.name.hasPrefix(term)        { score = max(score, 100) }
        else if fields.name.contains(term)    { score = max(score, 70) }
        if fields.group.contains(term)        { score = max(score, 50) }
        if fields.description.contains(term)  { score = max(score, 30) }
        if fields.project.contains(term)      { score = max(score, 20) }
        return score
    }
}
