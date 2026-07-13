//
//  AppleIntelligenceGradient.swift
//  StudyPulse
//
//  Apple Intelligence 渐变色 / Apple Intelligence gradient colors.
//  粉 → 紫 → 蓝,横向线性渐变。/ Pink → purple → blue, horizontal linear gradient.
//

import SwiftUI

/// Apple Intelligence 标志三色锚点(供其他视图复用)。
/// Three Apple Intelligence brand colors (for reuse across views).
enum AppleIntelligenceColor {
    static let start = Color(red: 1.0, green: 0.215, blue: 0.373)  // 粉红 #FF375F / Pink #FF375F.
    static let middle = Color(red: 0.749, green: 0.353, blue: 0.949)  // 紫色 #BF5AF2 / Purple #BF5AF2.
    static let end = Color(red: 0.369, green: 0.361, blue: 0.902)  // 靛蓝 #5E5CE6 / Indigo #5E5CE6.
}

private struct AppleIntelligenceForegroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(
            LinearGradient(
                colors: [
                    AppleIntelligenceColor.start,
                    AppleIntelligenceColor.middle,
                    AppleIntelligenceColor.end
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

extension View {
    /// 把 View 前景色替换为 Apple Intelligence 渐变 / Replaces foreground with the Apple Intelligence gradient.
    func appleIntelligenceForeground() -> some View {
        modifier(AppleIntelligenceForegroundModifier())
    }
}
