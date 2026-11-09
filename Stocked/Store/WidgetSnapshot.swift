import Foundation

/// A small copy of the shopping list for the home-screen widget, kept in the shared app group.
struct WidgetSnapshot: Codable {
    struct Entry: Codable, Hashable {
        let name: String
        let category: String
        let note: String
    }

    static let appGroup = "group.com.payaz.Stocked"
    static let key = "widgetSnapshot"

    var toBuy: [Entry]
    var inStock: Int
    var useSoon: Int
    var updated: Date

    static func read() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
