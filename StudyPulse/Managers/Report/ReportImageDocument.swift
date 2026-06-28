//
//  ReportImageDocument.swift
//  StudyPulse
//
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
        guard let raw = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = raw
        self.fileName = "StudyPulse_Report.bin"
        // Pick the type from the read configuration, default to PNG.
        self.contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
