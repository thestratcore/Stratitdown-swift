import XCTest
@testable import MarkItDownSwift

final class MistralOCRResponseTests: XCTestCase {
    private func render(_ pages: [[String: Any]]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: ["pages": pages])
        return try JSONDecoder().decode(OCRResponse.self, from: data).combinedMarkdown()
    }

    func testReportedTablePlaceholderIsExpanded() throws {
        let table = "| Name | Revenue |\n| --- | --- |\n| Alice | €123 |"
        let result = try render([["index": 0,
            "markdown": "# Obchodní tým – 9/2026\n\nExport CSV\n\n[tbl-0.md](tbl-0.md)",
            "tables": [["id": "tbl-0.md", "content": table]]]])
        XCTAssertEqual(result, "# Obchodní tým – 9/2026\n\nExport CSV\n\n" + table)
    }

    func testOldResponsesWithoutTablesAndPageOrdering() throws {
        XCTAssertEqual(try render([
            ["index": 2, "markdown": "Second"],
            ["index": 1, "markdown": "First", "tables": NSNull()]
        ]), "First\n\n---\n\nSecond")
    }

    func testTableIDsAreScopedToPages() throws {
        let pages = ["First table", "Second table"].enumerated().map { index, content in
            ["index": index, "markdown": "[tbl-0.md](tbl-0.md)",
             "tables": [["id": "tbl-0.md", "content": content]]] as [String: Any]
        }
        XCTAssertEqual(try render(pages), "First table\n\n---\n\nSecond table")
    }

    func testRepeatedLinksHTMLAndLiteralReplacementText() throws {
        let content = "<table><tr><td>$1 \\ value</td></tr></table>"
        XCTAssertEqual(try render([["index": 0,
            "markdown": "[Table](tbl-0.html)\n\n[tbl-0.html](tbl-0.html)",
            "tables": [["id": "tbl-0.html", "content": content]]]]), content + "\n\n" + content)
    }

    func testUnreferencedReturnedTableIsPreservedOnce() throws {
        let tables = [["id": "tbl-0.md", "content": "Table content"]]
        XCTAssertEqual(try render([["index": 0, "markdown": "Heading", "tables": tables]]),
                       "Heading\n\nTable content")
        XCTAssertEqual(try render([["index": 0, "markdown": "Heading\n\nTable content", "tables": tables]]),
                       "Heading\n\nTable content")
    }

    func testMissingTableContentFailsInsteadOfPublishingBrokenLink() throws {
        XCTAssertThrowsError(try render([["index": 0, "markdown": "[tbl-0.md](tbl-0.md)"]]))
    }

    func testEmptyAndDuplicateTablesFail() throws {
        for tables in [
            [["id": "tbl-0.md", "content": " \n"]],
            [["id": "tbl-0.md", "content": "One"], ["id": "tbl-0.md", "content": "Two"]]
        ] {
            XCTAssertThrowsError(try render([["index": 0, "markdown": "[tbl-0.md](tbl-0.md)", "tables": tables]]))
        }
    }

    func testImageAndExternalLinksArePreserved() throws {
        let markdown = "![img-0.jpeg](img-0.jpeg)\n[Source](https://example.com/tbl-0.md)"
        XCTAssertEqual(try render([["index": 0, "markdown": markdown, "tables": []]]), markdown)
    }

    func testEmptyResponseFails() throws {
        XCTAssertThrowsError(try render([]))
    }
}
