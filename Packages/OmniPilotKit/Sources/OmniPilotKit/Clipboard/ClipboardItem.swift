import Foundation

public struct ClipboardItem: Codable, Hashable, Identifiable, Sendable {
    public static let previewCharacterLimit = 120

    public let id: UUID
    public let text: String
    public let date: Date

    public init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }

    /// A compact, single-line representation for the history list.
    public var preview: String {
        let flattened = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard flattened.count > Self.previewCharacterLimit else { return flattened }
        return String(flattened.prefix(Self.previewCharacterLimit)) + "…"
    }
}
