import XCTest
@testable import OmniPilotKit

@MainActor
final class ClipboardHistoryTests: XCTestCase {
    func testRecordDeduplicatesAndMovesExistingItemToFront() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = ClipboardHistory(limit: 10, store: store)

        history.record("first", at: Date(timeIntervalSince1970: 1))
        history.record("second", at: Date(timeIntervalSince1970: 2))
        history.record("first", at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(history.items.map(\.text), ["first", "second"])
        XCTAssertEqual(history.items.first?.date, Date(timeIntervalSince1970: 3))
    }

    func testRecordIgnoresWhitespaceOnlyTextAndTruncatesLongText() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = ClipboardHistory(limit: 10, store: store)

        history.record(" \n\t ")
        history.record(String(repeating: "x", count: ClipboardHistory.maximumTextLength + 10))

        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(history.items[0].text.count, ClipboardHistory.maximumTextLength)
    }

    func testHistoryRespectsLimitAndTrimsWhenLimitIsReduced() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = ClipboardHistory(limit: 100, store: store)

        for value in 0..<11 {
            history.record("item-\(value)")
        }
        history.setLimit(10)

        XCTAssertEqual(history.items.count, 10)
        XCTAssertEqual(history.items.first?.text, "item-10")
        XCTAssertFalse(history.items.contains { $0.text == "item-0" })
    }

    func testHistoryPersistsAcrossInstancesAndClearPersists() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstHistory = ClipboardHistory(limit: 10, store: store)
        firstHistory.record("persistent text", at: Date(timeIntervalSince1970: 42))

        let restoredHistory = ClipboardHistory(limit: 10, store: store)
        XCTAssertEqual(restoredHistory.items.map(\.text), ["persistent text"])
        XCTAssertEqual(restoredHistory.items.first?.date, Date(timeIntervalSince1970: 42))

        restoredHistory.clear()
        XCTAssertTrue(ClipboardHistory(limit: 10, store: store).items.isEmpty)
    }

    func testCorruptHistoryCanBeClearedAndReplaced() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("invalid json".utf8).write(to: store.fileURL)

        let history = ClipboardHistory(limit: 10, store: store)
        XCTAssertNotNil(history.persistenceError)

        history.clear()

        XCTAssertNil(history.persistenceError)
        XCTAssertTrue(ClipboardHistory(limit: 10, store: store).items.isEmpty)
    }

    private func makeStore() throws -> (URL, ClipboardStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, ClipboardStore(fileURL: directory.appendingPathComponent("history.json")))
    }
}
