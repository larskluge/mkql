import XCTest
import WebKit
@testable import mdqlPreview

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

    func testPolicyDelegateIsSetAfterLoadView() {
        let controller = PreviewController()
        controller.loadView()
        // The webView should have its policyDelegate wired to the controller
        // so link clicks are intercepted and opened in the default browser.
        let webView = controller.view.subviews.first as? WebView
            ?? (controller.view as? WebView)
        XCTAssertNotNil(webView?.policyDelegate,
                        "policyDelegate must be set so link clicks open the default browser")
    }

    func testNonLinkNavigationIsAllowed() {
        // When navigation type is NOT a link click (e.g. initial HTML load),
        // the listener should call .use() to allow the navigation.
        let controller = PreviewController()
        controller.loadView()

        let expectation = XCTestExpectation(description: "use() called for non-link navigation")
        let mockListener = MockPolicyDecisionListener(onUse: { expectation.fulfill() }, onIgnore: {
            XCTFail("ignore() should not be called for non-link navigation")
        })

        let actionInfo: [AnyHashable: Any] = [
            WebActionNavigationTypeKey: WebNavigationType.other.rawValue
        ]
        controller.webView(nil,
                           decidePolicyForNavigationAction: actionInfo,
                           request: URLRequest(url: URL(string: "about:blank")!),
                           frame: nil,
                           decisionListener: mockListener)

        wait(for: [expectation], timeout: 1.0)
    }

    func testLinkClickNavigationIsIgnored() {
        // When a link is clicked, the listener should call .ignore() so the
        // WebView does not navigate internally; the URL is opened externally instead.
        let controller = PreviewController()
        controller.loadView()

        let expectation = XCTestExpectation(description: "ignore() called for link click")
        let mockListener = MockPolicyDecisionListener(onUse: {
            XCTFail("use() should not be called for link click")
        }, onIgnore: { expectation.fulfill() })

        let actionInfo: [AnyHashable: Any] = [
            WebActionNavigationTypeKey: WebNavigationType.linkClicked.rawValue
        ]
        let request = URLRequest(url: URL(string: "https://example.com")!)
        controller.webView(nil,
                           decidePolicyForNavigationAction: actionInfo,
                           request: request,
                           frame: nil,
                           decisionListener: mockListener)

        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Test helpers

private class MockPolicyDecisionListener: NSObject, WebPolicyDecisionListener {
    private let onUse: () -> Void
    private let onIgnore: () -> Void

    init(onUse: @escaping () -> Void, onIgnore: @escaping () -> Void) {
        self.onUse = onUse
        self.onIgnore = onIgnore
    }

    func use() { onUse() }
    func ignore() { onIgnore() }
    func download() {}
}
