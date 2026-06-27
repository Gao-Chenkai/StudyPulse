//
//  ReportShareSheet.swift
//  StudyPulse
//
//  UIActivityViewController wrapper, used to share the rendered
//  report image via the standard share sheet (WeChat, Mail, Save to
//  Photos, AirDrop, etc).
//

import SwiftUI
import UIKit

struct ReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var subject: String?
    var sourceView: UIView?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let subject {
            controller.setValue(subject, forKey: "subject")
        }
        // iPad：必须设置 anchor，否则会 crash。
        if let popover = controller.popoverPresentationController, let sourceView {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
            popover.permittedArrowDirections = [.any]
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}
