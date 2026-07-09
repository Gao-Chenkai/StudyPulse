//
//  ColorExtensions.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let systemGray6 = Color(UIColor.systemGray6)

    /// 6/8 位 hex 字符串(可带 `#` 前缀)→ Color
    /// - Example: `Color(hex: "8B5CF6")` or `Color(hex: "#8B5CF6FF")`
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((int & 0xFF0000) >> 16) / 255.0
            g = Double((int & 0x00FF00) >> 8) / 255.0
            b = Double(int & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((int & 0xFF000000) >> 24) / 255.0
            g = Double((int & 0x00FF0000) >> 16) / 255.0
            b = Double((int & 0x0000FF00) >> 8) / 255.0
            a = Double(int & 0x000000FF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5; a = 1.0
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
