import XCTest
@testable import MarkItDownSwift

final class OutputPublisherTests: XCTestCase {
    func testExistingOutputIsProtectedByDefault() throws {
        let directory = try temporaryDirectory()
        let output = directory.appendingPathComponent("result.md")
        try Data("old".utf8).write(to: output)
        XCTAssertThrowsError(try OutputPublisher.publish("new", to: output, allowingOverwrite: false)) { error in
            guard case ConversionError.outputExists = error else { return XCTFail("unexpected error: \(error)") }
        }
        XCTAssertEqual(try String(contentsOf: output), "old")
    }

    func testOverwriteUsesNewContent() throws {
        let directory = try temporaryDirectory()
        let output = directory.appendingPathComponent("result.md")
        try Data("old".utf8).write(to: output)
        try OutputPublisher.publish("new", to: output, allowingOverwrite: true)
        XCTAssertEqual(try String(contentsOf: output), "new")
    }

    func testOutputPublisherLeavesNoTemporaryFiles() throws {
        let directory = try temporaryDirectory()
        let output = directory.appendingPathComponent("result.md")
        try OutputPublisher.publish("new", to: output, allowingOverwrite: false)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
