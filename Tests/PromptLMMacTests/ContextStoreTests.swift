// Copyright 2026 promptLM contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import PromptLMMac

final class ContextStoreTests: XCTestCase {

    private func tempContextFile(_ json: String) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("promptlm-ctx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("context.json")
        try json.data(using: .utf8)!.write(to: url)
        return url
    }

    func testMissingFileYieldsEmptyResult() {
        let bogus = URL(fileURLWithPath: "/tmp/promptlm-ctx-missing-\(UUID().uuidString).json")
        let store = ContextStore(path: bogus)
        let result = store.load()
        XCTAssertFalse(result.fileExists)
        XCTAssertTrue(result.projects.isEmpty)
        XCTAssertNil(result.error)
    }

    func testDecodesProjectsFromCliShape() throws {
        // Mirrors the real shape produced by promptlm-app's context.json.
        let json = """
        {
          "projects": [
            {
              "id": "abc",
              "name": "testrepo",
              "description": null,
              "healthStatus": "HEALTHY",
              "healthMessage": null,
              "promptCount": 1,
              "localPath": "/Users/fk/testrepo",
              "repositoryUrl": "https://github.com/fabapp2/testrepo"
            },
            {
              "id": "def",
              "name": "missing-repo",
              "healthStatus": "BROKEN_LOCAL",
              "localPath": "/tmp/does-not-exist-\(UUID().uuidString)"
            }
          ],
          "activeProject": null
        }
        """
        let url = try tempContextFile(json)
        let result = ContextStore(path: url).load()
        XCTAssertTrue(result.fileExists)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.projects.count, 2)
        XCTAssertEqual(result.projects[0].name, "testrepo")
        XCTAssertEqual(result.projects[0].localPath, "/Users/fk/testrepo")
        XCTAssertEqual(result.projects[1].name, "missing-repo")
    }

    func testMalformedFileSurfacesAsDecodeError() throws {
        let url = try tempContextFile("{ not json")
        let result = ContextStore(path: url).load()
        XCTAssertTrue(result.fileExists)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.projects.isEmpty)
    }

    func testHealthEvaluation() {
        let healthy = ContextProject(name: "x", localPath: NSTemporaryDirectory())
        XCTAssertEqual(healthy.evaluateHealth(), .healthy)

        let bogus = "/tmp/promptlm-missing-\(UUID().uuidString)"
        let missing = ContextProject(name: "x", localPath: bogus)
        if case .missingPath = missing.evaluateHealth() { /* ok */ } else {
            XCTFail("expected .missingPath")
        }

        let nopath = ContextProject(name: "x", localPath: nil)
        XCTAssertEqual(nopath.evaluateHealth(), .noLocalPath)
    }
}
