
//
//  TestParser.swift
//   CSV 
//

import Foundation

// 
func testCSV() {
    print("=== StudyPulse CSV  ===")
    
    // 
    let filePath = "/Users/chenkaigao/Documents/Program/Swift/StudyPulse/TestData/mistakes_sample.csv"
    let fileURL = URL(fileURLWithPath: filePath)
    
    print("[File] : \(filePath)")
    
    do {
        // 
        var csvString: String?
        let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let str = try? String(contentsOf: fileURL, encoding: encoding) {
                csvString = str
                print("[OK] : \(encoding)")
                break
            }
        }
        
        guard let content = csvString else {
            print("[ERROR] ")
            return
        }
        
        print("\n[Header]  800 :")
        print(String(content.prefix(800)))
        print("\n-------------------------")
        
        // 
        let rows = parseCSVRows(content)
        print("[Data]  \(rows.count) ")
        
        if rows.count > 0 {
            print("  : \(rows[0])")
        }
        
        if rows.count > 1 {
            print("   \(rows[1].count) ")
            print("  :")
            for (i, f) in rows[1].enumerated() {
                print("    [\(i)]: \(f.prefix(100))...")
            }
        }
        
    } catch {
        print("[ERROR] : \(error)")
    }
}

func parseCSVRows(_ csvString: String) -> [[String]] {
    print("\n[DEBUG] parseCSVRows ...")
    var rows: [[String]] = []
    var currentRow: [String] = []
    var currentField = ""
    var inQuotes = false
    
    let characters = Array(csvString)
    var i = 0
    let n = characters.count
    
    while i < n {
        let char = characters[i]
        
        if char == "\"" {
            if inQuotes && i + 1 < n && characters[i + 1] == "\"" {
                currentField.append("\"")
                i += 1
            } else {
                inQuotes.toggle()
            }
        } else if char == "," && !inQuotes {
            currentRow.append(currentField)
            currentField = ""
        } else if (char == "\n" || char == "\r") && !inQuotes {
            currentRow.append(currentField)
            rows.append(currentRow)
            currentRow = []
            currentField = ""
            
            if char == "\r" && i + 1 < n && characters[i + 1] == "\n" {
                i += 1
            }
        } else {
            currentField.append(char)
        }
        
        i += 1
    }
    
    if !currentField.isEmpty || !currentRow.isEmpty {
        currentRow.append(currentField)
        rows.append(currentRow)
    }
    
    return rows
}

testCSV()
