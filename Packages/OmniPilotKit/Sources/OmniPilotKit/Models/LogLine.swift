import Foundation

public struct LogLine: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let source: String
    public let text: String
    public let isError: Bool

    public init(id: UUID = UUID(), date: Date = Date(), source: String, text: String, isError: Bool = false) {
        self.id = id
        self.date = date
        self.source = source
        self.text = text
        self.isError = isError
    }
}
