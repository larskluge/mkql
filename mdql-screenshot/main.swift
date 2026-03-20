import Cocoa
import WebKit  // legacy WebView

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: mdql-screenshot <input.md> <output.png> [width] [height]\n", stderr)
    exit(1)
}
let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let width = CommandLine.arguments.count > 3
    ? CGFloat(Double(CommandLine.arguments[3]) ?? Double(MarkdownRenderer.previewSize.width))
    : MarkdownRenderer.previewSize.width
let height = CommandLine.arguments.count > 4
    ? CGFloat(Double(CommandLine.arguments[4]) ?? Double(MarkdownRenderer.previewSize.height))
    : MarkdownRenderer.previewSize.height

let inputURL = URL(fileURLWithPath: inputPath)

// Off-screen window required for legacy WebView to render and
// produce a valid bitmap via cacheDisplay(in:to:).
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: width, height: height),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.isReleasedWhenClosed = false

class Screenshotter: NSObject, WebFrameLoadDelegate {
    let webView: WebView
    let outputPath: String

    init(webView: WebView, outputPath: String) {
        self.webView = webView
        self.outputPath = outputPath
        super.init()
        webView.frameLoadDelegate = self
    }

    func load(html: String) {
        webView.mainFrame.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
        // Only act on the main frame finishing
        guard frame === webView.mainFrame else { return }

        let bounds = webView.bounds
        guard let bitmap = webView.bitmapImageRepForCachingDisplay(in: bounds) else {
            fputs("Failed to create bitmap\n", stderr)
            exit(1)
        }
        webView.cacheDisplay(in: bounds, to: bitmap)

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            fputs("PNG conversion failed\n", stderr)
            exit(1)
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            fputs("Failed to write PNG: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        print("Screenshot saved to \(outputPath)")
        exit(0)
    }

    func webView(_ sender: WebView!, didFailLoadWithError error: Error!, for frame: WebFrame!) {
        fputs("Load failed: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

do {
    let html = try MarkdownRenderer.render(fileAt: inputURL)
    // Use the shared factory — same WebView configuration as the QuickLook extension.
    let webView = MarkdownRenderer.createPreviewWebView(
        frame: NSRect(x: 0, y: 0, width: width, height: height)
    )
    window.contentView = webView

    let screenshotter = Screenshotter(webView: webView, outputPath: outputPath)
    screenshotter.load(html: html)
    withExtendedLifetime(screenshotter) {
        RunLoop.main.run()
    }
} catch {
    fputs("Failed to render: \(error)\n", stderr)
    exit(1)
}
