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
    private let renderer = PromptRenderer()
    private var lastLoad: LocalFolderRepository.LoadResult?
    private var formController: FormWindowController?

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
        if prompt.placeholders.isEmpty {
            renderAndCopy(prompt: prompt, values: [:])
            return
        }
        presentForm(for: prompt)
    }

    private func presentForm(for prompt: PromptSpec) {
        let controller = FormWindowController(
            prompt: prompt,
            onSubmit: { [weak self] values in
                self?.renderAndCopy(prompt: prompt, values: values)
            },
            onClose: { [weak self] in
                self?.formController = nil
            }
        )
        formController = controller
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        controller.showWindow(nil)
    }

    private func renderAndCopy(prompt: PromptSpec, values: [String: String]) {
        do {
            let rendered = try renderer.render(prompt.text, with: values)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rendered, forType: .string)
            NSLog("[promptLM] copied \(rendered.count) chars to clipboard from \(prompt.id)")
        } catch {
            NSLog("[promptLM] render failed for \(prompt.id): \(error)")
            presentRenderError(prompt: prompt, error: error)
        }
    }

    private func presentRenderError(prompt: PromptSpec, error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not render \"\(prompt.name)\""
        alert.informativeText = String(describing: error)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
