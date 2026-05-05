// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit

/// Owns the NSStatusItem (menu bar icon) and its menu.
///
/// We use AppKit's NSStatusItem directly rather than SwiftUI's MenuBarExtra
/// because the latter has reliability issues on recent macOS releases when
/// run from a SwiftPM-built, ad-hoc-signed .app bundle.
final class StatusBarController {

    private let statusItem: NSStatusItem

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        statusItem.menu = buildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let symbol = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "promptLM")
        symbol?.isTemplate = true
        button.image = symbol
        button.toolTip = "promptLM"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let title = NSMenuItem(title: "promptLM", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let picker = NSMenuItem(
            title: "Open Prompt Picker…",
            action: #selector(openPicker),
            keyEquivalent: "p"
        )
        picker.keyEquivalentModifierMask = [.command, .option]
        picker.target = self
        menu.addItem(picker)

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

        return menu
    }

    @objc private func openPicker() {
        NSLog("[promptLM] picker requested — not implemented yet")
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
