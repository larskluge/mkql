import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController {
    private var webView: WebView!
    private var fileWatcher: FileWatcher?
    private var fileURL: URL?

    override func loadView() {
        webView = WebView(frame: NSRect(x: 0, y: 0, width: 1060, height: 900))
        webView.autoresizingMask = [.width, .height]
        webView.drawsBackground = false
        self.view = webView
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
