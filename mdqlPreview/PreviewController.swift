import Cocoa
import QuickLookUI
import Quartz

class PreviewController: NSViewController, QLPreviewingController {

    override func loadView() {
        self.view = NSView()
    }

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let html = try MarkdownRenderer.render(fileAt: fileURL)
        let data = Data(html.utf8)

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 1060, height: 900)
        ) { _ in
            return data
        }
        return reply
    }
}
