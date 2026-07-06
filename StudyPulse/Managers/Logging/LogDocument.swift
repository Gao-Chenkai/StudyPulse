//
//  LogDocument.swift
//  StudyPulse
//

import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for exporting logs via .fileExporter.
struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.log, .plainText] }

    let content: String
    let fileName: String

    init(content: String, fileName: String) {
        self.content = content
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = content
        self.fileName = "export.log"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // String → UTF-8 转换理论上不会失败(都是合法 Unicode 标量),但保留 fallback 避免崩溃。
        let data = content.data(using: .utf8) ?? Data(content.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
