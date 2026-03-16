import XCTest
import Markdown

final class MarkdownRendererTests: XCTestCase {

    private func fixtureURL(_ name: String) -> URL {
        let bundle = Bundle(for: type(of: self))
        return bundle.url(forResource: name, withExtension: "md", subdirectory: "Fixtures")
            ?? URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("\(name).md")
    }

    // MARK: - Basic Markdown

    func testRenderBasicMarkdown() {
        let md = """
        # Hello

        A **bold** and *italic* paragraph.

        Some `inline code` here.

        [Link](https://example.com)
        """
        let html = MarkdownRenderer.render(markdown: md)
        XCTAssertTrue(html.contains("<h1>"), "Should contain h1")
        XCTAssertTrue(html.contains("<p>"), "Should contain p")
        XCTAssertTrue(html.contains("<a href="), "Should contain link")
        XCTAssertTrue(html.contains("<em>"), "Should contain em")
        XCTAssertTrue(html.contains("<strong>"), "Should contain strong")
        XCTAssertTrue(html.contains("<code>"), "Should contain code")
    }

    // MARK: - GFM Features

    func testRenderGFMTable() {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = MarkdownRenderer.render(markdown: md)
        XCTAssertTrue(html.contains("<table>"), "Should contain table")
        XCTAssertTrue(html.contains("<th>"), "Should contain th")
        XCTAssertTrue(html.contains("<td>"), "Should contain td")
    }

    func testRenderGFMTaskList() {
        let md = """
        - [x] Done
        - [ ] Not done
        """
        let html = MarkdownRenderer.render(markdown: md)
        XCTAssertTrue(html.contains("<input type=\"checkbox\""), "Should contain checkbox input")
    }

    func testRenderGFMStrikethrough() {
        let md = "This is ~~deleted~~ text."
        let html = MarkdownRenderer.render(markdown: md)
        XCTAssertTrue(html.contains("<del>"), "Should contain del for strikethrough")
    }

    func testRenderCodeBlock() {
        let md = """
        ```swift
        let x = 42
        ```
        """
        let html = MarkdownRenderer.render(markdown: md)
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">"), "Should contain code block with language class")
    }

    // MARK: - HTML Document Structure

    func testHTMLDocumentStructure() {
        let html = MarkdownRenderer.render(markdown: "# Test")
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"), "Should start with DOCTYPE")
        XCTAssertTrue(html.contains("<style>"), "Should contain style tag")
        XCTAssertTrue(html.contains("<article class=\"markdown-body\">"), "Should contain markdown-body article")
    }

    func testTitleEscaping() {
        let html = MarkdownRenderer.render(markdown: "Hello", title: "<script>alert('xss')</script>")
        XCTAssertTrue(html.contains("&lt;script&gt;"), "Title should be HTML-escaped")
        XCTAssertFalse(html.contains("<script>alert"), "Title should not contain raw script tag")
    }

    func testEmptyFile() {
        let html = MarkdownRenderer.render(markdown: "")
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"), "Empty input should still produce valid HTML")
        XCTAssertTrue(html.contains("<article class=\"markdown-body\">"), "Should contain article wrapper")
    }

    // MARK: - CSS

    func testCSSContainsDarkMode() {
        let html = MarkdownRenderer.render(markdown: "test")
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"), "CSS should contain dark mode media query")
    }

    func testCSSContainsInkpadTokens() {
        let html = MarkdownRenderer.render(markdown: "test")
        XCTAssertTrue(html.contains("#3f3b3d"), "CSS should contain inkpad text color")
        XCTAssertTrue(html.contains("#4183c4"), "CSS should contain inkpad link color")
        XCTAssertTrue(html.contains("#f9f9f9"), "CSS should contain inkpad bg color")
    }

    // MARK: - File-based rendering

    func testRenderFromURL() throws {
        let url = fixtureURL("basic")
        let html = try MarkdownRenderer.render(fileAt: url)
        XCTAssertTrue(html.contains("<h1>"), "Should render headings from file")
        XCTAssertTrue(html.contains("<strong>"), "Should render bold from file")
    }

    func testRenderFromString() {
        let html = MarkdownRenderer.render(markdown: "**hello**")
        XCTAssertTrue(html.contains("<strong>"), "Should render bold from string")
    }
}
