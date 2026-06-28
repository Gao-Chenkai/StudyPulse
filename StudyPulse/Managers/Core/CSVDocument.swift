//
//  CSVDocument.swift
//  StudyPulse

import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for CSV export via .fileExporter.
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    let content: String
    let fileName: String

    init(content: String, fileName: String) {
        // Prepend UTF-8 BOM so Excel recognises the encoding.
        let bom = "\u{FEFF}"
        self.content = bom + content
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var string: String?
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
        var cleanedContent = content
        if content.hasPrefix("\u{FEFF}") {
            cleanedContent = String(content.dropFirst())
        }

        self.content = cleanedContent
        self.fileName = "export.csv"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}
