import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var fileWatcher: FileWatcher?
    private(set) var fileURL: URL?
    private var fileHistory: [URL] = []
    private var xpcConnection: NSXPCConnection?

    /// Injectable URL opener. Default uses the XPC service to open in the default browser.
    var openURL: (URL) -> Void = { _ in }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "mdql")

        webView = WKWebView(frame: NSRect(origin: .zero, size: MarkdownRenderer.previewSize), configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        self.view = webView
        preferredContentSize = MarkdownRenderer.previewSize

        // Set up XPC connection to unsandboxed URL opener
        let connection = NSXPCConnection(serviceName: "com.mdql.app.open-url")
        connection.remoteObjectInterface = NSXPCInterface(with: OpenURLProtocol.self)
        connection.resume()
        self.xpcConnection = connection

        self.openURL = { [weak self] url in
            guard let proxy = self?.xpcConnection?.remoteObjectProxyWithErrorHandler({ error in
                NSLog("mdql XPC error: \(error)")
            }) as? OpenURLProtocol else { return }
            proxy.open(url) { _ in }
        }
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            try loadMarkdownFile(at: url)
            handler(nil)
        } catch {
            handler(error)
        }
    }

    // MARK: - URL handling

    /// Handles an openURL action. Exposed for testing.
    func handleOpenURL(_ urlString: String, background: Bool) {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return }
        openURL(url)
    }

    /// Handles an openMarkdown action. Exposed for testing.
    func handleOpenMarkdown(_ urlString: String) {
        let decoded = urlString.removingPercentEncoding ?? urlString
        guard let currentURL = self.fileURL,
              !decoded.isEmpty else { return }

        let resolved = URL(fileURLWithPath: decoded, relativeTo: currentURL.deletingLastPathComponent()).standardized
        let ext = resolved.pathExtension.lowercased()
        guard ext == "md" || ext == "markdown" else { return }

        // Read file via unsandboxed XPC service to bypass QL extension sandbox
        guard let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ _ in }) as? OpenURLProtocol else { return }
        proxy.readFile(at: resolved.path) { [weak self] content, error in
            guard let self = self, let markdown = content else { return }
            DispatchQueue.main.async {
                self.navigateToMarkdown(markdown, url: resolved)
            }
        }
    }

    private func navigateToMarkdown(_ markdown: String, url: URL) {
        if let current = fileURL {
            fileHistory.append(current)
        }
        fileWatcher?.stop()
        fileURL = url
        let title = url.deletingPathExtension().lastPathComponent
        let html = MarkdownRenderer.render(markdown: markdown, title: title, showBackButton: !fileHistory.isEmpty)
        webView.loadHTMLString(html, baseURL: nil)
        fileWatcher = FileWatcher(url: url) { [weak self] in
            self?.reloadContent()
        }
        fileWatcher?.start()
    }

    private func goBack() {
        guard let previousURL = fileHistory.popLast() else { return }
        guard let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ _ in }) as? OpenURLProtocol else { return }
        proxy.readFile(at: previousURL.path) { [weak self] content, error in
            guard let self = self, let markdown = content else { return }
            DispatchQueue.main.async {
                self.fileWatcher?.stop()
                self.fileURL = previousURL
                let title = previousURL.deletingPathExtension().lastPathComponent
                let html = MarkdownRenderer.render(markdown: markdown, title: title, showBackButton: !self.fileHistory.isEmpty)
                self.webView.loadHTMLString(html, baseURL: nil)
                self.fileWatcher = FileWatcher(url: previousURL) { [weak self] in
                    self?.reloadContent()
                }
                self.fileWatcher?.start()
            }
        }
    }

    /// Loads and renders a markdown file, replacing the current preview.
    /// Used for the initial file (which the sandbox grants access to).
    @discardableResult
    func loadMarkdownFile(at url: URL) throws -> Bool {
        fileWatcher?.stop()
        fileURL = url

        let html = try MarkdownRenderer.render(fileAt: url)
        webView.loadHTMLString(html, baseURL: nil)

        fileWatcher = FileWatcher(url: url) { [weak self] in
            self?.reloadContent()
        }
        fileWatcher?.start()
        return true
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "openURL":
            if let urlString = body["url"] as? String {
                let background = body["background"] as? Bool ?? false
                handleOpenURL(urlString, background: background)
            }
        case "openMarkdown":
            if let urlString = body["url"] as? String {
                handleOpenMarkdown(urlString)
            }
        case "goBack":
            goBack()
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Cancel all link-activated navigations — JS message handlers handle everything.
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url,
               let scheme = url.scheme,
               ["http", "https"].contains(scheme) {
                handleOpenURL(url.absoluteString, background: false)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    private func reloadContent() {
        guard let url = fileURL else { return }

        // Use XPC to read file (sandbox may block direct reads for navigated files)
        guard let proxy = xpcConnection?.remoteObjectProxyWithErrorHandler({ _ in }) as? OpenURLProtocol else { return }
        proxy.readFile(at: url.path) { [weak self] content, error in
            guard let self = self, let markdown = content else { return }
            DispatchQueue.main.async {
                let bodyHTML = MarkdownRenderer.renderBody(markdown: markdown)
                let base64 = Data(bodyHTML.utf8).base64EncodedString()
                self.webView.evaluateJavaScript(
                    "document.querySelector('.markdown-body').innerHTML = new TextDecoder().decode(Uint8Array.from(atob('\(base64)'), c => c.charCodeAt(0)))"
                )
            }
        }
    }
}
