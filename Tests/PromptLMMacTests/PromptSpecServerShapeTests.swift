// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
import Yams
@testable import PromptLMMac

/// Validates the tolerant decoder against the on-disk shape produced by the
/// real promptlm-app server (see `~/testrepo/prompts/.../promptlm.yml`),
/// where `text` is implicit in `request.messages` and placeholders are
/// surfaced via a `list`/`defaults` envelope rather than a flat map.
final class PromptSpecServerShapeTests: XCTestCase {

    func testDecodesServerShapeWithRequestMessagesAndListPlaceholders() throws {
        let yaml = """
        id: 8ed659b7
        name: support-prompt
        group: support
        description: Assist support agents
        request:
          messages:
          - content: You are a helpful assistant.
            role: system
          - content: "Help the customer {{customer_name}}."
            role: user
        placeholders:
          list:
          - name: customer_name
            value: ""
          defaults:
            customer_name: "Acme"
        """
        let spec = try YAMLDecoder().decode(PromptSpec.self, from: yaml)
        XCTAssertEqual(spec.id, "8ed659b7")
        XCTAssertEqual(spec.name, "support-prompt")
        XCTAssertEqual(spec.group, "support")
        XCTAssertTrue(spec.text.contains("You are a helpful assistant."))
        XCTAssertTrue(spec.text.contains("Help the customer {{customer_name}}."))
        XCTAssertEqual(spec.placeholders.count, 1)
        XCTAssertEqual(spec.placeholders["customer_name"]?.defaultValue, "Acme")
    }

    func testFallsBackToEntryValueWhenDefaultsMissing() throws {
        let yaml = """
        id: x
        request:
          messages:
          - content: "hi {{a}}"
        placeholders:
          list:
          - name: a
            value: "from-entry"
        """
        let spec = try YAMLDecoder().decode(PromptSpec.self, from: yaml)
        XCTAssertEqual(spec.placeholders["a"]?.defaultValue, "from-entry")
    }

    func testSimpleShapeStillWorks() throws {
        let yaml = """
        id: greet
        name: Greet
        text: "Hello {{name}}"
        placeholders:
          name:
            default: "World"
            required: true
        """
        let spec = try YAMLDecoder().decode(PromptSpec.self, from: yaml)
        XCTAssertEqual(spec.text, "Hello {{name}}")
        XCTAssertEqual(spec.placeholders["name"]?.defaultValue, "World")
        XCTAssertEqual(spec.placeholders["name"]?.required, true)
    }

    func testMissingTextAndMessagesThrows() {
        let yaml = """
        id: bad
        name: Bad
        """
        XCTAssertThrowsError(try YAMLDecoder().decode(PromptSpec.self, from: yaml))
    }
}
