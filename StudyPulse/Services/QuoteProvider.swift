//
//  QuoteProvider.swift
//  StudyPulse
//
//  每日励志语录的纯函数(基于日期索引)。
// 之前是 HomeView.swift 顶部的全局变量,此处集中。
//
//  Created for MVVM refactor (2026-07-05).
//

import Foundation

/// 每日励志语录。基于"dayOfYear % count"轮换,跨年自动重置。
enum QuoteProvider {

    /// 14 句励志语录(本地化 key 占位)
    static let all: [String] = [
        "Quote 1".localized(),
        "Quote 2".localized(),
        "Quote 3".localized(),
        "Quote 4".localized(),
        "Quote 5".localized(),
        "Quote 6".localized(),
        "Quote 7".localized(),
        "Quote 8".localized(),
        "Quote 9".localized(),
        "Quote 10".localized(),
        "Quote 11".localized(),
        "Quote 12".localized(),
        "Quote 13".localized(),
        "Quote 14".localized(),
    ]

    /// 今日语录(基于传入日期,默认今天)
    static func dailyQuote(for date: Date = Date()) -> String {
        guard !all.isEmpty else { return "" }
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        let index = dayOfYear % all.count
        return all[index]
    }
}
