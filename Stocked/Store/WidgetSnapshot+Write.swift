import Foundation
import WidgetKit

extension WidgetSnapshot {
    /// Save the shopping list for the widget and ask iOS to redraw it.
    static func write(_ items: [Item]) {
        let toBuy = items
            .filter(\.onList)
            .sorted { ($0.category.order, $0.displayName) < ($1.category.order, $1.displayName) }
            .map { item in
                Entry(
                    name: item.displayName,
                    category: item.category.rawValue,
                    note: item.inStock ? "Have \(item.quantity)" : ""
                )
            }
        let snapshot = WidgetSnapshot(
            toBuy: toBuy,
            inStock: items.filter(\.inStock).count,
            useSoon: items.filter(\.useSoon).count,
            updated: .now
        )
        // Skip the redraw when nothing the widget shows has changed.
        if let old = read(), old.toBuy == snapshot.toBuy, old.inStock == snapshot.inStock, old.useSoon == snapshot.useSoon {
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroup)?.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
