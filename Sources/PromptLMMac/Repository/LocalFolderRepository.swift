// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Yams

public enum RepositoryError: Error, CustomStringConvertible {
    case folderUnreadable(URL, underlying: Error)
    case decodeFailed(URL, underlying: Error)

    public var description: String {
        switch self {
        case .folderUnreadable(let url, let err):
            return "Cannot read folder \(url.path): \(err.localizedDescription)"
        case .decodeFailed(let url, let err):
            return "Failed to decode \(url.lastPathComponent): \(err.localizedDescription)"
        }
    }
}

/// Loads PromptSpecs from a local folder.
///
/// Scans the configured folder recursively for `*.yaml`, `*.yml`, and `*.json`
/// files and decodes each into a `PromptSpec`. Files that fail to decode are
/// skipped and reported via the returned `errors` list — one bad file does
/// not break the whole repository.
public final class LocalFolderRepository {

    public let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public struct LoadResult {
        public let prompts: [PromptSpec]
        public let errors: [RepositoryError]
    }

    public func load() -> LoadResult {
        var prompts: [PromptSpec] = []
        var errors: [RepositoryError] = []

        guard fileManager.fileExists(atPath: root.path) else {
            // Missing folder is not an error: empty repository, nothing to do.
            return LoadResult(prompts: [], errors: [])
        }

        let files: [URL]
        do {
            files = try collectFiles(under: root)
        } catch {
            return LoadResult(
                prompts: [],
                errors: [.folderUnreadable(root, underlying: error)]
            )
        }

        for file in files {
            do {
                let spec = try decode(file)
                prompts.append(spec)
            } catch {
                errors.append(.decodeFailed(file, underlying: error))
            }
        }

        prompts.sort { lhs, rhs in
            if lhs.group != rhs.group {
                return (lhs.group ?? "") < (rhs.group ?? "")
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return LoadResult(prompts: prompts, errors: errors)
    }

    private func collectFiles(under url: URL) throws -> [URL] {
        let supportedExtensions: Set<String> = ["yaml", "yml", "json"]
        var results: [URL] = []
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        while let candidate = enumerator?.nextObject() as? URL {
            let ext = candidate.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }
            let isFile = (try? candidate.resourceValues(forKeys: [.isRegularFileKey]))?
                .isRegularFile ?? false
            if isFile { results.append(candidate) }
        }
        return results
    }

    private func decode(_ file: URL) throws -> PromptSpec {
        let data = try Data(contentsOf: file)
        let ext = file.pathExtension.lowercased()
        switch ext {
        case "json":
            return try JSONDecoder().decode(PromptSpec.self, from: data)
        case "yaml", "yml":
            let decoder = YAMLDecoder()
            return try decoder.decode(PromptSpec.self, from: data)
        default:
            // collectFiles filters extensions; this branch is unreachable in practice.
            throw NSError(
                domain: "LocalFolderRepository", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported extension .\(ext)"]
            )
        }
    }
}

public extension LocalFolderRepository {
    /// Default folder used when the user has not configured an override:
    /// `~/.promptlm/prompts`. Override via env var `PROMPTLM_PROMPTS_DIR`.
    static func defaultRoot() -> URL {
        if let env = ProcessInfo.processInfo.environment["PROMPTLM_PROMPTS_DIR"],
           !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".promptlm/prompts", isDirectory: true)
    }
}
