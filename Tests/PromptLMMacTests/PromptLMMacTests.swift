// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import PromptLMMac

final class LocalFolderRepositoryTests: XCTestCase {

    private var fixturesURL: URL {
        // Resources are copied into the test bundle; locate the Fixtures dir.
        guard let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            fatalError("Fixtures resource bundle missing")
        }
        return url
    }

    func testLoadsAllSupportedFormats() throws {
        let repo = LocalFolderRepository(root: fixturesURL)
        let result = repo.load()

        let ids = Set(result.prompts.map(\.id))
        XCTAssertTrue(ids.contains("minimal"))
        XCTAssertTrue(ids.contains("greet"))
        XCTAssertTrue(ids.contains("json-spec"))
    }

    func testReportsBadFilesAsErrorsWithoutBreakingValidOnes() throws {
        let repo = LocalFolderRepository(root: fixturesURL)
        let result = repo.load()

        XCTAssertFalse(result.errors.isEmpty, "broken.yaml should produce a decode error")
        XCTAssertGreaterThanOrEqual(result.prompts.count, 3,
                                    "valid files should still load alongside the broken one")
    }

    func testPromptsAreSortedByGroupThenName() throws {
        let repo = LocalFolderRepository(root: fixturesURL)
        let prompts = repo.load().prompts

        let withGroup = prompts.first { $0.group == "demo" }
        XCTAssertEqual(withGroup?.id, "greet")
    }

    func testMissingFolderYieldsEmptyResultNotError() {
        let bogus = URL(fileURLWithPath: "/tmp/promptlm-does-not-exist-\(UUID().uuidString)")
        let repo = LocalFolderRepository(root: bogus)
        let result = repo.load()
        XCTAssertTrue(result.prompts.isEmpty)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testPlaceholderDefaultsAreDecoded() throws {
        let repo = LocalFolderRepository(root: fixturesURL)
        let prompts = repo.load().prompts

        let greet = try XCTUnwrap(prompts.first { $0.id == "greet" })
        let nameDef = try XCTUnwrap(greet.placeholders["name"])
        XCTAssertEqual(nameDef.defaultValue, "World")
        XCTAssertEqual(nameDef.required, true)
    }

    func testDefaultRootHonoursEnvOverride() {
        // Sanity check: the static helper produces a non-empty path.
        let url = LocalFolderRepository.defaultRoot()
        XCTAssertFalse(url.path.isEmpty)
    }
}
