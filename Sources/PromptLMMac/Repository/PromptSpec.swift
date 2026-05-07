// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Tolerant subset of the promptlm-app PromptSpec schema, sufficient for
/// listing, rendering, and inserting prompts. Unknown fields are ignored.
///
/// Two shapes are accepted:
///
/// **Simple shape** (used by hand-authored fixtures and the previous
/// version of this client):
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
/// ```
///
/// **Server shape** (what `promptlm-app` actually writes into a repo):
/// ```yaml
/// id: 8ed659b7
/// name: support-prompt
/// group: support
/// description: Assist support agents
/// request:
///   messages:
///   - { role: system, content: "You are a helpful assistant." }
///   - { role: user,   content: "Help the customer {{customer_name}}." }
/// placeholders:
///   list:
///   - { name: customer_name, value: "" }
///   defaults:
///     customer_name: ""
/// ```
///
/// In the server shape we synthesise `text` from the message contents joined
/// with blank lines, and flatten the `list` + `defaults` form into the same
/// `[String: PlaceholderDef]` dictionary the rest of the app expects.
public struct PromptSpec: Decodable, Equatable {
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
        case id, name, group, description, text, placeholders, request
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? self.id
        self.group = try c.decodeIfPresent(String.self, forKey: .group)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)

        // Text resolution: explicit `text` wins; otherwise synthesise from
        // `request.messages[].content` joined with blank lines.
        if let explicit = try c.decodeIfPresent(String.self, forKey: .text) {
            self.text = explicit
        } else if let request = try c.decodeIfPresent(RequestEnvelope.self, forKey: .request),
                  !request.messages.isEmpty {
            self.text = request.messages
                .map { $0.content }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.text,
                .init(
                    codingPath: c.codingPath,
                    debugDescription: "Prompt spec must have either `text` or `request.messages`"
                )
            )
        }

        // Placeholders: accept either `[String: PlaceholderDef]` or the
        // server `{ list, defaults }` envelope.
        if c.contains(.placeholders) {
            self.placeholders = try Self.decodePlaceholders(container: c)
        } else {
            self.placeholders = [:]
        }
    }

    private static func decodePlaceholders(
        container c: KeyedDecodingContainer<CodingKeys>
    ) throws -> [String: PlaceholderDef] {
        // Try the simple map form first.
        if let map = try? c.decode([String: PlaceholderDef].self, forKey: .placeholders) {
            return map
        }
        // Fall back to the server envelope.
        let envelope = try c.decode(PlaceholderEnvelope.self, forKey: .placeholders)
        var result: [String: PlaceholderDef] = [:]
        for entry in envelope.list ?? [] {
            let defaultValue = envelope.defaults?[entry.name] ?? entry.value
            result[entry.name] = PlaceholderDef(
                defaultValue: defaultValue?.isEmpty == false ? defaultValue : nil
            )
        }
        return result
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

// MARK: - Server-shape envelopes (decode-only)

private struct RequestEnvelope: Decodable {
    let messages: [Message]

    struct Message: Decodable {
        let role: String?
        let content: String

        private enum CodingKeys: String, CodingKey { case role, content }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.role = try c.decodeIfPresent(String.self, forKey: .role)
            self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        }
    }

    private enum CodingKeys: String, CodingKey { case messages }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.messages = try c.decodeIfPresent([Message].self, forKey: .messages) ?? []
    }
}

private struct PlaceholderEnvelope: Decodable {
    let list: [Entry]?
    let defaults: [String: String]?

    struct Entry: Decodable {
        let name: String
        let value: String?
    }
}
