//
//  MistakePDFDocument.swift
//  StudyPulse
//
//  FileDocument 包装：把 MistakePDFRenderer 输出的 PDF Data 暴露给
//  .fileExporter 走系统分享面板（保存到文件 / 隔空投送 / 邮件 / 微信 等）。
//  沿用 ReportImageDocument / LogDocument 的模式。
//

import SwiftUI
import UniformTypeIdentifiers

/// `FileDocument` 包装:把 `MistakePDFRenderer` 输出的 PDF Data 暴露给
/// `.fileExporter` 走系统分享面板(保存到文件 / 隔空投送 / 邮件 / 微信 等)。
/// 沿用 `ReportImageDocument` / `LogDocument` 的模式。
/// FileDocument wrapper exposing MistakePDFRenderer output via the system
/// share sheet (.fileExporter) — mirrors the ReportImageDocument pattern.
struct MistakePDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    let data: Data
    let fileName: String

    init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

    init(configuration: ReadConfiguration) throws {
        // 系统回读 PDF 时直接拿 regularFileContents 原始字节
        // When the system re-reads the PDF, take the raw bytes from regularFileContents.
        guard let raw = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = raw
        self.fileName = "StudyPulse_Mistakes.pdf"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 写出时直接以原始 PDF 字节包成 FileWrapper
        // Wrap the raw PDF bytes into a FileWrapper for writing.
        FileWrapper(regularFileWithContents: data)
    }
}
