import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let studyPulseBackup = UTType(
        exportedAs: BackupManifest.expectedFormatIdentifier,
        conformingTo: .zip
    )
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.studyPulseBackup] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupError.invalidArchive
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
