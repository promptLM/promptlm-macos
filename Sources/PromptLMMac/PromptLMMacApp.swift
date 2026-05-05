// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@main
struct PromptLMMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No primary window. Settings scene is opened on demand from the menu.
        Settings {
            SettingsPlaceholderView()
        }
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.title2)
            Text("Repository path, hotkey recorder, and autostart will live here.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}
