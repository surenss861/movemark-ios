//
//  ReportPDFShareSheet.swift
//  movemork
//
//  Reliable PDF sharing with UTType metadata for AirDrop and Messages.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ReportPDFActivityItem: NSObject, UIActivityItemSource {
    let fileURL: URL
    let subject: String

    init(fileURL: URL, subject: String) {
        self.fileURL = fileURL
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        subject
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.pdf.identifier
    }
}

struct ReportPDFShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        configurePopover(for: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    private func configurePopover(for controller: UIActivityViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootView = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.view
        else {
            return
        }
        popover.sourceView = rootView
        popover.sourceRect = CGRect(
            x: rootView.bounds.midX,
            y: rootView.bounds.midY,
            width: 1,
            height: 1
        )
        popover.permittedArrowDirections = []
    }
}
