import CoreData

/// A kitchen: the thing that gets shared with a household. Every item belongs to one.
@objc(Kitchen)
final class Kitchen: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var name: String
    @NSManaged var createdAt: Date?
    @NSManaged var items: NSSet?

    var itemsArray: [Item] { (items as? Set<Item>).map(Array.init) ?? [] }
}

/// One product in the kitchen.
@objc(Item)
final class Item: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var name: String
    @NSManaged var barcode: String
    @NSManaged var categoryRaw: String
    @NSManaged var quantity: Int64
    /// Keep at least this many. 0 means no minimum.
    @NSManaged var minQuantity: Int64
    @NSManaged var onList: Bool
    /// True once the item has ever been in the kitchen. Items typed straight
    /// onto the shopping list stay out of the kitchen until they're bought.
    @NSManaged var everStocked: Bool
    @NSManaged var bestBefore: Date?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var kitchen: Kitchen?
}

extension Item {
    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var displayName: String { name.isEmpty ? "Unnamed Item" : name }
    var inStock: Bool { quantity > 0 }
    var showsInKitchen: Bool { quantity > 0 || everStocked }
    /// In stock, but fewer than the minimum you want to keep.
    var isLow: Bool { minQuantity > 0 && quantity > 0 && quantity < minQuantity }

    /// Whole days until the best-before date: 0 is today, negative is past.
    var daysUntilBestBefore: Int? {
        guard let bestBefore else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: bestBefore)).day
    }

    /// In stock and within three days of its best-before date (or past it).
    var useSoon: Bool {
        guard inStock, let days = daysUntilBestBefore else { return false }
        return days <= 3
    }

    var bestBeforeText: String? {
        guard let days = daysUntilBestBefore else { return nil }
        switch days {
        case ..<(-1): return "Best before was \(-days) days ago"
        case -1: return "Best before was yesterday"
        case 0: return "Best before today"
        case 1: return "Best before tomorrow"
        case 2...6: return "Best before in \(days) days"
        default: return "Best before \(bestBefore!.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }

    /// Use one up. The kitchen store puts it on the list if that takes it below the minimum.
    func useOne() {
        if quantity > 0 { quantity -= 1 }
    }

    /// Bought one: add it to the kitchen and take it off the list.
    func addOne() {
        quantity += 1
        onList = false
    }

    static func request(in kitchen: Kitchen, predicate extra: NSPredicate? = nil) -> NSFetchRequest<Item> {
        let request = NSFetchRequest<Item>(entityName: "Item")
        let inKitchen = NSPredicate(format: "kitchen == %@", kitchen)
        request.predicate = extra.map { NSCompoundPredicate(andPredicateWithSubpredicates: [inKitchen, $0]) } ?? inKitchen
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        return request
    }
}

enum Barcode {
    /// Scanners report UPC-A both as 12 digits and as 13 with a leading zero,
    /// so compare without leading zeros.
    static func matches(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.drop(while: { $0 == "0" }) == b.drop(while: { $0 == "0" })
    }
}
