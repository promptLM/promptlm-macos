// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@main
struct PromptLMMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: SettingsStore.shared)
        }
    }
}
