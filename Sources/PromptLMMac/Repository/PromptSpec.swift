// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Tolerant subset of the promptlm-app PromptSpec schema, sufficient for
/// listing, rendering, and inserting prompts. Unknown fields are ignored.
///
/// Schema (YAML/JSON):
/// ```yaml
/// id: example-prompt
/// name: Example Prompt
/// group: examples
/// description: A demo prompt
/// text: |
///   Hello {{name}}, write {{count}} ideas about {{topic}}.
/// placeholders:
///   name:
///     description: Your name
///     default: Fabian
///   count:
///     default: "3"
///   topic:
///     required: true
/// ```
public struct PromptSpec: Codable, Equatable {
    public let id: String
    public let name: String
    public let group: String?
    public let description: String?
    public let text: String
    public let placeholders: [String: PlaceholderDef]

    public init(
        id: String,
        name: String,
        group: String? = nil,
        description: String? = nil,
        text: String,
        placeholders: [String: PlaceholderDef] = [:]
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.description = description
        self.text = text
        self.placeholders = placeholders
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, group, description, text, placeholders
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? self.id
        self.group = try c.decodeIfPresent(String.self, forKey: .group)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.text = try c.decode(String.self, forKey: .text)
        self.placeholders = try c.decodeIfPresent(
            [String: PlaceholderDef].self, forKey: .placeholders
        ) ?? [:]
    }
}

/// Per-placeholder metadata.
public struct PlaceholderDef: Codable, Equatable {
    public let description: String?
    public let defaultValue: String?
    public let required: Bool?
    public let type: String?
    public let options: [String]?

    public init(
        description: String? = nil,
        defaultValue: String? = nil,
        required: Bool? = nil,
        type: String? = nil,
        options: [String]? = nil
    ) {
        self.description = description
        self.defaultValue = defaultValue
        self.required = required
        self.type = type
        self.options = options
    }

    private enum CodingKeys: String, CodingKey {
        case description
        case defaultValue = "default"
        case required, type, options
    }
}
