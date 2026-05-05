// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@main
struct PromptLMMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // We deliberately ship no SwiftUI Settings scene: in an LSUIElement
        // (menu-bar-only) app it does not get a reliable show path. The
        // status bar's "Settings…" item presents a SettingsWindowController
        // directly. Returning a no-op WindowGroup keeps Scene{} happy
        // without putting a window on screen at launch.
        #if compiler(>=5.9)
        Settings { EmptyView() }
        #else
        WindowGroup { EmptyView() }
        #endif
    }
}
