//
//  BackGroundColors.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/4/29.
//

import SwiftUI

func getBackgroundColor(_ colorScheme: ColorScheme) -> Color {
    if colorScheme == .light {
        return Color(.systemGray6)
    } else {
        return Color(.systemBackground)
    }
}
