// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Carbon.HIToolbox

/// A platform-independent representation of a hotkey: a keyCode plus a set
/// of modifier flags. Encoded in the same units the Carbon API uses
/// (`kVK_*` for keys, `cmdKey | optionKey | …` for modifiers) to keep the
/// registration site trivial.
public struct HotkeySpec: Equatable, Codable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Default: ⌃⌥⌘P. Picked to avoid conflicts with widely-used shortcuts
    /// like ⌥⌘P (printing dialogs, design tools) and ⇧⌘P (command palettes).
    public static let `default` = HotkeySpec(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | optionKey | controlKey)
    )

    /// Human-readable form, e.g. "⌃⌥⌘P". Used in menus and logs.
    public var displayString: String {
        var glyphs = ""
        if modifiers & UInt32(controlKey) != 0 { glyphs += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { glyphs += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { glyphs += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { glyphs += "⌘" }
        glyphs += keyName(keyCode)
        return glyphs
    }

    private func keyName(_ code: UInt32) -> String {
        // Cover the keys we are likely to default to or use in tests; full
        // keycode-to-glyph mapping arrives with the hotkey recorder UI.
        switch Int(code) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space:  return "Space"
        case kVK_Return: return "↵"
        case kVK_Escape: return "⎋"
        default:         return "·"
        }
    }
}
