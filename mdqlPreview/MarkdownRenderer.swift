import Foundation
import Markdown

private class BundleAnchor {}

public struct MarkdownRenderer {

    public static func render(fileAt url: URL) throws -> String {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let title = url.deletingPathExtension().lastPathComponent
        return render(markdown: markdown, title: title)
    }

    public static func render(markdown: String, title: String = "") -> String {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        let html = HTMLFormatter.format(document)
        return wrapInHTMLDocument(body: html, title: title)
    }

    public static func renderBody(markdown: String) -> String {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        return HTMLFormatter.format(document)
    }

    private static func wrapInHTMLDocument(body: String, title: String) -> String {
        let css = loadCSS()
        let escapedTitle = escapeHTML(title)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapedTitle)</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <article class="markdown-body">
        \(body)
        </article>
        </body>
        </html>
        """
    }

    private static func loadCSS() -> String {
        guard let url = Bundle(for: BundleAnchor.self).url(forResource: "preview", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return css
    }

    static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
