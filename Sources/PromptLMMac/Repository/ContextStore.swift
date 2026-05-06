// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// One project entry from `~/.promptlm/context.json` — tolerantly decoded.
///
/// Mirrors the subset the macOS client cares about: where the repo lives on
/// disk and how to display it. Server-side fields (`updatedAt`, `promptCount`,
/// etc.) are ignored.
public struct ContextProject: Codable, Equatable {
    public let id: String?
    public let name: String
    public let description: String?
    public let localPath: String?
    public let repositoryUrl: String?
    public let healthStatus: String?
    public let healthMessage: String?

    public init(
        id: String? = nil,
        name: String,
        description: String? = nil,
        localPath: String? = nil,
        repositoryUrl: String? = nil,
        healthStatus: String? = nil,
        healthMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.localPath = localPath
        self.repositoryUrl = repositoryUrl
        self.healthStatus = healthStatus
        self.healthMessage = healthMessage
    }

    /// Resolves `localPath` to an on-disk URL with `~` expanded.
    public var localURL: URL? {
        guard let path = localPath, !path.isEmpty else { return nil }
        return URL(
            fileURLWithPath: (path as NSString).expandingTildeInPath,
            isDirectory: true
        )
    }
}

/// Wire format of `~/.promptlm/context.json`. Only `projects` is required; the
/// `activeProject` pointer is ignored — the macOS client surfaces *all*
/// projects, not just the active one.
private struct ContextFile: Codable {
    let projects: [ContextProject]?
}

public enum ContextStoreError: Error, CustomStringConvertible {
    case decodeFailed(URL, underlying: Error)

    public var description: String {
        switch self {
        case .decodeFailed(let url, let err):
            return "Failed to decode \(url.lastPathComponent): \(err.localizedDescription)"
        }
    }
}

/// Reads the promptlm CLI's project list from `~/.promptlm/context.json`.
///
/// A missing file is not an error — it just means the user has no projects
/// registered yet, in which case we fall back to the legacy single-folder
/// repository configured in `SettingsStore`.
public final class ContextStore {

    public let path: URL
    private let fileManager: FileManager

    public init(path: URL = ContextStore.defaultPath(), fileManager: FileManager = .default) {
        self.path = path
        self.fileManager = fileManager
    }

    public struct LoadResult {
        public let projects: [ContextProject]
        public let error: ContextStoreError?
        public let fileExists: Bool
    }

    public func load() -> LoadResult {
        guard fileManager.fileExists(atPath: path.path) else {
            return LoadResult(projects: [], error: nil, fileExists: false)
        }
        do {
            let data = try Data(contentsOf: path)
            let file = try JSONDecoder().decode(ContextFile.self, from: data)
            return LoadResult(projects: file.projects ?? [], error: nil, fileExists: true)
        } catch {
            return LoadResult(
                projects: [],
                error: .decodeFailed(path, underlying: error),
                fileExists: true
            )
        }
    }

    public static func defaultPath() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".promptlm/context.json", isDirectory: false)
    }
}

/// Per-project health, evaluated against the local filesystem.
public enum ProjectHealth: Equatable {
    case healthy
    case missingPath(URL)
    case noLocalPath
}

public extension ContextProject {
    func evaluateHealth(fileManager: FileManager = .default) -> ProjectHealth {
        guard let url = localURL else { return .noLocalPath }
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return .healthy
        }
        return .missingPath(url)
    }
}
