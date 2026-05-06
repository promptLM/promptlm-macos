// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Aggregates prompts across all projects registered in
/// `~/.promptlm/context.json`, falling back to the legacy single-folder
/// repository when no context file is present.
///
/// The result is "tolerant by design": a missing context file, a project
/// whose `localPath` no longer exists, or a single bad prompt file all
/// surface as user-visible warnings without blocking the rest.
public final class MultiRepository {

    public let contextStore: ContextStore
    public let fallbackRoot: URL?
    private let fileManager: FileManager

    public init(
        contextStore: ContextStore = ContextStore(),
        fallbackRoot: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.contextStore = contextStore
        self.fallbackRoot = fallbackRoot
        self.fileManager = fileManager
    }

    /// One project surfaced in the menu, with its prompts and any per-project
    /// load errors. Even an unhealthy project is included so the user can see
    /// *why* it has no prompts.
    public struct Section {
        public let project: ContextProject
        public let health: ProjectHealth
        public let prompts: [PromptSpec]
        public let errors: [RepositoryError]
    }

    public struct LoadResult {
        public let sections: [Section]
        public let contextError: ContextStoreError?
        public let usedFallback: Bool

        /// Flat view across all healthy sections, useful for search/picker UI.
        public var allPrompts: [(project: ContextProject, prompt: PromptSpec)] {
            sections.flatMap { section in
                section.prompts.map { (project: section.project, prompt: $0) }
            }
        }
    }

    public func load() -> LoadResult {
        let context = contextStore.load()

        // Fallback path: when context.json is missing entirely, behave like
        // the previous single-folder client so existing setups keep working.
        if !context.fileExists, let fallback = fallbackRoot {
            let result = LocalFolderRepository(root: fallback, fileManager: fileManager).load()
            let synthetic = ContextProject(
                name: "Local prompts",
                localPath: fallback.path,
                healthStatus: nil
            )
            let health: ProjectHealth = fileManager.fileExists(atPath: fallback.path)
                ? .healthy
                : .missingPath(fallback)
            return LoadResult(
                sections: [
                    Section(
                        project: synthetic,
                        health: health,
                        prompts: result.prompts,
                        errors: result.errors
                    )
                ],
                contextError: nil,
                usedFallback: true
            )
        }

        let sections = context.projects.map { project -> Section in
            let health = project.evaluateHealth(fileManager: fileManager)
            switch health {
            case .healthy:
                let url = project.localURL!  // .healthy guarantees this resolves
                let result = LocalFolderRepository(root: url, fileManager: fileManager).load()
                return Section(
                    project: project,
                    health: health,
                    prompts: result.prompts,
                    errors: result.errors
                )
            case .missingPath, .noLocalPath:
                return Section(project: project, health: health, prompts: [], errors: [])
            }
        }

        return LoadResult(
            sections: sections,
            contextError: context.error,
            usedFallback: false
        )
    }
}
