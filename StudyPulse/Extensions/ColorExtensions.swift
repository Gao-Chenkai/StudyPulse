//
//  ColorExtensions.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

extension Color {
    // MARK: - System Color Shortcuts / 系统色快捷方式
    /// 系统背景色 / Shortcut for `UIColor.systemBackground`.
    static let systemBackground = Color(UIColor.systemBackground)
    /// 次级系统背景色 / Shortcut for `UIColor.secondarySystemBackground`.
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    /// 系统灰 6 背景 / Shortcut for `UIColor.systemGray6`.
    static let systemGray6 = Color(UIColor.systemGray6)

    /// 6/8 位 hex(可带 `#`)→ Color;格式错误回退中性灰。
    /// 6/8-digit hex (optional `#`) → `Color`; bad input → neutral gray.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((int & 0xFF0000) >> 16) / 255.0  // 6 位 RGB / 6-digit RGB.
            g = Double((int & 0x00FF00) >> 8) / 255.0
            b = Double(int & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((int & 0xFF000000) >> 24) / 255.0  // 8 位 RGBA / 8-digit RGBA.
            g = Double((int & 0x00FF0000) >> 16) / 255.0
            b = Double((int & 0x0000FF00) >> 8) / 255.0
            a = Double(int & 0x000000FF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1.0  // 容错 / Bad input.
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
