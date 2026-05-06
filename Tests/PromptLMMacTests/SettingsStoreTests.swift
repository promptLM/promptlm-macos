// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Carbon.HIToolbox
import XCTest
@testable import PromptLMMac

final class SettingsStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "promptlm.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFreshStoreFallsBackToDefaults() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.hotkey, .default)
        XCTAssertFalse(store.launchAtLogin)
        XCTAssertTrue(store.repositoryPath.contains(".promptlm/prompts"))
    }

    func testHotkeyMutationPersists() {
        let store = SettingsStore(defaults: defaults)
        let custom = HotkeySpec(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | shiftKey)
        )
        store.hotkey = custom

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.hotkey, custom)
    }

    func testRepositoryPathMutationPersists() {
        let store = SettingsStore(defaults: defaults)
        store.repositoryPath = "/tmp/custom-prompts"

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.repositoryPath, "/tmp/custom-prompts")
        XCTAssertEqual(reloaded.repositoryURL.path, "/tmp/custom-prompts")
    }

    func testRepositoryURLExpandsTilde() {
        let store = SettingsStore(defaults: defaults)
        store.repositoryPath = "~/promptlm-prompts"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(
            store.repositoryURL.path,
            "\(home)/promptlm-prompts"
        )
    }

    func testLaunchAtLoginMutationPersists() {
        let store = SettingsStore(defaults: defaults)
        store.launchAtLogin = true

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.launchAtLogin)
    }
}
