// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Combine
import Foundation

/// Single source of truth for user-configurable settings, persisted to
/// `UserDefaults` and exposed as `@Published` properties so the SwiftUI
/// settings form and the runtime (status bar controller, hotkey, login
/// item) can observe changes uniformly.
///
/// All mutations are expected to come from the main thread (SwiftUI view
/// bindings or AppDelegate-initiated reactions). We do not annotate
/// `@MainActor` so the class can be referenced from `NSApplicationDelegate`
/// callbacks without forcing every call site to be MainActor-isolated.
public final class SettingsStore: ObservableObject {

    public static let shared = SettingsStore()

    // MARK: - Persisted properties

    @Published public var repositoryPath: String {
        didSet { defaults.set(repositoryPath, forKey: Keys.repositoryPath) }
    }

    @Published public var hotkey: HotkeySpec {
        didSet {
            defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
            defaults.set(Int(hotkey.modifiers), forKey: Keys.hotkeyModifiers)
        }
    }

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // MARK: - Init

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedPath = defaults.string(forKey: Keys.repositoryPath)
        self.repositoryPath = storedPath?.isEmpty == false
            ? storedPath!
            : SettingsStore.defaultRepositoryPath()

        let key = defaults.object(forKey: Keys.hotkeyKeyCode) as? Int
        let mods = defaults.object(forKey: Keys.hotkeyModifiers) as? Int
        if let key, let mods {
            self.hotkey = HotkeySpec(keyCode: UInt32(key), modifiers: UInt32(mods))
        } else {
            self.hotkey = .default
        }

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    // MARK: - Helpers

    /// `URL` form of `repositoryPath` with `~` expansion.
    public var repositoryURL: URL {
        URL(fileURLWithPath: (repositoryPath as NSString).expandingTildeInPath, isDirectory: true)
    }

    public static func defaultRepositoryPath() -> String {
        // Match LocalFolderRepository.defaultRoot() so the menu bar shows
        // the same folder before and after the user opens settings.
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".promptlm/prompts", isDirectory: true).path
    }

    // MARK: - Keys

    private enum Keys {
        static let repositoryPath = "repository.path"
        static let hotkeyKeyCode = "hotkey.keyCode"
        static let hotkeyModifiers = "hotkey.modifiers"
        static let launchAtLogin = "launchAtLogin"
    }
}
