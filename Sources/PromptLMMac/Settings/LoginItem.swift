// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import ServiceManagement

/// Toggle promptLM as a login item via `SMAppService`.
///
/// Requires macOS 13+ (the app's deployment target). On older macOS this
/// would have used the deprecated launchd plist + helper binary dance,
/// which we explicitly do not support.
enum LoginItem {

    /// `true` if registered with launchd, `false` if not, `nil` if the
    /// service reports an unexpected status (e.g. requires user approval
    /// in System Settings).
    static var isEnabled: Bool? {
        switch SMAppService.mainApp.status {
        case .enabled: return true
        case .notRegistered, .notFound: return false
        case .requiresApproval: return nil
        @unknown default: return nil
        }
    }

    /// Apply `enabled`; throws if the OS rejects the call. Common failure
    /// is `requiresApproval`, in which case the user must flip the toggle
    /// in System Settings → General → Login Items themselves.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
