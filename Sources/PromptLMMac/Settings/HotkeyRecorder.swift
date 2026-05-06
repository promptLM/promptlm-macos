// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// SwiftUI control that records a global hotkey: click → press combo → done.
///
/// We bridge an `NSView` because SwiftUI's keyboard handling is tied to
/// focus/key-window plumbing that does not capture modifier-only state
/// reliably. The view becomes first responder when activated, observes
/// `keyDown` and `flagsChanged`, and emits the new `HotkeySpec` once a key
/// is pressed together with at least one modifier.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var spec: HotkeySpec

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onCapture = { newSpec in spec = newSpec }
        view.update(spec: spec)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.update(spec: spec)
    }
}

final class HotkeyRecorderNSView: NSView {

    var onCapture: ((HotkeySpec) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Record", target: nil, action: nil)
    private var isRecording = false {
        didSet { refresh() }
    }
    private var displayedSpec: HotkeySpec = .default

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.alignment = .left
        addSubview(label)

        button.target = self
        button.action = #selector(toggleRecording)
        button.bezelStyle = .rounded
        button.controlSize = .small
        addSubview(button)

        translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            button.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(spec: HotkeySpec) {
        displayedSpec = spec
        if !isRecording { refresh() }
    }

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    private func refresh() {
        if isRecording {
            label.stringValue = "Press a key combination… (⎋ to cancel)"
            label.textColor = .secondaryLabelColor
            button.title = "Stop"
        } else {
            label.stringValue = displayedSpec.displayString
            label.textColor = .labelColor
            button.title = "Record"
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if Int(event.keyCode) == kVK_Escape {
            isRecording = false
            return
        }
        let mods = HotkeyRecorderNSView.carbonModifiers(from: event.modifierFlags)
        // Require at least one non-shift modifier; otherwise the shortcut
        // would steal regular typing.
        let hasMandatoryModifier = mods & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasMandatoryModifier else {
            NSSound.beep()
            return
        }
        let newSpec = HotkeySpec(keyCode: UInt32(event.keyCode), modifiers: mods)
        displayedSpec = newSpec
        onCapture?(newSpec)
        isRecording = false
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }
}
