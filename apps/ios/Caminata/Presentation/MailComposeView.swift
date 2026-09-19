import MessageUI
import SwiftUI

/// The system mail composer, so the app never needs a mail server or credentials.
struct MailComposeView: UIViewControllerRepresentable {
    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    let subject: String
    let body: String
    let attachments: [Attachment]
    let onFinish: () -> Void

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        for attachment in attachments {
            controller.addAttachmentData(
                attachment.data,
                mimeType: attachment.mimeType,
                fileName: attachment.fileName
            )
        }
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }
}

extension MailComposeView.Attachment {
    static func from(url: URL) -> MailComposeView.Attachment? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mimeType = url.pathExtension.lowercased() == "png"
            ? "image/png"
            : "application/gpx+xml"
        return MailComposeView.Attachment(
            data: data,
            mimeType: mimeType,
            fileName: url.lastPathComponent
        )
    }
}
