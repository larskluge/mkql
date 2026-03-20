import XCTest
import WebKit

final class PreviewControllerTests: XCTestCase {

    func testPreviewSizeIsLarge() {
        let size = PreviewController.previewSize
        XCTAssertGreaterThanOrEqual(size.width, 1060, "Preview width must be at least 1060")
        XCTAssertGreaterThanOrEqual(size.height, 900, "Preview height must be at least 900")
    }

    func testPreferredContentSizeIsSet() {
        let controller = PreviewController()
        controller.loadView()
        XCTAssertEqual(controller.preferredContentSize, PreviewController.previewSize,
                       "preferredContentSize must match previewSize")
    }

    func testViewFrameMatchesPreviewSize() {
        let controller = PreviewController()
        controller.loadView()
        XCTAssertEqual(controller.view.frame.size, PreviewController.previewSize,
                       "View frame must match previewSize")
    }

    // MARK: - Link handling

    func testFrameLoadDelegateIsSetAfterLoadView() {
        let controller = PreviewController()
        controller.loadView()
        let webView = controller.view as? WebView
        XCTAssertNotNil(webView?.frameLoadDelegate,
                        "frameLoadDelegate must be set for JS bridge injection")
    }

    func testLinkBridgeCopiesURL() {
        let controller = PreviewController()
        controller.loadView()

        var copiedURL: URL?
        controller.copyURLToClipboard = { url in copiedURL = url }

        let webView = controller.view as! WebView
        let html = MarkdownRenderer.render(markdown: "[link](https://example.com)", title: "t")
        webView.mainFrame.loadHTMLString(html, baseURL: nil)

        let expectation = XCTestExpectation(description: "bridge callable")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.stringByEvaluatingJavaScript(from: "window.mdql.openURL('https://example.com')")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(copiedURL?.absoluteString, "https://example.com")
    }

    func testRenderedHTMLContainsLinkScript() {
        let html = MarkdownRenderer.render(markdown: "[test](https://example.com)", title: "t")
        XCTAssertTrue(html.contains("window.mdql.openURL"), "HTML must contain JS bridge click handler")
        XCTAssertTrue(html.contains("__mdqlShowToast"), "HTML must contain toast notification")
    }
}
