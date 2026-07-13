//
//  CSVDocument.swift
//  StudyPulse

import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for CSV export via .fileExporter.
/// `.fileExporter` 用的 CSV `FileDocument` 包装。
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let content: String
    let fileName: String

    init(content: String, fileName: String) {
        // Prepend UTF-8 BOM so Excel recognises the encoding.
        // 在最前面补 UTF-8 BOM，让 Excel 识别为 UTF-8 编码。
        let bom = "\u{FEFF}"
        self.content = bom + content
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var string: String?
        // 逐个尝试常见编码；先 UTF-8 系，再到 Windows/ISO 系。
        // Try common encodings in order: UTF-8 family first, then Windows/ISO.
        let encodings: [String.Encoding] = [
            .utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .windowsCP1252, .isoLatin1
        ]
        for encoding in encodings {
            if let str = String(data: data, encoding: encoding) {
                string = str
                break
            }
        }

        guard let content = string else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Strip BOM if present.
        // 如果存在 BOM 则去掉。
        var cleanedContent = content
        if content.hasPrefix("\u{FEFF}") {
            cleanedContent = String(content.dropFirst())
        }

        self.content = cleanedContent
        self.fileName = "export.csv"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // String → UTF-8 转换理论上不会失败(都是合法 Unicode 标量),但保留 fallback 避免崩溃。
        // String → UTF-8 should never fail (all legal Unicode scalars), but keep a fallback for safety.
        let data = content.data(using: .utf8) ?? Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
