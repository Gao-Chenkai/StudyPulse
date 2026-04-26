//
//  SubjectInfo.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/25.
//

import Foundation
import Combine

class SubjectInfo: ObservableObject {
    func getMaxScore (level: String, subject: String) -> Double {
        if level == "Middle School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 120.0
            } else if subject == "Science" {
                return 160.0
            } else {
                return 100.0
            }
        } else if level == "High School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 150.0
            } else {
                return 100.0
            }
        } else if level == "Primary School" {
            return 100.0
        }
        return 100.0
    }
}

