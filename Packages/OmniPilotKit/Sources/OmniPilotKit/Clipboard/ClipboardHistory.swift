import Foundation
import Combine

@MainActor
public final class ClipboardHistory: ObservableObject {
    nonisolated public static let minimumLimit = 10
    nonisolated public static let maximumLimit = 500
    nonisolated public static let allowedLimits = [20, 50, 100, 200, 500]
    nonisolated public static let defaultLimit = 50
    nonisolated public static let maximumTextLength = 100_000

    public static let shared = ClipboardHistory(limit: ClipboardHistory.maximumLimit)

    @Published public private(set) var items: [ClipboardItem]
    @Published public private(set) var limit: Int
    @Published public private(set) var persistenceError: String?

    private let store: ClipboardStore

    public var hasPinnedItems: Bool {
        items.contains(where: \.isPinned)
    }

    public var unpinnedCount: Int {
        items.filter { !$0.isPinned }.count
    }

    public init(limit: Int = ClipboardHistory.defaultLimit, store: ClipboardStore = ClipboardStore()) {
        let effectiveLimit = Self.normalizedLimit(limit)
        let loadedItems: [ClipboardItem]
        var loadError: String? = nil
        do {
            loadedItems = try store.load()
        } catch {
            loadedItems = []
            loadError = error.localizedDescription
        }

        let retainedItems = Self.trimmed(loadedItems, to: effectiveLimit)
        self.store = store
        self.limit = effectiveLimit
        self.items = retainedItems
        self.persistenceError = loadError

        if loadedItems.count > retainedItems.count {
            do {
                try store.save(retainedItems)
            } catch {
                self.persistenceError = error.localizedDescription
            }
        }
    }

    nonisolated public static func normalizedLimit(_ value: Int) -> Int {
        guard value > 0 else { return defaultLimit }
        return min(max(value, minimumLimit), maximumLimit)
    }

    /// Applies a limit in `10...500` and immediately removes records beyond it.
    public func setLimit(_ value: Int) {
        let newLimit = Self.normalizedLimit(value)
        guard newLimit != limit || items.count > newLimit else { return }

        limit = newLimit
        if items.count > newLimit {
            items = Self.trimmed(items, to: newLimit)
            persist()
        }
    }

    public func record(_ text: String, at date: Date = Date()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let boundedText = String(text.prefix(Self.maximumTextLength))
        if let existingIndex = items.firstIndex(where: { $0.text == boundedText }) {
            let existing = items.remove(at: existingIndex)
            let updated = ClipboardItem(
                id: existing.id,
                text: boundedText,
                date: date,
                isPinned: existing.isPinned,
                note: existing.note
            )
            insertMaintainingOrder(updated)
        } else {
            insertMaintainingOrder(ClipboardItem(text: boundedText, date: date))
        }

        if items.count > limit {
            items = Self.trimmed(items, to: limit)
        }
        persist()
    }

    public func togglePin(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.isPinned.toggle()
        insertMaintainingOrder(item)
        persist()
    }

    public func updateNote(_ id: ClipboardItem.ID, note: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let normalized = ClipboardItem.normalizedNote(note)
        guard items[index].note != normalized else { return }
        items[index].note = normalized
        persist()
    }

    public func remove(_ id: ClipboardItem.ID) {
        guard items.contains(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        persist()
    }

    /// Removes only unpinned records while keeping pinned items intact.
    public func clearUnpinned() {
        let hadUnpinned = items.contains { !$0.isPinned }
        guard hadUnpinned || persistenceError != nil else { return }
        items.removeAll { !$0.isPinned }
        persist()
    }

    /// Removes every record including pinned items.
    public func clear() {
        items.removeAll()
        persist()
    }

    private func insertMaintainingOrder(_ item: ClipboardItem) {
        if item.isPinned {
            items.insert(item, at: 0)
        } else {
            let firstUnpinned = items.firstIndex(where: { !$0.isPinned }) ?? items.endIndex
            items.insert(item, at: firstUnpinned)
        }
    }

    private static func trimmed(_ source: [ClipboardItem], to limit: Int) -> [ClipboardItem] {
        let pinned = source.filter(\.isPinned)
        let unpinned = source.filter { !$0.isPinned }
        let ordered = pinned + unpinned
        guard ordered.count > limit else { return ordered }
        if pinned.count >= limit {
            return Array(pinned.prefix(limit))
        }
        let remaining = limit - pinned.count
        return pinned + Array(unpinned.prefix(remaining))
    }

    private func persist() {
        do {
            try store.save(items)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
