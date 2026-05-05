// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import PromptLMMac

final class PromptRendererTests: XCTestCase {

    private let renderer = PromptRenderer()

    func testEmptyTemplate() throws {
        XCTAssertEqual(try renderer.render("", with: [:]), "")
    }

    func testTemplateWithoutPlaceholdersIsReturnedVerbatim() throws {
        XCTAssertEqual(try renderer.render("Hello world", with: [:]), "Hello world")
    }

    func testSingleSubstitution() throws {
        let out = try renderer.render("Hello {{name}}", with: ["name": "Fabian"])
        XCTAssertEqual(out, "Hello Fabian")
    }

    func testMultipleSubstitutionsInOrder() throws {
        let out = try renderer.render(
            "{{a}} - {{b}} - {{c}}",
            with: ["a": "1", "b": "2", "c": "3"]
        )
        XCTAssertEqual(out, "1 - 2 - 3")
    }

    func testRepeatedKey() throws {
        let out = try renderer.render(
            "{{x}}/{{x}}/{{x}}",
            with: ["x": "yo"]
        )
        XCTAssertEqual(out, "yo/yo/yo")
    }

    func testWhitespaceInsideBracesIsAllowed() throws {
        let out = try renderer.render("Hi {{   name }}!", with: ["name": "Sam"])
        XCTAssertEqual(out, "Hi Sam!")
    }

    func testMissingValueThrows() {
        XCTAssertThrowsError(try renderer.render("Hi {{name}}", with: [:])) { error in
            guard case RenderError.missingValue(let key) = error else {
                return XCTFail("Wrong error type: \(error)")
            }
            XCTAssertEqual(key, "name")
        }
    }

    func testEmptyStringIsAValidValue() throws {
        let out = try renderer.render("[{{x}}]", with: ["x": ""])
        XCTAssertEqual(out, "[]")
    }

    func testValueContainingBracesIsNotReRendered() throws {
        let out = try renderer.render(
            "Outer {{inner}}",
            with: ["inner": "{{not-a-key}}"]
        )
        XCTAssertEqual(out, "Outer {{not-a-key}}")
    }

    func testKeysWithUnderscoresAndHyphens() throws {
        let out = try renderer.render(
            "{{user_id}}/{{prompt-id}}",
            with: ["user_id": "42", "prompt-id": "abc"]
        )
        XCTAssertEqual(out, "42/abc")
    }

    func testMultilineTemplate() throws {
        let template = """
        Line one with {{a}}.
        Line two with {{b}}.
        """
        let out = try renderer.render(template, with: ["a": "X", "b": "Y"])
        XCTAssertEqual(out, "Line one with X.\nLine two with Y.")
    }

    func testNonMatchingBracesArePreserved() throws {
        // Single braces, mismatched, or invalid keys should not be touched.
        XCTAssertEqual(try renderer.render("{not-a-tag}", with: [:]), "{not-a-tag}")
        XCTAssertEqual(try renderer.render("{{}} stays", with: [:]), "{{}} stays")
        XCTAssertEqual(try renderer.render("{{1abc}} too", with: [:]), "{{1abc}} too")
    }
}
