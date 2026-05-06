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
    private var repository: MultiRepository
    private let renderer = PromptRenderer()
    private let inserter = PasteInserter()
    private let hotkey = GlobalHotkey()
    private var lastLoad: MultiRepository.LoadResult?
    private var formController: FormWindowController?
    private var settingsController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    init(store: SettingsStore = .shared) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.repository = MultiRepository(fallbackRoot: store.repositoryURL)
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
                self.repository = MultiRepository(fallbackRoot: url)
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

        addProjectSections(result, to: menu)

        if let ctxErr = result.contextError {
            menu.addItem(.separator())
            let item = NSMenuItem(
                title: "context.json: \(ctxErr.description)",
                action: nil, keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }

        let allErrors = result.sections.flatMap(\.errors)
        if !allErrors.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(
                title: "\(allErrors.count) prompt file(s) failed to load",
                action: nil,
                keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            for err in allErrors.prefix(5) {
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

    private func addProjectSections(_ result: MultiRepository.LoadResult, to menu: NSMenu) {
        if result.sections.isEmpty {
            let empty = NSMenuItem(
                title: "No projects registered (run promptlm CLI first)",
                action: nil, keyEquivalent: ""
            )
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for (index, section) in result.sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            addSection(section, to: menu)
        }
    }

    private func addSection(_ section: MultiRepository.Section, to menu: NSMenu) {
        let project = section.project
        let header = NSMenuItem(
            title: headerTitle(for: section),
            action: nil, keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        switch section.health {
        case .missingPath(let url):
            let warning = NSMenuItem(
                title: "  Local repo missing: \(displayPath(url))",
                action: nil, keyEquivalent: ""
            )
            warning.isEnabled = false
            menu.addItem(warning)
            return
        case .noLocalPath:
            let warning = NSMenuItem(
                title: "  No local path configured",
                action: nil, keyEquivalent: ""
            )
            warning.isEnabled = false
            menu.addItem(warning)
            return
        case .healthy:
            break
        }

        if section.prompts.isEmpty {
            let empty = NSMenuItem(title: "  No prompts found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        // Group prompts by their `group` field; ungrouped first.
        let grouped = Dictionary(grouping: section.prompts, by: { $0.group ?? "" })
        let ungrouped = grouped[""] ?? []
        let groups = grouped.keys
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for prompt in ungrouped {
            let item = makePromptItem(prompt, project: project)
            item.indentationLevel = 1
            menu.addItem(item)
        }
        for groupName in groups {
            guard let entries = grouped[groupName], !entries.isEmpty else { continue }
            let groupHeader = NSMenuItem(title: "  \(groupName)", action: nil, keyEquivalent: "")
            groupHeader.isEnabled = false
            menu.addItem(groupHeader)
            for prompt in entries {
                let item = makePromptItem(prompt, project: project)
                item.indentationLevel = 2
                menu.addItem(item)
            }
        }
    }

    private func headerTitle(for section: MultiRepository.Section) -> String {
        let count = section.prompts.count
        switch section.health {
        case .healthy:
            return count == 0
                ? section.project.name
                : "\(section.project.name)  ·  \(count) prompt\(count == 1 ? "" : "s")"
        case .missingPath:
            return "\(section.project.name)  ·  ⚠ missing"
        case .noLocalPath:
            return "\(section.project.name)  ·  ⚠ no path"
        }
    }

    private func makePromptItem(_ prompt: PromptSpec, project: ContextProject) -> NSMenuItem {
        let item = NSMenuItem(
            title: prompt.name,
            action: #selector(promptSelected(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = prompt
        var tooltipParts: [String] = [project.name]
        if let desc = prompt.description, !desc.isEmpty { tooltipParts.append(desc) }
        item.toolTip = tooltipParts.joined(separator: " — ")
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
        let url = store.repositoryURL
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
