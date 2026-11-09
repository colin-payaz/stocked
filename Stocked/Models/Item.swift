import Foundation
import SwiftData

/// One product in the kitchen. Every property has a default so the store can
/// later sync through iCloud (CloudKit requires that).
@Model
final class Item {
    var name: String = ""
    var barcode: String = ""
    var categoryRaw: String = "other"
    var quantity: Int = 0
    var onList: Bool = false
    /// True once the item has ever been in the kitchen. Items typed straight
    /// onto the shopping list stay out of the kitchen until they're bought.
    var everStocked: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(name: String, barcode: String = "", category: Category = .dry, quantity: Int = 1, onList: Bool = false) {
        self.name = name
        self.barcode = barcode
        self.categoryRaw = category.rawValue
        self.quantity = quantity
        self.onList = onList
        self.everStocked = quantity > 0
        self.createdAt = .now
        self.updatedAt = .now
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var inStock: Bool { quantity > 0 }
    var showsInKitchen: Bool { quantity > 0 || everStocked }

    /// Use one up. Using the last one puts it on the shopping list.
    func useOne() {
        quantity = max(0, quantity - 1)
        if quantity == 0 { onList = true }
        touch()
    }

    /// Bought one: add it to the kitchen and take it off the list.
    func addOne() {
        quantity += 1
        onList = false
        everStocked = true
        touch()
    }

    func touch() { updatedAt = .now }
}

enum Barcode {
    /// Scanners report UPC-A both as 12 digits and as 13 with a leading zero,
    /// so compare without leading zeros.
    static func matches(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.drop(while: { $0 == "0" }) == b.drop(while: { $0 == "0" })
    }
}
