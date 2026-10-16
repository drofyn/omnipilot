import Foundation

public struct ClipboardItem: Codable, Hashable, Identifiable, Sendable {
    public static let previewCharacterLimit = 120

    public let id: UUID
    public let text: String
    public let date: Date
    public var isPinned: Bool
    public var note: String?

    public init(
        id: UUID = UUID(),
        text: String,
        date: Date = Date(),
        isPinned: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.isPinned = isPinned
        self.note = Self.normalizedNote(note)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case date
        case isPinned
        case note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.text = try container.decode(String.self, forKey: .text)
        self.date = try container.decode(Date.self, forKey: .date)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        let rawNote = try container.decodeIfPresent(String.self, forKey: .note)
        self.note = Self.normalizedNote(rawNote)
    }

    public static func normalizedNote(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
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
