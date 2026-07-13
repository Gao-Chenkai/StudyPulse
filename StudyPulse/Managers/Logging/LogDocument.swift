//
//  LogDocument.swift
//  StudyPulse
//

import SwiftUI
import UniformTypeIdentifiers

/// `FileDocument` 包装,用于通过 `.fileExporter` 导出日志。
/// `FileDocument` wrapper for exporting logs via `.fileExporter`.
struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.log, .plainText] }

    let content: String
    let fileName: String

    init(content: String, fileName: String) {
        self.content = content
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        // 从系统读取配置中提取 regularFileContents,失败时抛 fileReadCorruptFile
        // Extract regularFileContents from the read configuration; throw on failure.
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
