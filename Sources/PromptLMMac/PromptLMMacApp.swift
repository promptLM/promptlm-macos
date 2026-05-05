// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

@main
struct PromptLMMacApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(systemName: "text.bubble")
                .accessibilityLabel("promptLM")
        }
        .menuBarExtraStyle(.menu)
    }
}
