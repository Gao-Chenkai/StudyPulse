//
//  SubjectInfo.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/25.
//

import Foundation
import Combine

class SubjectInfo: ObservableObject {
    func getMaxScore (level: String, subject: String) -> Int {
        if level == "Middle School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 120
            } else if subject == "PE & Health"{
                    return 30
            } else if subject == "GROUP: Chinese, Maths, English"{
                return 360
            } else if subject == "GROUP: Main Subjects" {
                return 660
            } else if subject == "GROUP: Elective Subjects" {
                return 300
            } else if subject == "Science" {
                return 160
            } else {
                return 1000
            }
        } else if level == "High School" {
            if subject == "Chinese" || subject == "Mathematics" || subject == "English" {
                return 150
            } else if subject == "PE & Health"{
                    return 30
            } else if subject == "GROUP: Chinese, Maths, English"{
                return 450
            } else if subject == "GROUP: Main Subjects" {
                return 750
            } else if subject == "GROUP: Elective Subjects" {
                return 300
            } else {
                return 1200
            }
        } else if level == "Primary School" {
            if subject == "GROUP: Chinese, Maths, English"{
                return 300
            } else {
                return 100
            }
        }
        return 100
    }
}
