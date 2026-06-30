//
//  DataExportManager.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/7.
//
//  CSV 导入/导出：
//  - 导出成绩 / 错题 / 考试（含综合考试）/ 任务（作业 + 阅读材料）到 RFC 4180 兼容的 CSV
//  - 解析时统一走支持引号转义的 parseCSVRows，能处理字段内含逗号 / 引号 / 换行
//  - 考试 type 列：single / comprehensive（同时兼容旧的中文"单科" / "综合"）
//  - 任务 type 列：homework / reading（同时兼容中文"作业" / "阅读"）
//

import Foundation
import os

/// CSV 导入导出
@MainActor
enum DataExportManager {

    // MARK: - Headers

    /// 成绩 CSV 表头
    static let gradesHeader = [
        "ID", "Subject", "Score", "FullScore", "ScoreRate",
        "RawScore", "Ranking", "Importance", "ExamName", "Date"
    ]

    /// 错题 CSV 表头
    static let mistakesHeader = [
        "ID", "Title", "Subject", "OriginalQuestion", "Source",
        "Date", "ErrorReason", "WrongSolution", "CorrectSolution"
    ]

    /// 考试 CSV 表头
    static let examsHeader = [
        "ID", "Name", "Subject", "Date", "ExamEndDate", "Importance", "Mastery", "Type"
    ]

    /// 任务（作业 / 阅读材料）CSV 表头
    /// Task (homework / reading material) CSV header
    static let tasksHeader = [
        "ID", "Title", "Type", "Subject", "DueDate", "ReminderTime",
        "Importance", "Notes", "IsCompleted", "CreatedAt"
    ]

    // MARK: - Export

    /// 导出成绩到 CSV
    static func exportGradesToCSV(grades: [Grade], subjects: [Subject]) -> String {
        var csv = joinRow(gradesHeader)

        for grade in grades {
            let subjectFullScore = subjects.first(where: { $0.name == grade.subject })?.fullScore ?? 100
            let fullScore = grade.fullScore ?? subjectFullScore
            let scoreRate = grade.scoreRate(subjectFullScore: subjectFullScore)

            let row: [String] = [
                grade.id.uuidString,
                grade.subject,
                String(format: "%.1f", grade.score),
                String(format: "%.1f", fullScore),
                String(format: "%.1f%%", scoreRate * 100),
                grade.rawScore.map { String(format: "%.1f", $0) } ?? "",
                grade.ranking.map { String($0) } ?? "",
                String(grade.importance),
                grade.examName,
                formatDate(grade.date)
            ]
            csv += joinRow(row)
        }

        return csv
    }

    /// 导出错题到 CSV
    static func exportMistakesToCSV(mistakes: [MistakeNote]) -> String {
        var csv = joinRow(mistakesHeader)

        for mistake in mistakes {
            let row: [String] = [
                mistake.id.uuidString,
                mistake.title,
                mistake.subject,
                mistake.originalQuestion,
                mistake.source,
                formatDate(mistake.date),
                mistake.errorReason,
                mistake.wrongSolution,
                mistake.correctSolution
            ]
            csv += joinRow(row)
        }

        return csv
    }

    /// 导出考试（单科 + 综合）到 CSV
    /// Type 列：single / comprehensive
    static func exportExamsToCSV(exams: [Exam], comprehensiveExams: [comprehensiveExam]) -> String {
        var csv = joinRow(examsHeader)

        for exam in exams {
            let row: [String] = [
                exam.id.uuidString,
                exam.name,
                exam.subject,
                formatDate(exam.examDate),
                exam.examEndDate.map(formatDate) ?? "",
                String(exam.importance),
                String(exam.masteryDegree),
                "single"
            ]
            csv += joinRow(row)
        }

        for exam in comprehensiveExams {
            let row: [String] = [
                exam.id.uuidString,
                exam.name,
                exam.subject.joined(separator: ";"),
                formatDate(exam.examDate),
                exam.examEndDate.map(formatDate) ?? "",
                String(exam.importance),
                String(exam.masteryDegree),
                "comprehensive"
            ]
            csv += joinRow(row)
        }

        return csv
    }

    /// 导出任务（作业 + 阅读材料）到 CSV
    /// Type 列：homework / reading
    /// Export tasks (homework + reading) to CSV.
    /// - Parameter tasks: 任务列表（不再按类型拆分；同一文件内通过 Type 列区分）
    ///   The list of tasks. Single / reading are mixed; the `Type` column tells them apart.
    static func exportTasksToCSV(tasks: [TaskItem]) -> String {
        var csv = joinRow(tasksHeader)

        for task in tasks {
            let row: [String] = [
                task.id.uuidString,
                task.title,
                task.type.rawValue,
                task.subject,
                formatDate(task.dueDate),
                formatDate(task.reminderDate),
                String(task.importance),
                task.notes,
                task.isCompleted ? "true" : "false",
                formatDate(task.createdAt)
            ]
            csv += joinRow(row)
        }

        return csv
    }

    // MARK: - Import

    /// 从 CSV 解析成绩
    static func parseGrades(from csvString: String, subjects: [Subject]) -> [Grade] {
        let rows = parseCSVRows(csvString)
        guard rows.count > 1 else { return [] }

        var grades: [Grade] = []
        for row in rows.dropFirst() {
            if let grade = parseGradeRow(row, subjects: subjects) {
                grades.append(grade)
            }
        }
        return grades
    }

    /// 从 CSV 解析错题
    static func parseMistakes(from csvString: String) -> [MistakeNote] {
        let rows = parseCSVRows(csvString)
        Log.export.info("开始解析错题 CSV / Parsing mistakes CSV: rowCount=\(rows.count, privacy: .public)")
        guard rows.count > 1 else {
            Log.export.warning("CSV 缺少数据行 / CSV has no data rows")
            return []
        }

        var mistakes: [MistakeNote] = []
        for row in rows.dropFirst() {
            if let mistake = parseMistakeRow(row) {
                mistakes.append(mistake)
                Log.export.debug("解析成功 / Parsed mistake: title=\(mistake.title, privacy: .public)")
            } else {
                Log.export.error("解析失败：字段数量异常 / Parse failed: unexpected field count=\(row.count, privacy: .public), expected \(mistakesHeader.count)")
            }
        }
        Log.export.info("错题 CSV 解析完成 / Finished parsing mistakes: success=\(mistakes.count, privacy: .public)")
        return mistakes
    }

    /// 从 CSV 解析考试（单科 + 综合），根据 Type 列区分
    static func parseExams(from csvString: String) -> (single: [Exam], comprehensive: [comprehensiveExam]) {
        let rows = parseCSVRows(csvString)
        guard rows.count > 1 else { return ([], []) }

        var singleExams: [Exam] = []
        var comprehensiveExams: [comprehensiveExam] = []

        for row in rows.dropFirst() {
            switch parseExamRow(row) {
            case .single(let exam):
                singleExams.append(exam)
            case .comprehensive(let exam):
                comprehensiveExams.append(exam)
            case .invalid:
                continue
            }
        }

        return (singleExams, comprehensiveExams)
    }

    /// 从 CSV 解析任务（作业 + 阅读材料），根据 Type 列区分
    /// Parse tasks (homework + reading) from a CSV.
    /// - Returns: 解析得到的所有任务（成功解析的，失败行会被跳过）
    ///   All tasks that parsed successfully. Bad rows are silently skipped.
    static func parseTasks(from csvString: String) -> [TaskItem] {
        let rows = parseCSVRows(csvString)
        guard rows.count > 1 else { return [] }

        var tasks: [TaskItem] = []
        for row in rows.dropFirst() {
            if let task = parseTaskRow(row) {
                tasks.append(task)
            }
        }
        return tasks
    }

    // MARK: - Row Parsers (private)

    private static func parseGradeRow(_ fields: [String], subjects: [Subject]) -> Grade? {
        // 兼容旧版本（无 ScoreRate 列时也能解析）
        // 旧版列数 = 10（ID, Subject, Score, FullScore, ScoreRate, RawScore, Ranking, Importance, ExamName, Date）
        // 新版同旧版，列定义未变
        guard fields.count >= gradesHeader.count else { return nil }

        let subjectName = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let score = Double(fields[2].trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let fullScore = Double(fields[3].trimmingCharacters(in: .whitespacesAndNewlines))
        // fields[4] is ScoreRate — derived, not parsed
        let rawScore = Double(fields[5].trimmingCharacters(in: .whitespacesAndNewlines))
        let ranking = Int(fields[6].trimmingCharacters(in: .whitespacesAndNewlines))
        let importance = Int(fields[7].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3
        let examName = fields[8].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[9].trimmingCharacters(in: .whitespacesAndNewlines))

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

    private static func parseMistakeRow(_ fields: [String]) -> MistakeNote? {
        guard fields.count >= mistakesHeader.count else { return nil }

        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let originalQuestion = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let source = fields[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[5].trimmingCharacters(in: .whitespacesAndNewlines))
        let errorReason = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        let wrongSolution = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)
        let correctSolution = fields[8].trimmingCharacters(in: .whitespacesAndNewlines)

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

    private enum ParsedExam {
        case single(Exam)
        case comprehensive(comprehensiveExam)
        case invalid
    }

    private static func parseExamRow(_ fields: [String]) -> ParsedExam {
        // 新版 8 列：ID, Name, Subject, Date, ExamEndDate, Importance, Mastery, Type
        // 旧版 7 列：ID, Name, Subject, Date, Importance, Mastery, Type
        guard fields.count >= 7 else { return .invalid }

        let name = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectStr = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parseDate(fields[3].trimmingCharacters(in: .whitespacesAndNewlines))

        // 8 列格式带 examEndDate
        let examEndDate: Date?
        let importance: Int
        let mastery: Int
        let typeRaw: String
        if fields.count >= 8 {
            examEndDate = fields[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : parseDate(fields[4].trimmingCharacters(in: .whitespacesAndNewlines))
            importance = Int(fields[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            mastery = Int(fields[6].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            typeRaw = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // 兼容 7 列旧格式
            examEndDate = nil
            importance = Int(fields[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
            mastery = Int(fields[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            typeRaw = fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch normalizeExamType(typeRaw) {
        case .single:
            return .single(Exam(
                name: name,
                date: date,
                importance: importance,
                subject: subjectStr,
                examName: name,
                masteryDegree: mastery,
                examEndDate: examEndDate
            ))
        case .comprehensive:
            let subjects = subjectStr.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return .comprehensive(comprehensiveExam(
                name: name,
                date: date,
                importance: importance,
                subject: subjects,
                examName: name,
                masteryDegree: mastery,
                examEndDate: examEndDate
            ))
        case .unknown:
            return .invalid
        }
    }

    private enum ExamKind { case single, comprehensive, unknown }

    /// 兼容英文（single / comprehensive）和中文（单科 / 综合）
    private static func normalizeExamType(_ raw: String) -> ExamKind {
        let lower = raw.lowercased()
        if lower == "single" || lower == "单科" { return .single }
        if lower == "comprehensive" || lower == "综合" { return .comprehensive }
        return .unknown
    }

    /// 解析一条任务行（兼容 homework / reading 两种类型）
    /// Parse a single task row. Accepts both English (homework / reading) and Chinese (作业 / 阅读) type values.
    private static func parseTaskRow(_ fields: [String]) -> TaskItem? {
        guard fields.count >= tasksHeader.count else { return nil }

        // 0=ID, 1=Title, 2=Type, 3=Subject, 4=DueDate, 5=ReminderTime,
        // 6=Importance, 7=Notes, 8=IsCompleted, 9=CreatedAt
        let idString = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID(uuidString: idString) ?? UUID()
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let typeRaw = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate = parseDate(fields[4].trimmingCharacters(in: .whitespacesAndNewlines))
        let reminderDate = parseDate(fields[5].trimmingCharacters(in: .whitespacesAndNewlines))
        let importance = Int(fields[6].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3
        let notes = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)
        let isCompletedRaw = fields[8].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isCompleted = (isCompletedRaw == "true" || isCompletedRaw == "1" || isCompletedRaw == "yes" || isCompletedRaw == "是")
        let createdAt = parseDate(fields[9].trimmingCharacters(in: .whitespacesAndNewlines))

        guard let type = normalizeTaskType(typeRaw) else { return nil }

        return TaskItem(
            id: id,
            title: title,
            type: type,
            dueDate: dueDate,
            reminderDate: reminderDate,
            subject: subject,
            importance: importance,
            notes: notes,
            isCompleted: isCompleted,
            reminderEventId: nil,
            reminderCalendarId: nil,
            createdAt: createdAt
        )
    }

    /// 兼容英文（homework / reading）和中文（作业 / 阅读），直接返回模型层的 `TaskType`。
    /// Accept English (homework / reading) and Chinese (作业 / 阅读). Returns the model-layer `TaskType`.
    private static func normalizeTaskType(_ raw: String) -> TaskType? {
        let lower = raw.lowercased()
        if lower == "homework" || lower == "作业" { return .homework }
        if lower == "reading" || lower == "阅读" { return .reading }
        return nil
    }

    // MARK: - CSV Low-Level

    /// 解析整个 CSV 字符串为行（每行是字段数组）。
    /// 支持引号转义（"" 表示字面量 "），可处理字段内含 , " 换行。
    private static func parseCSVRows(_ csvString: String) -> [[String]] {
        var cleaned = csvString
        if cleaned.hasPrefix("\u{FEFF}") {
            cleaned = String(cleaned.dropFirst())
        }

        // 统一换行符
        cleaned = cleaned
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(cleaned)
        var i = 0
        let n = chars.count

        while i < n {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < n && chars[i + 1] == "\"" {
                        // "" -> 字面量 "
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(c)
                    i += 1
                    continue
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i += 1
                    continue
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                    continue
                } else if c == "\n" {
                    currentRow.append(currentField)
                    if !(currentRow.count == 1 && currentRow[0].isEmpty) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    currentField = ""
                    i += 1
                    continue
                } else {
                    currentField.append(c)
                    i += 1
                    continue
                }
            }
        }

        // 收尾
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !(currentRow.count == 1 && currentRow[0].isEmpty) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    /// 把一行字段拼成 CSV 行（自动加引号转义）
    private static func joinRow(_ fields: [String]) -> String {
        return fields.map(escapeCSV).joined(separator: ",") + "\n"
    }

    /// RFC 4180 转义：包含 , " 换行的字段用 " 包起来，内部 " 变 ""
    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") || string.contains("\r") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Date() }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return Date()
    }
}
