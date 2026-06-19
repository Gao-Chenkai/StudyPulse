#!/usr/bin/env swift
//
//  test_import.swift
//  StudyPulse
//
//  CSV
//

import Foundation

//  DataExportManager 

struct TestMistakeNote {
    let id: String
    let title: String
    let subject: String
    let originalQuestion: String
    let source: String
    let date: String
    let errorReason: String
    let wrongSolution: String
    let correctSolution: String
}

func parseCSVRows(_ csvString: String) -> [[String]] {
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

func parseMistakeLine(from fields: [String]) -> TestMistakeNote? {
    guard fields.count >= 9 else {
        print("[ERROR] : \(fields.count) 9 ")
        return nil
    }
    
    return TestMistakeNote(
        id: fields[0],
        title: fields[1],
        subject: fields[2],
        originalQuestion: fields[3],
        source: fields[4],
        date: fields[5],
        errorReason: fields[6],
        wrongSolution: fields[7],
        correctSolution: fields[8]
    )
}

func parseMistakes(from csvString: String) -> [TestMistakeNote] {
    var mistakes: [TestMistakeNote] = []
    
    var cleanedString = csvString
    if csvString.hasPrefix("\u{FEFF}") {
        cleanedString = String(csvString.dropFirst())
        print("[Tool]  BOM ")
    }
    
    let rows = parseCSVRows(cleanedString)
    
    print("[Data] CSV :  \(rows.count)")
    if rows.count > 0 {
        print("[Header] : \(rows[0])")
    }
    
    guard rows.count > 1 else {
        print("[WARN] CSV ")
        return []
    }
    
    for (index, row) in rows.dropFirst().enumerated() {
        print("[DEBUG]  \(index + 1) : \(row)")
        if let mistake = parseMistakeLine(from: row) {
            mistakes.append(mistake)
            print("[OK] : \(mistake.title) (: \(mistake.subject))")
        } else {
            print("[ERROR] :  \(row.count) 9 ")
        }
    }
    
    print("\n[Success]  \(mistakes.count) ")
    
    // 
    let subjectCounts = Dictionary(grouping: mistakes) { $0.subject }
        .mapValues { $0.count }
        .sorted { $0.value > $1.value }
    
    print("\n[Subjects] :")
    for (subject, count) in subjectCounts {
        print("  - \(subject): \(count) ")
    }
    
    return mistakes
}

// 
print("============================================================")
print("[Test] StudyPulse CSV ")
print("============================================================")

let csvPath = "/Users/chenkaigao/Documents/Program/Swift/StudyPulse/TestData/mistakes_sample.csv"
print("\n[File] : \(csvPath)")

do {
    let csvContent = try String(contentsOfFile: csvPath, encoding: .utf8)
    print("[OK] : \(csvContent.count) ")
    
    let mistakes = parseMistakes(from: csvContent)
    
    if mistakes.isEmpty {
        print("\n[ERROR] ")
        exit(1)
    } else {
        print("\n[OK]  \(mistakes.count) ")
        print("\n[Note]  5 :")
        for (index, mistake) in mistakes.prefix(5).enumerated() {
            print("\n  \(index + 1). \(mistake.title)")
            print("     : \(mistake.subject)")
            print("     : \(mistake.errorReason)")
        }
        exit(0)
    }
} catch {
    print("[ERROR] : \(error)")
    exit(1)
}
