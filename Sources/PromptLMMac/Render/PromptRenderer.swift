// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

public enum RenderError: Error, CustomStringConvertible, Equatable {
    case missingValue(key: String)

    public var description: String {
        switch self {
        case .missingValue(let key):
            return "Missing value for placeholder '\(key)'"
        }
    }
}

/// `{{key}}` placeholder substitution.
///
/// Compatible with the spirit of promptlm-app's `DefaultPromptRenderer`:
/// keys match `[A-Za-z_][A-Za-z0-9_-]*`, surrounding whitespace inside the
/// braces is allowed (`{{ key }}`), and substituted values are inserted
/// verbatim — no re-rendering.
///
/// Strict by default: a `{{key}}` with no entry in `values` throws
/// `RenderError.missingValue`. Empty string values are valid.
public struct PromptRenderer {

    private static let pattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z_][A-Za-z0-9_-]*)\s*\}\}"#)
    }()

    public init() {}

    public func render(_ template: String, with values: [String: String]) throws -> String {
        let ns = template as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = Self.pattern.matches(in: template, range: fullRange)
        if matches.isEmpty { return template }

        var result = ""
        var cursor = 0
        for match in matches {
            let keyRange = match.range(at: 1)
            let key = ns.substring(with: keyRange)
            guard let value = values[key] else {
                throw RenderError.missingValue(key: key)
            }
            if match.range.location > cursor {
                result += ns.substring(with: NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                ))
            }
            result += value
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            result += ns.substring(with: NSRange(
                location: cursor,
                length: ns.length - cursor
            ))
        }
        return result
    }
}
