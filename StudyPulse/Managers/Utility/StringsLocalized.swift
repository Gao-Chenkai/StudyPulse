//
//  Localized.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/5.
//
//  本地化便捷扩展:为 String 提供 `.localized()` 入口。
//  Localization convenience: adds `.localized()` to String.
//

import Foundation

extension String {
    /// 便捷本地化:等价于 `NSLocalizedString(self, comment: "")`。
    /// Shortcut for `NSLocalizedString(self, comment: "")`.
    nonisolated func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}
