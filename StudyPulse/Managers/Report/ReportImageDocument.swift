//
//  ReportImageDocument.swift
//  StudyPulse
//
//  FileDocument wrapper for a single report image (PNG or JPEG).
//  Mirrors the `LogDocument` pattern so the report can be saved via
//  the standard `.fileExporter` flow.
//
//  单张报告图片的 FileDocument 包装(PNG 或 JPEG)。
//  FileDocument wrapper for a single report image (PNG or JPEG).
//  Mirrors the `LogDocument` pattern so the report can be saved via
//  the standard `.fileExporter` flow.
//

import SwiftUI
import UniformTypeIdentifiers

/// `FileDocument` wrapper around a rendered report image.
/// - Important: the writable type is determined by `format` so the
///   system share sheet offers the right UTType filter.
struct ReportImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .jpeg] }
    static var writableContentTypes: [UTType] { [.png, .jpeg] }

    let data: Data
    let fileName: String
    let contentType: UTType

    init(data: Data, fileName: String, contentType: UTType) {
        self.data = data
        self.fileName = fileName
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        // 读取失败(无内容)抛 fileReadCorruptFile
        // Throw fileReadCorruptFile if the read has no contents.
        guard let raw = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = raw
        self.fileName = "StudyPulse_Report.bin"
        // 从系统读入的 UTI 决定最终 contentType(默认 PNG)
        // The content type is derived from the read configuration; defaults to PNG.
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // 写出时直接以原始字节包成 FileWrapper(contentType 在外层 ShareLink 决定)
        // Wrap raw bytes into a FileWrapper; the outer ShareLink decides the content type.
        FileWrapper(regularFileWithContents: data)
    }
}
