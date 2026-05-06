// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Hosts `QuickPickerView` in a Spotlight-style floating panel.
///
/// We use `NSPanel` (rather than a regular `NSWindow`) so it can become key
/// without forcing the app into the foreground in the Dock — important
/// because we are LSUIElement. The panel is `.nonactivating` and dismisses
/// itself when it loses focus (covers click-outside-to-close).
final class QuickPickerWindowController: NSWindowController, NSWindowDelegate {

    private let onActivate: (IndexedPrompt) -> Void
    private let onClose: () -> Void

    init(
        index: PromptIndex,
        onActivate: @escaping (IndexedPrompt) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onActivate = onActivate
        self.onClose = onClose

        var capturedActivate: ((IndexedPrompt) -> Void)?
        var capturedCancel: (() -> Void)?

        let view = QuickPickerView(
            index: index,
            onActivate: { entry in capturedActivate?(entry) },
            onCancel: { capturedCancel?() }
        )
        let hosting = NSHostingController(rootView: view)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.preferredContentSize]
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentViewController = hosting
        panel.isReleasedWhenClosed = false
        panel.center()

        super.init(window: panel)
        panel.delegate = self

        capturedActivate = { [weak self] entry in
            self?.close()
            onActivate(entry)
        }
        capturedCancel = { [weak self] in
            self?.close()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Show (or re-center and raise) the picker.
    func present() {
        // Position slightly above center so it sits where Spotlight does.
        if let window, let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = window.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2 + frame.height * 0.1
            )
            window.setFrameOrigin(origin)
        }
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Click-outside-to-close: matches Spotlight behaviour.
        close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
