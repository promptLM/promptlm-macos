// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import ApplicationServices

/// Wraps the macOS Accessibility-permission gate.
///
/// Pasting at the cursor needs to synthesize a Cmd-V keystroke, which
/// requires the user to grant the app Accessibility access in
/// System Settings → Privacy & Security → Accessibility.
enum AccessibilityCheck {

    /// Whether the current process is currently trusted to send synthetic
    /// keyboard input. Cheap, can be called freely.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Opens the Accessibility pane in System Settings. The user must
    /// flip the toggle for promptLM and re-launch the app for permission
    /// to take effect on ad-hoc-signed builds.
    static func openSystemSettings() {
        // Modern URL scheme; falls through to the legacy one on older macOS.
        let modern = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        if !NSWorkspace.shared.open(modern) {
            let legacy = URL(fileURLWithPath:
                "/System/Library/PreferencePanes/Security.prefPane"
            )
            NSWorkspace.shared.open(legacy)
        }
    }
}
