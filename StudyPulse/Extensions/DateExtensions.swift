//
//  DateExtensions.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import Foundation

extension Date {
    func formatted(date style: DateFormatter.Style, time style2: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style2
        return formatter.string(from: self)
    }
}
