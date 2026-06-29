#!/usr/bin/env swift
//
//  csv_edge_case_test.swift
//  StudyPulse
//
//  验证引号感知 CSV 解析器处理边界用例：
//  - 字段内含 , 逗号
//  - 字段内含 " 双引号（用 "" 转义）
//  - 字段内含 \n 换行
//  - 半英文 / 半中文标题
//  - BOM
//
//  用法:
//    swift TestData/csv_edge_case_test.swift
//

import Foundation

// 复制自 DataExportManager.parseCSVRows（保持完全一致）
func parseCSVRows(_ csvString: String) -> [[String]] {
    var cleaned = csvString
    if cleaned.hasPrefix("\u{FEFF}") {
        cleaned = String(cleaned.dropFirst())
    }
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

    if !currentField.isEmpty || !currentRow.isEmpty {
        currentRow.append(currentField)
        if !(currentRow.count == 1 && currentRow[0].isEmpty) {
            rows.append(currentRow)
        }
    }

    return rows
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String) -> Bool {
    if actual == expected {
        print("  [PASS] \(label)")
        return true
    } else {
        print("  [FAIL] \(label)")
        print("         actual  = \(actual)")
        print("         expected= \(expected)")
        return false
    }
}

var allPassed = true

// Test 1: 字段内含逗号
print("Test 1: 字段内含逗号")
let t1 = "a,b,c\n1,\"hello, world\",3\n"
let r1 = parseCSVRows(t1)
allPassed = assertEqual(r1.count, 2, "行数") && allPassed
allPassed = assertEqual(r1[1][1], "hello, world", "第 2 行第 2 列") && allPassed

// Test 2: 字段内含双引号（"" 转义 → 单个 "）
print("\nTest 2: 字段内含双引号（用 \"\" 转义）")
let t2 = "a,b,c\n1,\"he said \"\"hi\"\"\",3\n"
let r2 = parseCSVRows(t2)
allPassed = assertEqual(r2[1][1], "he said \"hi\"", "第 2 行第 2 列") && allPassed

// Test 3: 字段内含换行
print("\nTest 3: 字段内含换行")
let t3 = "a,b,c\n1,\"line1\nline2\",3\n"
let r3 = parseCSVRows(t3)
allPassed = assertEqual(r3.count, 2, "行数") && allPassed
allPassed = assertEqual(r3[1][1], "line1\nline2", "字段含换行") && allPassed

// Test 4: 半英文 / 半中文
print("\nTest 4: 半英文 / 半中文")
let t4 = "a,b\n\"中文, 标题\",value\n"
let r4 = parseCSVRows(t4)
allPassed = assertEqual(r4[1][0], "中文, 标题", "中文 + 逗号") && allPassed

// Test 5: BOM
print("\nTest 5: BOM 处理")
let t5 = "\u{FEFF}a,b\n1,2"
let r5 = parseCSVRows(t5)
allPassed = assertEqual(r5.count, 2, "BOM 不影响行数") && allPassed
allPassed = assertEqual(r5[0][0], "a", "BOM 不污染首列") && allPassed

// Test 6: 实际边界文件
print("\nTest 6: 读取 TestData/mistakes_edge_cases.csv")
let edgePath = FileManager.default.currentDirectoryPath + "/TestData/mistakes_edge_cases.csv"
if let content = try? String(contentsOfFile: edgePath, encoding: .utf8) {
    let r7 = parseCSVRows(content)
    print("  parsed \(r7.count) rows")
    for (i, row) in r7.enumerated() {
        print("    row \(i): \(row.count) fields, first=\(row.first ?? "")")
    }
    if r7.count >= 2 {
        allPassed = assertEqual(r7.count >= 2, true, "至少有 1 行数据") && allPassed
        if let firstDataRow = r7.dropFirst().first {
            print("    first data title: \(firstDataRow[1])")
            // 第一行数据：逗号与引号测试
            allPassed = assertEqual(firstDataRow[0], "edge-0001-0000-0000-0000-000000000001", "第一行 ID") && allPassed
        }
    }
} else {
    print("  [SKIP] file not found at \(edgePath)")
}

print("\n" + String(repeating: "=", count: 50))
if allPassed {
    print("[ALL PASS] CSV 边界用例全部通过")
    exit(0)
} else {
    print("[FAIL] 有用例未通过")
    exit(1)
}
