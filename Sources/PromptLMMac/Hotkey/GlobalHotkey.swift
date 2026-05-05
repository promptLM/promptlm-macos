// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey and dispatches its keypress to a
/// closure on the main queue.
///
/// Carbon's `RegisterEventHotKey` is the right tool here despite being part
/// of an old API: it works without any user-granted permissions, unlike
/// `CGEventTap`, which would require Accessibility access on top of what
/// pasting already needs.
///
/// Only one hotkey at a time is supported — this is what the app needs and
/// keeps the global event-handler bookkeeping trivial.
public final class GlobalHotkey {

    public typealias Action = () -> Void

    private static let signature: OSType = {
        // Four-char code 'PMLM'.
        return (OSType("P".utf8.first!) << 24)
             | (OSType("M".utf8.first!) << 16)
             | (OSType("L".utf8.first!) << 8)
             |  OSType("M".utf8.first!)
    }()

    private static var sharedAction: Action?
    private static var eventHandler: EventHandlerRef?
    private static var didInstallHandler = false
    private static let hotkeyID: UInt32 = 1

    private var hotkeyRef: EventHotKeyRef?
    public private(set) var spec: HotkeySpec?

    public init() {}

    deinit { unregister() }

    /// Register `spec`, replacing any previous registration. Returns `true`
    /// on success. A non-fatal failure (e.g. another app already owns the
    /// shortcut) returns `false`; the app keeps working via the menu bar.
    @discardableResult
    public func register(_ spec: HotkeySpec, action: @escaping Action) -> Bool {
        unregister()
        Self.installHandlerIfNeeded()
        Self.sharedAction = action

        let id = EventHotKeyID(signature: Self.signature, id: Self.hotkeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("[promptLM] hotkey registration failed for \(spec.displayString) (status=\(status))")
            return false
        }
        self.hotkeyRef = ref
        self.spec = spec
        return true
    }

    public func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        spec = nil
    }

    private static func installHandlerIfNeeded() {
        guard !didInstallHandler else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let getStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard getStatus == noErr, hkID.signature == GlobalHotkey.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                if let action = GlobalHotkey.sharedAction {
                    DispatchQueue.main.async { action() }
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
        if status == noErr {
            didInstallHandler = true
        } else {
            NSLog("[promptLM] InstallEventHandler failed (status=\(status))")
        }
    }
}
