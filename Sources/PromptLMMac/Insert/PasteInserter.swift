// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import CoreGraphics

public enum InsertError: Error, CustomStringConvertible, Equatable {
    case accessibilityDenied
    case targetAppMissing
    case targetAppTerminated
    case eventTapUnavailable

    public var description: String {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission required. Enable promptLM in System Settings → Privacy & Security → Accessibility."
        case .targetAppMissing:
            return "Could not determine the app to paste into."
        case .targetAppTerminated:
            return "The target app was no longer running."
        case .eventTapUnavailable:
            return "Could not synthesize keyboard event."
        }
    }
}

/// Pastes rendered prompt text into a target app at the cursor position.
///
/// The flow:
/// 1. Snapshot the current pasteboard
/// 2. Write the rendered text to the pasteboard
/// 3. Reactivate the target app (which became background while the form was up)
/// 4. Synthesize Cmd-V via CGEvent
/// 5. After `restoreDelay`, restore the original pasteboard
///
/// Steps 3–4 require Accessibility permission. Without it, `insert` throws
/// `.accessibilityDenied` *before* touching the pasteboard, so the user's
/// clipboard is never disturbed.
public final class PasteInserter {

    /// How long to wait between sending Cmd-V and restoring the original
    /// pasteboard. The target app needs to have read the pasteboard before
    /// we overwrite it again. Slow apps benefit from a longer delay; the
    /// downside of waiting longer is only that the user's clipboard is
    /// briefly inaccessible.
    public var restoreDelay: TimeInterval = 0.4

    /// Delay between activating the target app and dispatching Cmd-V.
    /// Activation is asynchronous on macOS — sending keys too early lets
    /// them race past the focus change.
    public var activationDelay: TimeInterval = 0.08

    public init() {}

    /// Insert `text` at the cursor of `targetApp`. Throws synchronously for
    /// pre-flight failures (no permission, no target). Pasting itself is
    /// dispatched asynchronously.
    public func insert(text: String, into targetApp: NSRunningApplication?) throws {
        guard AccessibilityCheck.isTrusted else {
            throw InsertError.accessibilityDenied
        }
        guard let target = targetApp else {
            throw InsertError.targetAppMissing
        }
        guard !target.isTerminated else {
            throw InsertError.targetAppTerminated
        }

        let snapshot = PasteboardSnapshot()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if #available(macOS 14, *) {
            target.activate()
        } else {
            target.activate(options: [])
        }

        let restoreDelay = self.restoreDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) {
            self.postCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                snapshot.restore(to: pasteboard)
            }
        }
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // ANSI 'V'
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
