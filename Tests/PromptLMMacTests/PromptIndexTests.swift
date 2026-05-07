// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import PromptLMMac

final class PromptIndexTests: XCTestCase {

    private func entry(
        project: String,
        id: String,
        name: String,
        group: String? = nil,
        description: String? = nil
    ) -> IndexedPrompt {
        IndexedPrompt(
            project: ContextProject(name: project),
            prompt: PromptSpec(
                id: id,
                name: name,
                group: group,
                description: description,
                text: "x"
            )
        )
    }

    private var sample: PromptIndex {
        PromptIndex([
            entry(project: "infra", id: "1", name: "Java code review", group: "engineering"),
            entry(project: "infra", id: "2", name: "Bash one-liner",   group: "engineering"),
            entry(project: "infra", id: "3", name: "Standup summary",  group: "engineering"),
            entry(project: "support", id: "4", name: "Customer reply", group: "support",
                  description: "Polite reply with steps"),
            entry(project: "support", id: "5", name: "Refund request", group: "support")
        ])
    }

    func testEmptyQueryReturnsAllEntriesUnfiltered() {
        XCTAssertEqual(sample.search("").count, 5)
        XCTAssertEqual(sample.search("   ").count, 5)
    }

    func testSubstringMatchOnName() {
        let results = sample.search("review")
        XCTAssertEqual(results.map(\.prompt.id), ["1"])
    }

    func testCaseInsensitive() {
        XCTAssertEqual(sample.search("JAVA").map(\.prompt.id), ["1"])
        XCTAssertEqual(sample.search("java").map(\.prompt.id), ["1"])
    }

    func testMatchOnProjectName() {
        let results = sample.search("support")
        XCTAssertEqual(Set(results.map(\.prompt.id)), ["4", "5"])
    }

    func testMatchOnGroup() {
        let results = sample.search("engineering")
        XCTAssertEqual(Set(results.map(\.prompt.id)), ["1", "2", "3"])
    }

    func testMatchOnDescription() {
        let results = sample.search("polite")
        XCTAssertEqual(results.map(\.prompt.id), ["4"])
    }

    func testMultipleTermsAreAnded() {
        // "java review" should match prompt 1 (name has both); "java standup"
        // matches nothing because no entry has both.
        XCTAssertEqual(sample.search("java review").map(\.prompt.id), ["1"])
        XCTAssertTrue(sample.search("java standup").isEmpty)
    }

    func testNamePrefixOutranksLaterMatches() {
        let idx = PromptIndex([
            entry(project: "x", id: "later",  name: "Reformat the json",   description: "json"),
            entry(project: "x", id: "prefix", name: "Json schema validate")
        ])
        let results = idx.search("json")
        XCTAssertEqual(results.first?.prompt.id, "prefix",
                       "name-prefix match must rank above name-substring match")
    }

    func testNoMatch() {
        XCTAssertTrue(sample.search("xyzzy").isEmpty)
    }
}
