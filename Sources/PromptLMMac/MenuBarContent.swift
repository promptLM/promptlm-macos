// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct MenuBarContent: View {
    var body: some View {
        Text("promptLM")
            .font(.headline)
        Divider()
        Button("Open Prompt Picker…") {
            // TODO: present QuickPickerWindow
        }
        .keyboardShortcut("p", modifiers: [.command, .option])
        Button("Settings…") {
            // TODO: open SettingsWindow
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit promptLM") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
