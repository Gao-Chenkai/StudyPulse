import Foundation

/// An image selected in the chat composer, kept in-memory for the current turn.
nonisolated struct LLMImageAttachment: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: UUID
    let data: Data
    let mimeType: String

    init(id: UUID = UUID(), data: Data, mimeType: String = "image/jpeg") {
        self.id = id
        self.data = data
        self.mimeType = mimeType
    }

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}
