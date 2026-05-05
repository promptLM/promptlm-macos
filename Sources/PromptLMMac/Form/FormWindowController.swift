// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

/// Hosts a `PlaceholderFormView` in a floating, centered NSWindow.
///
/// The window stays on top so it isn't lost behind a fullscreen app. It is
/// closed when the form submits or cancels, and the controller releases
/// itself via the `onClose` hook.
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
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
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
}
