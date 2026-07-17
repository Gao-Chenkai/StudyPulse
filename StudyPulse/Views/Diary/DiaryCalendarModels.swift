//
//  DiaryCalendarModels.swift
//  StudyPulse
//
//  日记日历的调色板与数据辅助:
//  - DiaryCalendarPalette:mood 1-5 → 颜色映射(选中/未选中两档)
//  - DiaryEntry 扩展:dayEntries 按日历日分组
//
//  Color palette + small data helpers for the diary calendar.
//

import SwiftUI

/// 学习日记 mood 颜色调色板
/// Color palette keyed by `DiaryEntry.moodScore` (1-5).
enum DiaryCalendarPalette {
    /// 选中态填充色
    /// Fill color when the day is selected.
    static func color(forMood score: Int) -> Color {
        // 红(1) → 橙(2) → 黄(3) → 绿(4) → 深绿(5)
        // red (1) → orange (2) → yellow (3) → green (4) → deep green (5)
        switch max(1, min(5, score)) {
        case 1: return Color(red: 1.00, green: 0.40, blue: 0.40)
        case 2: return Color(red: 1.00, green: 0.65, blue: 0.30)
        case 3: return Color(red: 1.00, green: 0.85, blue: 0.30)
        case 4: return Color(red: 0.45, green: 0.80, blue: 0.45)
        default: return Color(red: 0.25, green: 0.65, blue: 0.45)
        }
    }
}
