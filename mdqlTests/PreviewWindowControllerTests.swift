import XCTest

final class PreviewWindowControllerTests: XCTestCase {

    func testWindowCreation() {
        let controller = PreviewWindowController()
        XCTAssertNotNil(controller.window)
        XCTAssertEqual(controller.window?.title, "mdql")
        let contentRect = controller.window!.contentRect(forFrameRect: controller.window!.frame)
        XCTAssertEqual(contentRect.size.width, 900)
        XCTAssertEqual(contentRect.size.height, 700)
    }

    func testLoadFile() {
        let controller = PreviewWindowController()
        controller.loadFile(fixtureURL("basic"))
        XCTAssertEqual(controller.window?.title, "basic.md")
        XCTAssertEqual(controller.currentURL, fixtureURL("basic"))
    }

    func testFileWatcherStarted() {
        let controller = PreviewWindowController()
        controller.loadFile(fixtureURL("basic"))
        XCTAssertTrue(controller.isWatching)
    }

    func testLoadSecondFileReplacesFirst() {
        let controller = PreviewWindowController()
        controller.loadFile(fixtureURL("basic"))
        XCTAssertEqual(controller.window?.title, "basic.md")

        controller.loadFile(fixtureURL("gfm"))
        XCTAssertEqual(controller.window?.title, "gfm.md")
        XCTAssertEqual(controller.currentURL, fixtureURL("gfm"))
        XCTAssertTrue(controller.isWatching, "Should still be watching after switching files")
    }

    func testWindowIsResizable() {
        let controller = PreviewWindowController()
        XCTAssertTrue(controller.window!.styleMask.contains(.resizable))
        XCTAssertTrue(controller.window!.styleMask.contains(.closable))
        XCTAssertTrue(controller.window!.styleMask.contains(.miniaturizable))
    }

    private func fixtureURL(_ name: String) -> URL {
        Bundle(for: type(of: self)).url(forResource: name, withExtension: "md", subdirectory: "Fixtures")
            ?? URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("\(name).md")
    }
}
