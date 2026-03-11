//
//  PinnedOrderStore.swift
//  CmdRack
//

import Foundation

/// Persists the manual order of pinned commands.
/// The first N (from settings) are treated as primary in the menu bar popover.
final class PinnedOrderStore {
    static let shared = PinnedOrderStore()

    private static let storageKey = "CmdRack.PinnedOrderIDs"

    private init() {}

    /// Ordered list of pinned command IDs, most important first.
    var ids: [UUID] {
        get {
            guard let raw = UserDefaults.standard.stringArray(forKey: Self.storageKey) else { return [] }
            return raw.compactMap { UUID(uuidString: $0) }
        }
        set {
            let unique = Array(NSOrderedSet(array: newValue).compactMap { $0 as? UUID })
            UserDefaults.standard.set(unique.map(\.uuidString), forKey: Self.storageKey)
        }
    }

    /// Returns `items` sorted according to the stored order, with any unknown IDs appended by `updatedAt` desc.
    func applyOrder(to items: [CommandItem]) -> [CommandItem] {
        guard !items.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        var ordered: [CommandItem] = []
        var seen: Set<UUID> = []
        for id in ids {
            if let item = byID[id], !seen.contains(id) {
                ordered.append(item)
                seen.insert(id)
            }
        }

        let remaining = items.filter { !seen.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }

        return ordered + remaining
    }

    /// Save a new explicit order for the given pinned items.
    func saveOrder(for items: [CommandItem]) {
        ids = items.map(\.id)
        NotificationCenter.default.post(name: .cmdRackPinnedOrderDidChange, object: nil)
    }
}

