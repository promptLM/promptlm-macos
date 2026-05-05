// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Hosts a `PlaceholderFormView` in a floating, centered NSWindow.
///
/// We allocate the window with an explicit size and let the SwiftUI view
/// fill it. NSHostingController's auto-sizing path does not respect SwiftUI
/// `.frame(...)` modifiers reliably across macOS releases — content rows
/// could end up invisible. A fixed initial size is good enough for the
/// typical 1–5 placeholders case; dynamic sizing is a follow-up.
final class FormWindowController: NSWindowController, NSWindowDelegate {

    private let onClose: () -> Void

    init(
        prompt: PromptSpec,
        onSubmit: @escaping ([String: String]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose

        var capturedClose: (() -> Void)?
        var capturedSubmit: (([String: String]) -> Void)?

        let view = PlaceholderFormView(
            prompt: prompt,
            onSubmit: { values in capturedSubmit?(values) },
            onCancel: { capturedClose?() }
        )
        let hosting = NSHostingController(rootView: view)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = [.preferredContentSize]
        }

        let initialHeight = FormWindowController.estimatedHeight(for: prompt)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: initialHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = prompt.name
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        super.init(window: window)
        window.delegate = self

        capturedClose = { [weak self] in self?.close() }
        capturedSubmit = { [weak self] values in
            onSubmit(values)
            self?.close()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    /// Rough height estimate so the window opens at a usable size for the
    /// number of placeholders it contains. Header + footer ≈ 130; each
    /// placeholder row ≈ 70 (label + description + input).
    private static func estimatedHeight(for prompt: PromptSpec) -> CGFloat {
        let rowHeight: CGFloat = 70
        let chrome: CGFloat = 150
        let count = max(1, prompt.placeholders.count)
        return chrome + CGFloat(count) * rowHeight
    }
}
