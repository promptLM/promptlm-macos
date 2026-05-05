// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Hosts the settings UI in an explicit NSWindow.
///
/// SwiftUI's `Settings { ... }` scene relies on the standard "Preferences…"
/// menu plumbing, which does not work reliably for LSUIElement apps that
/// have no Dock icon and no app menu. Building the window ourselves gives
/// us a single instance, deterministic centering, and a reliable show path
/// that does not depend on any responder chain magic.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store

        let hosting = NSHostingController(rootView: SettingsView(store: store))
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.preferredContentSize]
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = "promptLM Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Show (or bring forward) the settings window. Activates the app so
    /// the window can become key — important because we are LSUIElement.
    func present() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
