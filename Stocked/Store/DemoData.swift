import Foundation

#if DEBUG
/// Sample kitchen for simulator screenshots. Only runs when the app is launched
/// with `-demoData YES`, and only into an empty kitchen.
extension KitchenStore {
    func seedDemoDataIfRequested() {
        guard UserDefaults.standard.bool(forKey: "demoData"), allItems().isEmpty else { return }
        let calendar = Calendar.current
        func days(_ n: Int) -> Date? { calendar.date(byAdding: .day, value: n, to: .now) }

        let samples: [(String, Category, Int64, Int64, Date?)] = [
            ("Ground Cumin", .herbs, 1, 0, nil),
            ("Smoked Paprika", .herbs, 1, 0, nil),
            ("Dried Oregano", .herbs, 2, 0, nil),
            ("Basmati Rice 1kg", .dry, 2, 1, nil),
            ("Penne Pasta 500g", .dry, 1, 2, nil),
            ("Plain Flour 1.5kg", .dry, 1, 0, nil),
            ("Porridge Oats", .dry, 1, 0, nil),
            ("Chopped Tomatoes 400g", .tinned, 4, 2, nil),
            ("Coconut Milk", .tinned, 2, 0, nil),
            ("Baked Beans 415g", .tinned, 3, 0, nil),
            ("Greek Yoghurt", .fridge, 1, 0, days(2)),
            ("Semi-Skimmed Milk", .fridge, 1, 0, days(1)),
            ("Mature Cheddar", .fridge, 1, 0, days(12)),
            ("Frozen Peas", .freezer, 1, 0, nil),
            ("Fish Fingers", .freezer, 2, 0, nil),
        ]
        for (name, category, quantity, minimum, bestBefore) in samples {
            let item = newItem(name: name, barcode: "", category: category, quantity: quantity, bestBefore: bestBefore)
            item?.minQuantity = minimum
        }
        if let chickpeas = newItem(name: "Chickpeas 400g", category: .tinned, quantity: 0, onList: true) {
            chickpeas.everStocked = true
        }
        newItem(name: "Bananas", category: .other, quantity: 0, onList: true)
        newItem(name: "Olive Oil", category: .dry, quantity: 0, onList: true)
        save()
    }
}
#endif
