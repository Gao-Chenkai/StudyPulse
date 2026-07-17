//
//  ReportShareSheet.swift
//  StudyPulse
//
//  UIActivityViewController wrapper, used to share the rendered
//  report image via the standard share sheet (WeChat, Mail, Save to
//  Photos, AirDrop, etc).
//
//  iPad 行为:UIActivityViewController 在 iPad 上以 popover 弹出,
//  必须设置 popoverPresentationController.sourceView + sourceRect,
//  否则会触发 NSGenericException 立即崩溃。这里在没有传 sourceView
//  时回退到 key window 的根视图,保证两端都安全。
//
//  subject 设置:用 UIActivityItemSource 协议实现(系统推荐),
//  避免 setValue(_:forKey:"subject") 私有 KVC 在新 iOS 上被拒。
//

import SwiftUI
import UIKit

/// UIActivityItemSource 适配器,用于给 Mail 等 Activity 设置主题。
/// 同时把 image 作为 placeholder / subject 邮件附件,跨 iOS 版本稳定。
/// UIActivityItemSource adapter that supplies a `subject` (used by Mail,
/// Messages, etc.) and a fallback display text. Officially supported API
/// — replaces the previous `setValue(_:forKey:"subject")` KVC hack which
/// is silently ignored by MailActivity on recent iOS releases.
private final class ReportActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let subject: String?

    init(image: UIImage, subject: String?) {
        self.image = image
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        subject ?? ""
    }
}

struct ReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var subject: String?
    var sourceView: UIView?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // 把 image + subject 包成 UIActivityItemSource(系统支持,稳定)
        // 并把额外 raw items 一起作为 activityItems(让用户能分享附加信息)
        let activityItems: [Any] = items.map { item in
            if let image = item as? UIImage, subject != nil {
                return ReportActivityItemSource(image: image, subject: subject)
            }
            return item
        }

        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // iPad:必须给 popoverPresentationController 配 sourceView,否则崩溃。
        // iPad: UIActivityViewController is presented as a popover and needs an
        // anchor view, otherwise iOS throws NSGenericException.
        if let popover = controller.popoverPresentationController {
            let anchor: UIView? = sourceView ?? Self.firstKeyWindowRootView()
            if let anchor {
                popover.sourceView = anchor
                popover.sourceRect = CGRect(
                    x: anchor.bounds.midX,
                    y: anchor.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = [.any]
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }

    // MARK: - iPad 兜底:从 key window 找 anchor 视图

    /// 取当前活跃的 key window 的根视图,作为 iPad popover 的兜底 anchor。
    /// 在 sheet 全屏弹出场景下也能稳定拿到一个有效的 UIView。
    /// Fallback anchor for iPad popovers: the active key window's root view.
    private static func firstKeyWindowRootView() -> UIView? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        return window?.rootViewController?.view
    }
}
