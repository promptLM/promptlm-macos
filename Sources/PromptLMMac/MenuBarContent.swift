// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit

/// Owns the NSStatusItem (menu bar icon) and its menu.
///
/// Uses AppKit's NSStatusItem directly rather than SwiftUI's MenuBarExtra
/// because the latter has reliability issues on recent macOS releases when
/// run from a SwiftPM-built, ad-hoc-signed .app bundle.
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let repository: LocalFolderRepository
    private var lastLoad: LocalFolderRepository.LoadResult?

    init(repository: LocalFolderRepository = LocalFolderRepository(root: LocalFolderRepository.defaultRoot())) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.repository = repository
        super.init()
        configureButton()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    // MARK: - UI

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let symbol = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "promptLM")
        symbol?.isTemplate = true
        button.image = symbol
        button.toolTip = "promptLM"
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: "promptLM", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let result = repository.load()
        lastLoad = result

        if result.prompts.isEmpty {
            let empty = NSMenuItem(
                title: "No prompts in \(displayPath(repository.root))",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            menu.addItem(empty)

            let reveal = NSMenuItem(
                title: "Reveal repository folder in Finder",
                action: #selector(revealRepositoryFolder),
                keyEquivalent: ""
            )
            reveal.target = self
            menu.addItem(reveal)
        } else {
            addPromptItems(result.prompts, to: menu)
        }

        if !result.errors.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(
                title: "\(result.errors.count) file(s) failed to load",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            for err in result.errors.prefix(5) {
                let item = NSMenuItem(title: "  \(err.description)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let reload = NSMenuItem(
            title: "Reload prompts",
            action: #selector(reload),
            keyEquivalent: "r"
        )
        reload.keyEquivalentModifierMask = [.command]
        reload.target = self
        menu.addItem(reload)

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit promptLM",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)
    }

    private func addPromptItems(_ prompts: [PromptSpec], to menu: NSMenu) {
        // Group prompts by their `group` field; ungrouped go to the top.
        let grouped = Dictionary(grouping: prompts, by: { $0.group ?? "" })
        let ungrouped = grouped[""] ?? []
        let groups = grouped.keys
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for prompt in ungrouped {
            menu.addItem(makePromptItem(prompt))
        }
        for groupName in groups {
            if let entries = grouped[groupName], !entries.isEmpty {
                let header = NSMenuItem(title: groupName, action: nil, keyEquivalent: "")
                header.isEnabled = false
                menu.addItem(header)
                for prompt in entries {
                    let item = makePromptItem(prompt)
                    item.indentationLevel = 1
                    menu.addItem(item)
                }
            }
        }
    }

    private func makePromptItem(_ prompt: PromptSpec) -> NSMenuItem {
        let item = NSMenuItem(
            title: prompt.name,
            action: #selector(promptSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = prompt
        if let desc = prompt.description, !desc.isEmpty {
            item.toolTip = desc
        }
        return item
    }

    private func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Actions

    @objc private func promptSelected(_ sender: NSMenuItem) {
        guard let prompt = sender.representedObject as? PromptSpec else { return }
        // Step 2 stops here: we only confirm wiring works. Form + render +
        // paste are the next steps. For now, copy the raw prompt text to the
        // pasteboard so you can paste it manually and verify content.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.text, forType: .string)
        NSLog("[promptLM] prompt selected: \(prompt.id) — copied raw text to clipboard")
    }

    @objc private func reload() {
        rebuildMenu()
    }

    @objc private func revealRepositoryFolder() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: repository.root.path) {
            try? fm.createDirectory(at: repository.root, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([repository.root])
    }

    @objc private func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
    }
}
