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

    func testPinnedItemsStayAtTopAndSurviveEviction() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = ClipboardHistory(limit: 10, store: store)

        history.record("pinned-one", at: Date(timeIntervalSince1970: 1))
        let pinnedID = try XCTUnwrap(history.items.first?.id)
        history.togglePin(pinnedID)

        for value in 0..<12 {
            history.record("item-\(value)", at: Date(timeIntervalSince1970: TimeInterval(value + 10)))
        }

        XCTAssertEqual(history.items.count, 10)
        XCTAssertEqual(history.items.first?.text, "pinned-one")
        XCTAssertEqual(history.items.first?.isPinned, true)
        XCTAssertEqual(history.items[1].text, "item-11")
    }

    func testNotePersistsAcrossDuplicateRecordAndClearUnpinnedKeepsPinned() throws {
        let (directory, store) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = ClipboardHistory(limit: 50, store: store)

        history.record("ssh -p 2222 root@10.0.0.1", at: Date(timeIntervalSince1970: 1))
        let itemID = try XCTUnwrap(history.items.first?.id)
        history.updateNote(itemID, note: " 生产跳板机 ")
        history.togglePin(itemID)

        history.record("temporary text", at: Date(timeIntervalSince1970: 2))
        history.record("ssh -p 2222 root@10.0.0.1", at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(history.items.first?.note, "生产跳板机")
        XCTAssertEqual(history.items.first?.isPinned, true)

        history.clearUnpinned()
        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(history.items.first?.note, "生产跳板机")

        history.updateNote(itemID, note: "   ")
        XCTAssertNil(history.items.first?.note)
    }

    func testNormalizedLimitClampsToAllowedRangeAndDefaultsTo50() {
        XCTAssertEqual(ClipboardHistory.normalizedLimit(0), 50)
        XCTAssertEqual(ClipboardHistory.normalizedLimit(-5), 50)
        XCTAssertEqual(ClipboardHistory.normalizedLimit(5), 10)
        XCTAssertEqual(ClipboardHistory.normalizedLimit(128), 128)
        XCTAssertEqual(ClipboardHistory.normalizedLimit(999), 500)
    }

    private func makeStore() throws -> (URL, ClipboardStore) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, ClipboardStore(fileURL: directory.appendingPathComponent("history.json")))
    }
}
