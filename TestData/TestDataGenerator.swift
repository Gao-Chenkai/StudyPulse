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
    
    // MARK: - 
    static func generateMistakes(count: Int = 80) -> String {
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
            
            let mistakeLine = "\(UUID().uuidString),\(escapeCSV(title)),\(subjectKey),\(escapeCSV(originalQuestion)),\(escapeCSV(source)),\(formatDate(date)),\(escapeCSV(errorReason)),\(escapeCSV(wrongSolution)),\(escapeCSV(correctSolution))\n"
            mistakes.append(mistakeLine)
        }
        
        return "ID,Title,Subject,OriginalQuestion,Source,Date,ErrorReason,WrongSolution,CorrectSolution\n" + mistakes.joined()
    }
    
    // MARK: - 
    static func generateExams(count: Int = 40) -> (single: String, comprehensive: String) {
        var singleExams: [String] = []
        var comprehensiveExams: [String] = []
        
        let now = Date()
        let calendar = Calendar.current
        
        // 
        let subjects = ["chinese", "math", "english", "physics", "chemistry", "biology", "history", "geography", "politics", "computer_science"]
        
        for _ in 0..<count {
            let futureDays = Int.random(in: 1...180)
            let date = calendar.date(byAdding: .day, value: futureDays, to: now)!
            
            let subjectKey = subjects.randomElement()!
            let examName = examNames.randomElement()!
            let importance = Int.random(in: 1...5)
            let mastery = Int.random(in: 0...100)
            
            let examLine = "\(UUID().uuidString),\(escapeCSV(examName)),\(subjectKey),\(formatDate(date)),\(importance),\(mastery),\n"
            singleExams.append(examLine)
        }
        
        // 
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
            
            let examLine = "\(UUID().uuidString),\(escapeCSV(examName)),\(subjectList),\(formatDate(date)),\(importance),\(mastery),\n"
            comprehensiveExams.append(examLine)
        }
        
        let singleHeader = "ID,Name,Subject,Date,Importance,Mastery,Type\n"
        let compHeader = "ID,Name,Subjects,Date,Importance,Mastery,Type\n"
        
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
