//
//  AppleIntelligenceGradient.swift
//  StudyPulse
//
//  Apple Intelligence 渐变色：粉 (#FF375F) → 紫 (#BF5AF2) → 蓝 (#5E5CE6)，
//  对应 iOS 26 Apple Intelligence 标志的横向线性渐变。
//  提供 .appleIntelligenceForeground() modifier 给 Text / Image 等 View 使用。
//

import SwiftUI

/// Apple Intelligence 标志三色锚点（公开为静态属性，方便其他视图引用）。
enum AppleIntelligenceColor {
    /// 粉红 #FF375F
    static let start = Color(red: 1.0, green: 0.215, blue: 0.373)
    /// 紫色 #BF5AF2
    static let middle = Color(red: 0.749, green: 0.353, blue: 0.949)
    /// 靛蓝 #5E5CE6
    static let end = Color(red: 0.369, green: 0.361, blue: 0.902)
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
    /// 把 View 前景色（Text / Image 等）替换为 Apple Intelligence 渐变。
    func appleIntelligenceForeground() -> some View {
        modifier(AppleIntelligenceForegroundModifier())
    }
}
