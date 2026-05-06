// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import PromptLMMac

final class MultiRepositoryTests: XCTestCase {

    private var workdir: URL!

    override func setUpWithError() throws {
        workdir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("promptlm-multi-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workdir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workdir)
    }

    private func writeContext(projects: [(name: String, localPath: String?)]) throws -> URL {
        let entries: [[String: Any?]] = projects.map { p in
            [
                "id": UUID().uuidString,
                "name": p.name,
                "localPath": p.localPath as Any?,
                "healthStatus": p.localPath == nil ? "BROKEN_LOCAL" : "HEALTHY"
            ]
        }
        let json: [String: Any] = ["projects": entries.map { $0.compactMapValues { $0 } }]
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = workdir.appendingPathComponent("context.json")
        try data.write(to: url)
        return url
    }

    private func writePrompt(in dir: URL, id: String, body: String = "Hello {{n}}") throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let yaml = """
        id: \(id)
        text: "\(body)"
        """
        try yaml.data(using: .utf8)!.write(to: dir.appendingPathComponent("\(id).yaml"))
    }

    func testAggregatesPromptsAcrossHealthyProjects() throws {
        let p1 = workdir.appendingPathComponent("repo1", isDirectory: true)
        let p2 = workdir.appendingPathComponent("repo2", isDirectory: true)
        try writePrompt(in: p1, id: "alpha")
        try writePrompt(in: p2, id: "beta")

        let ctx = try writeContext(projects: [
            ("repo1", p1.path),
            ("repo2", p2.path)
        ])
        let multi = MultiRepository(contextStore: ContextStore(path: ctx))
        let result = multi.load()

        XCTAssertEqual(result.sections.count, 2)
        XCTAssertEqual(result.allPrompts.count, 2)
        let ids = Set(result.allPrompts.map { $0.prompt.id })
        XCTAssertEqual(ids, ["alpha", "beta"])
    }

    func testMissingLocalPathSurfacesAsUnhealthySection() throws {
        let p1 = workdir.appendingPathComponent("real", isDirectory: true)
        try writePrompt(in: p1, id: "alpha")
        let bogus = "/tmp/promptlm-does-not-exist-\(UUID().uuidString)"

        let ctx = try writeContext(projects: [
            ("real", p1.path),
            ("ghost", bogus)
        ])
        let result = MultiRepository(contextStore: ContextStore(path: ctx)).load()

        XCTAssertEqual(result.sections.count, 2)
        let ghost = result.sections.first { $0.project.name == "ghost" }!
        if case .missingPath = ghost.health { /* ok */ } else {
            XCTFail("expected .missingPath, got \(ghost.health)")
        }
        XCTAssertTrue(ghost.prompts.isEmpty)

        let real = result.sections.first { $0.project.name == "real" }!
        XCTAssertEqual(real.health, .healthy)
        XCTAssertEqual(real.prompts.count, 1)
    }

    func testFallsBackToLegacyRootWhenContextMissing() throws {
        let bogusCtx = workdir.appendingPathComponent("nope.json")
        let promptsDir = workdir.appendingPathComponent("legacy", isDirectory: true)
        try writePrompt(in: promptsDir, id: "old")

        let multi = MultiRepository(
            contextStore: ContextStore(path: bogusCtx),
            fallbackRoot: promptsDir
        )
        let result = multi.load()
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(result.allPrompts.count, 1)
        XCTAssertEqual(result.allPrompts.first?.prompt.id, "old")
    }
}
