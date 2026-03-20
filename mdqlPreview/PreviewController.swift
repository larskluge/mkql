import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController, WebFrameLoadDelegate {
    private var webView: WebView!
    private var fileWatcher: FileWatcher?
    private var fileURL: URL?
    private var linkBridge: LinkBridge!
    var copyURLToClipboard: (URL) -> Void = { url in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    static let previewSize = NSSize(width: 1060, height: 900)

    override func loadView() {
        linkBridge = LinkBridge { [weak self] urlString in
            guard let self = self, let url = URL(string: urlString) else { return }
            self.copyURLToClipboard(url)
            // Tell JS to show the toast
            self.webView.stringByEvaluatingJavaScript(from:
                "window.__mdqlShowToast && window.__mdqlShowToast('\(url.absoluteString.replacingOccurrences(of: "'", with: "\\'"))')"
            )
        }

        webView = WebView(frame: NSRect(origin: .zero, size: Self.previewSize))
        webView.autoresizingMask = [.width, .height]
        webView.drawsBackground = false
        webView.frameLoadDelegate = self
        self.view = webView
        preferredContentSize = Self.previewSize
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        fileURL = url

        do {
            let html = try MarkdownRenderer.render(fileAt: url)
            webView.mainFrame.loadHTMLString(html, baseURL: nil)
        } catch {
            handler(error)
            return
        }

        handler(nil)

        // Watch for file changes
        fileWatcher = FileWatcher(url: url) { [weak self] in
            self?.reloadContent()
        }
        fileWatcher?.start()
    }

    // MARK: - WebFrameLoadDelegate

    func webView(_ sender: WebView!, didClearWindowObject windowObject: WebScriptObject!, for frame: WebFrame!) {
        windowObject.setValue(linkBridge, forKey: "mdql")
    }

    private func reloadContent() {
        guard let url = fileURL,
              let markdown = try? String(contentsOf: url, encoding: .utf8) else { return }

        let bodyHTML = MarkdownRenderer.renderBody(markdown: markdown)
        let base64 = Data(bodyHTML.utf8).base64EncodedString()
        webView.stringByEvaluatingJavaScript(from:
            "document.querySelector('.markdown-body').innerHTML = new TextDecoder().decode(Uint8Array.from(atob('\(base64)'), c => c.charCodeAt(0)))"
        )
    }
}

// MARK: - JavaScript bridge

@objc class LinkBridge: NSObject {
    private let handler: (String) -> Void

    init(handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    @objc func openURL(_ urlString: String) {
        handler(urlString)
    }

    override class func isSelectorExcluded(fromWebScript selector: Selector) -> Bool {
        return selector != #selector(openURL(_:))
    }

    override class func webScriptName(for selector: Selector) -> String? {
        if selector == #selector(openURL(_:)) { return "openURL" }
        return nil
    }
}
