import Foundation
import Combine

@MainActor
public final class ClipboardHistory: ObservableObject {
    nonisolated public static let allowedLimits = [10, 20, 30, 50, 100]
    nonisolated public static let defaultLimit = 30
    nonisolated public static let maximumTextLength = 100_000

    public static let shared = ClipboardHistory(limit: 100)

    @Published public private(set) var items: [ClipboardItem]
    @Published public private(set) var limit: Int
    @Published public private(set) var persistenceError: String?

    private let store: ClipboardStore

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

        let retainedItems = Array(loadedItems.prefix(effectiveLimit))
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
        allowedLimits.contains(value) ? value : defaultLimit
    }

    /// Applies a preset limit and immediately removes records beyond it.
    public func setLimit(_ value: Int) {
        let newLimit = Self.normalizedLimit(value)
        guard newLimit != limit || items.count > newLimit else { return }

        limit = newLimit
        if items.count > newLimit {
            items = Array(items.prefix(newLimit))
            persist()
        }
    }

    public func record(_ text: String, at date: Date = Date()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let boundedText = String(text.prefix(Self.maximumTextLength))
        if let existingIndex = items.firstIndex(where: { $0.text == boundedText }) {
            let existing = items.remove(at: existingIndex)
            items.insert(ClipboardItem(id: existing.id, text: boundedText, date: date), at: 0)
        } else {
            items.insert(ClipboardItem(text: boundedText, date: date), at: 0)
        }

        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        persist()
    }

    public func remove(_ id: ClipboardItem.ID) {
        guard items.contains(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        items.removeAll()
        persist()
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
