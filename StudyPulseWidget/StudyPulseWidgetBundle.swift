//
//  StudyPulseWidgetBundle.swift
//  StudyPulseWidget
//
//  Created by Chenkai Gao on 2026/6/21.
//

import WidgetKit
import SwiftUI
import ActivityKit

@main
struct StudyPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        ExamWidget()
        TrendWidget()
        HRVWidget()
        StudyTimerLiveActivity()
    }
}
