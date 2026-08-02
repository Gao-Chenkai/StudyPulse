#!/usr/bin/env swift

import Foundation

// MARK: - .strings Parser

/// Parse a single .strings file, returning a dictionary of key -> value.
/// Handles C-style escape sequences: \", \\, \n, \r, \t.
func parseStringsFile(at path: String) -> [String: String] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("⚠️  Could not read: \(path)")
        return [:]
    }

    var result: [String: String] = [:]
    var inBlockComment = false

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip empty lines
        if trimmed.isEmpty { continue }

        // Handle block comments
        if inBlockComment {
            if trimmed.contains("*/") {
                inBlockComment = false
            }
            continue
        }
        if trimmed.hasPrefix("/*") {
            if !trimmed.contains("*/") {
                inBlockComment = true
            }
            continue
        }

        // Skip line comments
        if trimmed.hasPrefix("//") { continue }

        // Must match "key" = "value";
        guard let eqRange = findEqualsSign(in: trimmed) else {
            continue
        }

        let keyPart = String(trimmed[trimmed.startIndex..<eqRange.lowerBound])
        let valuePart = String(trimmed[eqRange.upperBound..<trimmed.endIndex])

        guard let key = parseStringToken(keyPart),
              let value = parseStringToken(valuePart) else {
            print("⚠️  Parse error at line: \(trimmed.prefix(80))")
            continue
        }

        result[key] = value
    }

    return result
}

/// Find the `=` separating key and value, accounting for quotes.
func findEqualsSign(in line: String) -> Range<String.Index>? {
    // Pattern: "key" = "value";
    // We need to find the = that is after the first closing quote and before the second opening quote.
    // A simpler approach: find " = " pattern, but the spaces might vary.
    // Standard Xcode output: "key" = "value";
    // Let's find the first = that has a " before and after it.

    var inString = false
    var escaped = false
    var foundFirstString = false

    for (i, char) in line.enumerated() {
        if escaped {
            escaped = false
            continue
        }
        if char == "\\" {
            escaped = true
            continue
        }
        if char == "\"" {
            inString.toggle()
            if !inString && !foundFirstString {
                foundFirstString = true
            }
            continue
        }
        if !inString && foundFirstString && char == "=" {
            let eqIndex = line.index(line.startIndex, offsetBy: i)
            return eqIndex..<line.index(after: eqIndex)
        }
    }
    return nil
}

/// Parse a .strings token: "content" with optional ; at end.
/// Handles C-style escapes: \", \\, \n, \r, \t.
func parseStringToken(_ token: String) -> String? {
    var s = token.trimmingCharacters(in: .whitespaces)

    // Remove trailing semicolon
    if s.hasSuffix(";") {
        s = String(s.dropLast())
    }
    s = s.trimmingCharacters(in: .whitespaces)

    // Must be quoted
    guard s.hasPrefix("\"") && s.hasSuffix("\"") else {
        return nil
    }

    // Extract content between quotes
    let contentStart = s.index(after: s.startIndex)
    let contentEnd = s.index(before: s.endIndex)
    let content = String(s[contentStart..<contentEnd])

    // Unescape C-style sequences
    var result = ""
    var escaped = false
    for char in content {
        if escaped {
            switch char {
            case "n":  result.append("\n")
            case "r":  result.append("\r")
            case "t":  result.append("\t")
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            default:   result.append(char)
            }
            escaped = false
        } else if char == "\\" {
            escaped = true
        } else {
            result.append(char)
        }
    }
    // Handle trailing backslash (shouldn't happen in valid files)
    if escaped { result.append("\\") }

    return result
}

// MARK: - Comment extraction

/// Extract comment lines preceding each key in a .strings file.
/// Returns a dictionary of key -> comment string.
func extractComments(from path: String) -> [String: String] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        return [:]
    }

    var result: [String: String] = [:]
    var pendingComments: [String] = []
    var inBlockComment = false

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if inBlockComment {
            if trimmed.contains("*/") {
                inBlockComment = false
            }
            continue
        }
        if trimmed.hasPrefix("/*") {
            if !trimmed.contains("*/") {
                inBlockComment = true
            }
            continue
        }

        // Collect line comments
        if trimmed.hasPrefix("//") {
            let comment = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if !comment.isEmpty {
                pendingComments.append(comment)
            }
            continue
        }

        // Empty lines reset comment accumulation
        if trimmed.isEmpty {
            pendingComments = []
            continue
        }

        // This is a key-value line – associate pending comments with the key
        if let eqRange = findEqualsSign(in: trimmed),
           let key = parseStringToken(String(trimmed[trimmed.startIndex..<eqRange.lowerBound])) {
            if !pendingComments.isEmpty {
                result[key] = pendingComments.joined(separator: " | ")
                pendingComments = []
            }
        }
    }

    return result
}

// MARK: - .xcstrings Generation

struct XCStrings: Encodable {
    var sourceLanguage: String
    var strings: [String: StringEntry]
    var version: String
}

struct StringEntry: Encodable {
    var extractionState: String
    var comment: String?
    var localizations: [String: LocalizationEntry]
}

struct LocalizationEntry: Encodable {
    var stringUnit: StringUnit
}

struct StringUnit: Encodable {
    var state: String
    var value: String
}

func generateXCStrings(
    sourceLanguage: String,
    languages: [String],
    stringsFiles: [String: String],  // lang -> file path
    outputPath: String
) {
    // Gather all keys from all languages
    var allKeys = Set<String>()
    var translations: [String: [String: String]] = [:]  // lang -> [key: value]

    for (lang, path) in stringsFiles {
        let dict = parseStringsFile(at: path)
        translations[lang] = dict
        allKeys.formUnion(dict.keys)
    }

    // Extract comments from the source language file
    let sourceCommentPath = stringsFiles[sourceLanguage] ?? ""
    let comments = extractComments(from: sourceCommentPath)

    // Build the xcstrings structure
    var stringEntries: [String: StringEntry] = [:]

    // Sort keys for deterministic output
    let sortedKeys = allKeys.sorted()

    for key in sortedKeys {
        var localizations: [String: LocalizationEntry] = [:]

        for lang in languages {
            if let value = translations[lang]?[key] {
                localizations[lang] = LocalizationEntry(
                    stringUnit: StringUnit(state: "translated", value: value)
                )
            }
        }

        // If no source language translation exists, skip
        guard localizations[sourceLanguage] != nil else {
            print("⚠️  Key '\(key)' has no source language (\(sourceLanguage)) translation – skipping")
            continue
        }

        let entry = StringEntry(
            extractionState: "manual",
            comment: comments[key],
            localizations: localizations
        )
        stringEntries[key] = entry
    }

    let xcstrings = XCStrings(
        sourceLanguage: sourceLanguage,
        strings: stringEntries,
        version: "1.0"
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    // Don't escape slashes or unicode – keep the output readable
    var jsonData: Data
    do {
        jsonData = try encoder.encode(xcstrings)
    } catch {
        print("❌ Encoding error: \(error)")
        return
    }

    // Write to file
    do {
        try jsonData.write(to: URL(fileURLWithPath: outputPath))
        print("✅ Written: \(outputPath) (\(sortedKeys.count) keys, \(languages.count) languages)")
    } catch {
        print("❌ Write error: \(error)")
    }
}

// MARK: - Main

let baseDir = FileManager.default.currentDirectoryPath
let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]
let sourceLanguage = "en"

print("🚀 Migrating .strings → .xcstrings")
print("   Base directory: \(baseDir)")

// ─── Main App ───────────────────────────────────────────────
print("\n── Main App ──")
var mainAppFiles: [String: String] = [:]
for lang in languages {
    let path = "\(baseDir)/\(lang).lproj/Localizable.strings"
    if FileManager.default.fileExists(atPath: path) {
        mainAppFiles[lang] = path
        print("   ✅ \(lang): \(path)")
    } else {
        print("   ⚠️  \(lang): MISSING – \(path)")
    }
}

if !mainAppFiles.isEmpty {
    generateXCStrings(
        sourceLanguage: sourceLanguage,
        languages: languages,
        stringsFiles: mainAppFiles,
        outputPath: "\(baseDir)/StudyPulse/Localizable.xcstrings"
    )
}

// ─── Widget ──────────────────────────────────────────────────
print("\n── Widget ──")
var widgetFiles: [String: String] = [:]
for lang in languages {
    let path = "\(baseDir)/StudyPulseWidget/\(lang).lproj/Localizable.strings"
    if FileManager.default.fileExists(atPath: path) {
        widgetFiles[lang] = path
        print("   ✅ \(lang): \(path)")
    } else {
        print("   ⚠️  \(lang): MISSING – \(path)")
    }
}

if !widgetFiles.isEmpty {
    generateXCStrings(
        sourceLanguage: sourceLanguage,
        languages: languages,
        stringsFiles: widgetFiles,
        outputPath: "\(baseDir)/StudyPulseWidget/Localizable.xcstrings"
    )
}

print("\n🎉 Migration complete!")
