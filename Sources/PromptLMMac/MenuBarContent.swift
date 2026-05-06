// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import Combine

/// Owns the NSStatusItem (menu bar icon) and its menu.
///
/// Uses AppKit's NSStatusItem directly rather than SwiftUI's MenuBarExtra
/// because the latter has reliability issues on recent macOS releases when
/// run from a SwiftPM-built, ad-hoc-signed .app bundle.
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let store: SettingsStore
    private var repository: LocalFolderRepository
    private let renderer = PromptRenderer()
    private let inserter = PasteInserter()
    private let hotkey = GlobalHotkey()
    private var lastLoad: LocalFolderRepository.LoadResult?
    private var formController: FormWindowController?
    private var settingsController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    init(store: SettingsStore = .shared) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.repository = LocalFolderRepository(root: store.repositoryURL)
        super.init()
        configureButton()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
        registerHotkey(store.hotkey)
        observeSettings()
    }

    private func observeSettings() {
        store.$repositoryPath
            .dropFirst()
            .sink { [weak self] newPath in
                guard let self else { return }
                let url = URL(
                    fileURLWithPath: (newPath as NSString).expandingTildeInPath,
                    isDirectory: true
                )
                self.repository = LocalFolderRepository(root: url)
                self.rebuildMenu()
            }
            .store(in: &cancellables)

        store.$hotkey
            .dropFirst()
            .sink { [weak self] newSpec in
                self?.registerHotkey(newSpec)
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    private func registerHotkey(_ spec: HotkeySpec) {
        hotkey.register(spec) { [weak self] in
            self?.openStatusMenu()
        }
    }

    private func openStatusMenu() {
        // Programmatically click the status item button to drop the menu.
        // performClick(_:) handles positioning and key-window plumbing for us.
        statusItem.button?.performClick(nil)
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

        let titleText: String
        if let spec = hotkey.spec {
            titleText = "promptLM  ·  \(spec.displayString)"
        } else {
            titleText = "promptLM"
        }
        let title = NSMenuItem(title: titleText, action: nil, keyEquivalent: "")
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
        // Capture the user's frontmost app *before* anything we do can take focus.
        let target = NSWorkspace.shared.frontmostApplication
        if prompt.placeholders.isEmpty {
            renderAndInsert(prompt: prompt, values: [:], target: target)
            return
        }
        presentForm(for: prompt, target: target)
    }

    private func presentForm(for prompt: PromptSpec, target: NSRunningApplication?) {
        let controller = FormWindowController(
            prompt: prompt,
            onSubmit: { [weak self] values in
                self?.renderAndInsert(prompt: prompt, values: values, target: target)
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

    private func renderAndInsert(
        prompt: PromptSpec,
        values: [String: String],
        target: NSRunningApplication?
    ) {
        let rendered: String
        do {
            rendered = try renderer.render(prompt.text, with: values)
        } catch {
            NSLog("[promptLM] render failed for \(prompt.id): \(error)")
            presentSimpleError(
                title: "Could not render \"\(prompt.name)\"",
                message: String(describing: error)
            )
            return
        }

        do {
            try inserter.insert(text: rendered, into: target)
            NSLog("[promptLM] inserted \(rendered.count) chars into \(target?.localizedName ?? "nil") from \(prompt.id)")
        } catch InsertError.accessibilityDenied {
            presentAccessibilityRequest(rendered: rendered)
        } catch {
            NSLog("[promptLM] insert failed for \(prompt.id): \(error)")
            // Fallback: at least put the text on the clipboard so the user
            // can paste manually.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rendered, forType: .string)
            presentSimpleError(
                title: "Could not paste at cursor",
                message: "\(error)\n\nThe rendered prompt has been copied to your clipboard."
            )
        }
    }

    private func presentAccessibilityRequest(rendered: String) {
        // Always leave the rendered text on the clipboard so the user has a
        // working fallback while permission is being granted.
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rendered, forType: .string)

        let alert = NSAlert()
        alert.messageText = "Accessibility access needed"
        alert.informativeText = """
            promptLM needs Accessibility permission to paste prompts at your \
            cursor. Open System Settings and enable promptLM under \
            Privacy & Security → Accessibility, then try again.

            The rendered prompt has been copied to your clipboard so you can \
            paste it manually in the meantime.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            AccessibilityCheck.openSystemSettings()
        }
    }

    private func presentSimpleError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
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
        let controller = settingsController ?? SettingsWindowController(store: store)
        settingsController = controller
        controller.present()
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
