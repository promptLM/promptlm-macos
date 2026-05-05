// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import XCTest
@testable import PromptLMMac

final class PasteboardSnapshotTests: XCTestCase {

    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        // Custom-named pasteboard so tests do not stomp on the user's clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("promptlm.test.\(UUID().uuidString)"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        super.tearDown()
    }

    func testRestoresPreviousString() {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = PasteboardSnapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("scratch", forType: .string)
        XCTAssertEqual(pasteboard.string(forType: .string), "scratch")

        snapshot.restore(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testRestoresEmptyPasteboardAsCleared() {
        pasteboard.clearContents()
        let snapshot = PasteboardSnapshot(of: pasteboard)
        XCTAssertEqual(snapshot.itemCount, 0)

        pasteboard.clearContents()
        pasteboard.setString("noise", forType: .string)
        snapshot.restore(to: pasteboard)
        XCTAssertNil(pasteboard.string(forType: .string))
    }

    func testRestoresMultipleTypesOnSingleItem() {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        item.setData(Data([0x01, 0x02, 0x03]), forType: .init("dev.promptlm.test.binary"))
        pasteboard.writeObjects([item])

        let snapshot = PasteboardSnapshot(of: pasteboard)
        XCTAssertEqual(snapshot.itemCount, 1)

        pasteboard.clearContents()
        pasteboard.setString("scratch", forType: .string)

        snapshot.restore(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "plain")
        XCTAssertEqual(
            pasteboard.data(forType: .init("dev.promptlm.test.binary")),
            Data([0x01, 0x02, 0x03])
        )
    }
}
