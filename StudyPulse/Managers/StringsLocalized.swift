//
//  Localized.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/5.
//

import Foundation

extension String {
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}
