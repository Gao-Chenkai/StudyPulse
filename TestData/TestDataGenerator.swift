//
//  TestDataGenerator.swift
//  StudyPulse
//
//   - 
//  Created on 2026-06-07
//

import Foundation

struct TestDataGenerator {
    
    // MARK: - 
    
    static let subjectNames = [
        "chinese": [""],
        "math": [""],
        "english": [""],
        "physics": [""],
        "chemistry": [""],
        "biology": [""],
        "history": [""],
        "geography": [""],
        "politics": [""],
        "music": [""],
        "art": [""],
        "sports": [""],
        "economics": [""],
        "computer_science": [""]
    ]
    
    static let examNames = [
        "", "", "", "", "",
        "", "", "", "", "",
        "", "Quiz 1", "Mid-Term Test", "End-of-Year Exam",
        "Mock Exam", "Final Review", "Practice Test", "Quarterly Exam",
        "Pre-Mock Exam", "Mock Exam 2", "Final Revision Quiz", "Weekly Test"
    ]
    
    static let mistakeTitles = [
        "", "", "",
        "", "",
        "", "", "",
        "", "",
        "", "",
        "",
        "", "",
        "", "",
        "", "",
        ""
    ]
    
    static let errorReasons = [
        "", "", "", "", "",
        "", "", "", "",
        "", "", "", "",
        "",
        "", "",
        "",
        "",
        ""
    ]
    
    static let correctSolutions = [
        "",
        "",
        ": 1. 2. 3. 4.",
        "",
        "",
        "",
        "",
        "",
        ""
    ]
    
    static let wrongSolutions = [
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        ""
    ]
    
    static let originalQuestionPrefixes = [
        "\n",
        "\n",
        "\n",
        "\n"
    ]
    
    // MARK: - 
    static func generateGrades(count: Int = 150) -> String {
        var grades: [String] = []
        
        let now = Date()
        let calendar = Calendar.current
        
        for _ in 0..<count {
            //  2 
            let randomDays = Int.random(in: 1...730)
            let date = calendar.date(byAdding: .day, value: -randomDays, to: now)!
            
            // 
            let subjects = ["chinese", "math", "english", "physics", "chemistry", "biology", "history", "geography", "politics"]
            let subjectKey = subjects.randomElement()!
            let subject = subjectNames[subjectKey]!.first!
            
            // 
            let subjectFullScore = [100, 120, 150].randomElement()!
            
            //  75 
            var scoreValue: Double
            let randomValue = Double.random(in: 0...1)
            if randomValue < 0.1 {
                scoreValue = Double.random(in: 40...60) * (Double(subjectFullScore) / 100)
            } else if randomValue < 0.7 {
                scoreValue = Double.random(in: 65...90) * (Double(subjectFullScore) / 100)
            } else {
                scoreValue = Double.random(in: 85...100) * (Double(subjectFullScore) / 100)
            }
            
            let score = min(max(scoreValue, 0), Double(subjectFullScore))
            
            // 
            let rawScore: Double? = Bool.random() ? Double.random(in: 40...100) * (Double(subjectFullScore) / 100) : nil
            
            // 
            let ranking = Int.random(in: 1...60)
            
            // 
            let importance = Int.random(in: 1...5)
            
            // 
            let examName = examNames.randomElement()!
            
            // 
            let scoreRate = (score / Double(subjectFullScore)) * 100
            
            //  CSV 
            let gradeLine = "\(UUID().uuidString),\(subjectKey),\(String(format: "%.1f", score)),\(subjectFullScore),\(String(format: "%.1f", scoreRate)),\(rawScore != nil ? String(format: "%.1f", rawScore!) : ""),\(ranking),\(importance),\(examName),\(formatDate(date))\n"
            grades.append(gradeLine)
        }
        
        return "ID,Subject,Score,FullScore,ScoreRate,RawScore,Ranking,Importance,ExamName,Date\n" + grades.joined()
    }
    
    // MARK: - 错题
    static func generateMistakes(count: Int = 80) -> String {
        // 13 列:与 DataExportManager.mistakesHeader 完全对齐
        // ID, Title, Subject, OriginalQuestion, Source,
        // Date, ErrorReason, WrongSolution, CorrectSolution, SRSEnabled,
        // ExposureCount, MasteryScore, MasteryHistory
        var mistakes: [String] = []

        let now = Date()
        let calendar = Calendar.current

        for _ in 0..<count {
            let days = Int.random(in: 1...365)
            let date = calendar.date(byAdding: .day, value: -days, to: now)!

            let subjects = ["math", "chinese", "english", "physics", "chemistry", "biology", "history", "geography", "politics"]
            let subjectKey = subjects.randomElement()!

            let title = mistakeTitles.randomElement()!
            let prefix = originalQuestionPrefixes.randomElement()!
            let originalQuestion = prefix + title + "\n\n"
            let source = "" + examNames.randomElement()!
            let errorReason = errorReasons.randomElement()!
            let wrongSolution = wrongSolutions.randomElement()!
            let correctSolution = correctSolutions.randomElement()!
            // SM-2 SRS 开关:测试数据全部开启
            let srsEnabled = true
            // 新增 v2.0+ 字段:曝光次数 / 掌握度 / 掌握度历史
            let exposureCount = Int.random(in: 0...8)
            let masteryScore = Double.random(in: 0.0...0.95)
            // 掌握度历史:空 JSON 数组(测试数据保持空,真实复习时由 EMA 算法填充)
            let masteryHistory = "[]"

            let mistakeLine = "\(UUID().uuidString),\(escapeCSV(title)),\(subjectKey),\(escapeCSV(originalQuestion)),\(escapeCSV(source)),\(formatDate(date)),\(escapeCSV(errorReason)),\(escapeCSV(wrongSolution)),\(escapeCSV(correctSolution)),\(srsEnabled),\(exposureCount),\(String(format: "%.4f", masteryScore)),\(masteryHistory)\n"
            mistakes.append(mistakeLine)
        }

        return "ID,Title,Subject,OriginalQuestion,Source,Date,ErrorReason,WrongSolution,CorrectSolution,SRSEnabled,ExposureCount,MasteryScore,MasteryHistory\n" + mistakes.joined()
    }

    // MARK: - 考试
    static func generateExams(count: Int = 40) -> (single: String, comprehensive: String) {
        // 8 列:与 DataExportManager.examsHeader 完全对齐
        // ID, Name, Subject, Date, ExamEndDate, Importance, Mastery, Type
        var singleExams: [String] = []
        var comprehensiveExams: [String] = []

        let now = Date()
        let calendar = Calendar.current

        let subjects = ["chinese", "math", "english", "physics", "chemistry", "biology", "history", "geography", "politics", "computer_science"]

        for _ in 0..<count {
            let futureDays = Int.random(in: 1...180)
            let date = calendar.date(byAdding: .day, value: futureDays, to: now)!

            let subjectKey = subjects.randomElement()!
            let examName = examNames.randomElement()!
            let importance = Int.random(in: 1...5)
            let mastery = Int.random(in: 0...100)
            // 80% 概率不设结束日期(= 单日考试);20% 设为开始日期后 1-3 天(= 多日考试)
            let examEndDate: String
            if Int.random(in: 0..<100) < 20 {
                let offset = Int.random(in: 1...3)
                let endDate = calendar.date(byAdding: .day, value: offset, to: date)!
                examEndDate = formatDate(endDate)
            } else {
                examEndDate = ""
            }

            let examLine = "\(UUID().uuidString),\(escapeCSV(examName)),\(subjectKey),\(formatDate(date)),\(examEndDate),\(importance),\(mastery),single\n"
            singleExams.append(examLine)
        }

        // 综合考试
        for _ in 0..<10 {
            let futureDays = Int.random(in: 7...365)
            let date = calendar.date(byAdding: .day, value: futureDays, to: now)!

            let subjectCount = Int.random(in: 3...6)
            let selectedSubjects = Array(subjects.shuffled().prefix(subjectCount))
            let subjectList = selectedSubjects.joined(separator: ";")

            let compExamNames = ["", "", "", "Final Exam", "Mid-Year Exam", "Mock Exam", "", ""]
            let examName = compExamNames.randomElement()!
            let importance = Int.random(in: 3...5)
            let mastery = Int.random(in: 20...80)
            // 综合考试通常 2-3 天
            let offset = Int.random(in: 1...2)
            let endDate = calendar.date(byAdding: .day, value: offset, to: date)!
            let examEndDate = formatDate(endDate)

            let examLine = "\(UUID().uuidString),\(escapeCSV(examName)),\(subjectList),\(formatDate(date)),\(examEndDate),\(importance),\(mastery),comprehensive\n"
            comprehensiveExams.append(examLine)
        }

        let singleHeader = "ID,Name,Subject,Date,ExamEndDate,Importance,Mastery,Type\n"
        let compHeader = "ID,Name,Subject,Date,ExamEndDate,Importance,Mastery,Type\n"

        return (singleHeader + singleExams.joined(), compHeader + comprehensiveExams.joined())
    }
    
    // MARK: - Helper
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}
