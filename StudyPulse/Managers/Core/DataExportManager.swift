//
//  DataExportManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/7.
//

import Foundation
import os

///  CSV 
@MainActor
enum DataExportManager {
    
    ///  CSV
    static func exportGradesToCSV(grades: [Grade], subjects: [Subject]) -> String {
        var csv = "ID,,,,,,,,,\n"
        
        for grade in grades {
            let subjectFullScore = subjects.first(where: { $0.name == grade.subject })?.fullScore ?? 100
            let fullScore = grade.fullScore ?? subjectFullScore
            let scoreRate = grade.scoreRate(subjectFullScore: subjectFullScore)
            
            let id = grade.id.uuidString
            let subject = escapeCSV(grade.subject)
            let score = String(format: "%.1f", grade.score)
            let fs = String(format: "%.1f", fullScore)
            let rate = String(format: "%.1f%%", scoreRate * 100)
            let rawScore = grade.rawScore.map { String(format: "%.1f", $0) } ?? ""
            let ranking = grade.ranking.map { String($0) } ?? ""
            let importance = String(grade.importance)
            let examName = escapeCSV(grade.examName)
            let date = formatDate(grade.date)
            
            csv += "\(id),\(subject),\(score),\(fs),\(rate),\(rawScore),\(ranking),\(importance),\(examName),\(date)\n"
        }
        
        return csv
    }
    
    ///  CSV
    static func exportMistakesToCSV(mistakes: [MistakeNote]) -> String {
        var csv = "ID,,,,,,,,\n"
        
        for mistake in mistakes {
            let id = mistake.id.uuidString
            let title = escapeCSV(mistake.title)
            let subject = escapeCSV(mistake.subject)
            let question = escapeCSV(mistake.originalQuestion)
            let source = escapeCSV(mistake.source)
            let date = formatDate(mistake.date)
            let reason = escapeCSV(mistake.errorReason)
            let wrongSol = escapeCSV(mistake.wrongSolution)
            let correctSol = escapeCSV(mistake.correctSolution)
            
            csv += "\(id),\(title),\(subject),\(question),\(source),\(date),\(reason),\(wrongSol),\(correctSol)\n"
        }
        
        return csv
    }
    
    ///  CSV
    static func exportExamsToCSV(exams: [Exam], comprehensiveExams: [comprehensiveExam]) -> String {
        var csv = "ID,,,,,,\n"
        
        // 
        for exam in exams {
            let id = exam.id.uuidString
            let name = escapeCSV(exam.name)
            let subject = escapeCSV(exam.subject)
            let date = formatDate(exam.examDate)
            let importance = String(exam.importance)
            let mastery = String(exam.masteryDegree)
            let type = ""
            
            csv += "\(id),\(name),\(subject),\(date),\(importance),\(mastery),\(type)\n"
        }
        
        // 
        for exam in comprehensiveExams {
            let id = exam.id.uuidString
            let name = escapeCSV(exam.name)
            let subject = escapeCSV(exam.subject.joined(separator: ";"))
            let date = formatDate(exam.examDate)
            let importance = String(exam.importance)
            let mastery = String(exam.masteryDegree)
            let type = ""
            
            csv += "\(id),\(name),\(subject),\(date),\(importance),\(mastery),\(type)\n"
        }
        
        return csv
    }
    
    // MARK: - CSV 
    
    ///  CSV 
    static func parseGrades(from csvString: String, subjects: [Subject]) -> [Grade] {
        var grades: [Grade] = []
        
        // 
        let rows = parseCSVRows(csvString)
        
        // 
        guard rows.count > 1 else { return [] }
        
        for row in rows.dropFirst() {
            // 
            if let grade = parseGradeLine(from: row, subjects: subjects) {
                grades.append(grade)
            }
        }
        
        return grades
    }
    
    ///  CSV / Parse mistakes from a CSV string
    static func parseMistakes(from csvString: String) -> [MistakeNote] {
        var mistakes: [MistakeNote] = []

        //  BOM / Strip UTF-8 BOM
        var cleanedString = csvString
        if csvString.hasPrefix("\u{FEFF}") {
            cleanedString = String(csvString.dropFirst())
        }

        //  / Parse rows
        let rows = parseCSVRows(cleanedString)

        Log.export.info("开始解析错题 CSV / Parsing mistakes CSV: rowCount=\(rows.count, privacy: .public)")
        if rows.count > 0 {
            Log.export.debug("CSV 表头 / CSV header: \(rows[0], privacy: .public)")
        }

        //  / Need header + at least one data row
        guard rows.count > 1 else {
            Log.export.warning("CSV 缺少数据行 / CSV has no data rows")
            return []
        }

        for (index, row) in rows.dropFirst().enumerated() {
            Log.export.debug("解析第 \(index + 1, privacy: .public) 行 / Parsing row \(index + 1, privacy: .public): fields=\(row.count, privacy: .public)")
            if let mistake = parseMistakeLine(from: row) {
                mistakes.append(mistake)
                Log.export.debug("解析成功 / Parsed mistake: title=\(mistake.title, privacy: .public)")
            } else {
                Log.export.error("解析失败：字段数量异常 / Parse failed: unexpected field count=\(row.count, privacy: .public), expected 9")
            }
        }

        Log.export.info("错题 CSV 解析完成 / Finished parsing mistakes: success=\(mistakes.count, privacy: .public)")
        return mistakes
    }
    
    ///  CSV 
    static func parseExams(from csvString: String) -> (single: [Exam], comprehensive: [comprehensiveExam]) {
        var singleExams: [Exam] = []
        var comprehensiveExams: [comprehensiveExam] = []
        
        // 
        let rows = parseCSVRows(csvString)
        
        // 
        guard rows.count > 1 else { return ([], []) }
        
        for row in rows.dropFirst() {
            let (_, data) = parseExamLine(from: row)
            if let single = data as? Exam {
                singleExams.append(single)
            } else if let comprehensive = data as? comprehensiveExam {
                comprehensiveExams.append(comprehensive)
            }
        }
        
        return (singleExams, comprehensiveExams)
    }
    
    ///  CSV
    private static func parseCSVRows(_ csvString: String) -> [[String]] {
        var rows: [[String]] = []
        var cleanedString = csvString
        
        //  BOM 
        if cleanedString.hasPrefix("\u{FEFF}") {
            cleanedString = String(cleanedString.dropFirst())
        }
        
        //  \r\n  \r  \n
        let normalized = cleanedString
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        // 
        let lines = normalized.components(separatedBy: "\n")
        
        for line in lines {
            // 
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                continue
            }
            
            // CSV
            let fields = trimmedLine.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if !fields.isEmpty {
                rows.append(fields)
            }
        }
        
        return rows
    }
    
    ///  CSV
    private static func parseGradeLine(from fields: [String], subjects: [Subject]) -> Grade? {
        guard fields.count >= 10 else { return nil }
        
        // 
        let subjectName = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let score = Double(fields[2].trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let fullScore = Double(fields[3].trimmingCharacters(in: .whitespacesAndNewlines))
        let rawScore = Double(fields[5].trimmingCharacters(in: .whitespacesAndNewlines))
        let ranking = Int(fields[6].trimmingCharacters(in: .whitespacesAndNewlines))
        let importance = Int(fields[7].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        let examName = fields[8].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[9].trimmingCharacters(in: .whitespacesAndNewlines))
        
        //  Grade 
        return Grade(
            subject: subjectName,
            score: score,
            rawScore: rawScore,
            ranking: ranking,
            importance: importance,
            image: nil,
            imageFileName: nil,
            date: date,
            examName: examName,
            fullScore: fullScore
        )
    }
    
    ///  CSV
    private static func parseMistakeLine(from fields: [String]) -> MistakeNote? {
        guard fields.count >= 9 else { return nil }
        
        // 
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let originalQuestion = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let source = fields[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[5].trimmingCharacters(in: .whitespacesAndNewlines))
        let errorReason = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        let wrongSolution = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)
        let correctSolution = fields[8].trimmingCharacters(in: .whitespacesAndNewlines)
        
        //  MistakeNote 
        return MistakeNote(
            title: title,
            subject: subject,
            originalQuestion: originalQuestion,
            source: source,
            date: date,
            errorReason: errorReason,
            wrongSolution: wrongSolution,
            correctSolution: correctSolution
        )
    }
    
    ///  CSV
    private static func parseExamLine(from fields: [String]) -> (type: String, data: Any?) {
        guard fields.count >= 7 else { return ("", nil) }
        
        // 
        let name = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectStr = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[3].trimmingCharacters(in: .whitespacesAndNewlines))
        let importance = Int(fields[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        let mastery = Int(fields[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let type = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        
        if type == "" {
            // 
            let exam = Exam(
                name: name,
                date: date,
                importance: importance,
                subject: subjectStr,
                examName: name,
                masteryDegree: mastery
            )
            return ("single", exam)
        } else if type == "" {
            // 
            let subjects = subjectStr.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let exam = comprehensiveExam(
                name: name,
                date: date,
                importance: importance,
                subject: subjects,
                examName: name,
                masteryDegree: mastery
            )
            return ("comprehensive", exam)
        }
        
        return ("", nil)
    }
    
    // MARK:  - 
    ///  CSV
    private static func parseGradeLine(_ line: String, subjects: [Subject]) -> Grade? {
        let fields = parseCSVLine(line)
        return parseGradeLine(from: fields, subjects: subjects)
    }
    
    ///  CSV
    private static func parseMistakeLine(_ line: String) -> MistakeNote? {
        let fields = parseCSVLine(line)
        return parseMistakeLine(from: fields)
    }
    
    ///  CSV
    private static func parseExamLine(_ line: String) -> (type: String, data: Any?) {
        let fields = parseCSVLine(line)
        return parseExamLine(from: fields)
    }
    
    ///  CSV 
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    // 
                    currentField.append("\"")
                    i = line.index(after: i)
                } else {
                    // 
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                // 
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            i = line.index(after: i)
        }
        
        // 
        result.append(currentField)
        return result
    }
    
    /// 
    private static func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 
        return Date()
    }
    
    // MARK: - Helper
    
    ///  CSV 
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
    
    /// 
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
