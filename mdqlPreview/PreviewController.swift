import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController, WebPolicyDelegate {
    private var webView: WebView!
    private var fileWatcher: FileWatcher?
    private var fileURL: URL?

    static let previewSize = NSSize(width: 1060, height: 900)

    override func loadView() {
        webView = WebView(frame: NSRect(origin: .zero, size: Self.previewSize))
        webView.autoresizingMask = [.width, .height]
        webView.drawsBackground = false
        webView.policyDelegate = self
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

    func webView(_ webView: WebView!, decidePolicyForNavigationAction actionInformation: [AnyHashable : Any]!, request: URLRequest!, frame: WebFrame!, decisionListener listener: (any WebPolicyDecisionListener)!) {
        guard let navType = actionInformation[WebActionNavigationTypeKey] as? Int,
              navType == WebNavigationType.linkClicked.rawValue,
              let url = request?.url else {
            listener.use()
            return
        }
        let isBackground = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
        if isBackground {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.open(url, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
        listener.ignore()
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
