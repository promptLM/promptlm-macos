// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Carbon.HIToolbox
import XCTest
@testable import PromptLMMac

final class HotkeySpecTests: XCTestCase {

    func testDefaultIsControlOptionCommandP() {
        let spec = HotkeySpec.default
        XCTAssertEqual(spec.keyCode, UInt32(kVK_ANSI_P))
        XCTAssertEqual(
            spec.modifiers,
            UInt32(cmdKey | optionKey | controlKey)
        )
    }

    func testDisplayStringOrdersModifiersConsistently() {
        // Display order: ⌃⌥⇧⌘ then key, matching Apple HIG.
        let spec = HotkeySpec(
            keyCode: UInt32(kVK_ANSI_P),
            modifiers: UInt32(cmdKey | optionKey | controlKey)
        )
        XCTAssertEqual(spec.displayString, "⌃⌥⌘P")
    }

    func testDisplayStringHandlesShiftAndSpace() {
        let spec = HotkeySpec(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey)
        )
        XCTAssertEqual(spec.displayString, "⇧⌘Space")
    }

    func testCodableRoundTrip() throws {
        let original = HotkeySpec.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeySpec.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
