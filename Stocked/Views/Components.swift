import SwiftUI
import CoreData

/// Coloured rounded tile with the category's symbol, like the Settings app.
struct CategoryIcon: View {
    let category: Category
    var size: CGFloat = 29

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A list row for an item in the kitchen.
struct ItemRow: View {
    @ObservedObject var item: Item

    private var detail: (text: String, color: Color)? {
        if let text = item.bestBeforeText, item.inStock, let days = item.daysUntilBestBefore, days <= 3 {
            return (text, days < 0 ? .red : .orange)
        }
        if item.isLow { return ("Low: keep \(item.minQuantity)", .orange) }
        if item.onList { return ("On shopping list", .secondary) }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: item.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                if let detail {
                    Text(detail.text)
                        .font(.footnote)
                        .foregroundStyle(detail.color)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if item.inStock {
                Text("\(item.quantity)")
                    .monospacedDigit()
                    .foregroundStyle(item.isLow ? Color.orange : Color.secondary)
            } else {
                Pill(text: "Run Out", color: .red)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// Grid of category tiles for choosing where an item lives.
struct CategoryPicker: View {
    @Binding var selection: Category
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Category.allCases) { category in
                let isSelected = selection == category
                Button {
                    selection = category
                } label: {
                    VStack(spacing: 8) {
                        CategoryIcon(category: category, size: 36)
                        Text(category.name)
                            .font(.footnote.weight(.medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2, reservesSpace: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// The big round symbol, title and subtitle at the top of a result sheet.
struct StatusHeader: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String
    var code: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(color.gradient, in: Circle())
                .padding(.bottom, 4)
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let code {
                Text(code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Sample data for SwiftUI previews only.
@MainActor
enum PreviewData {
    static let store: KitchenStore = {
        let store = KitchenStore(persistence: PersistenceController(inMemory: true))
        let samples: [(String, Category, Int64)] = [
            ("Ground Cumin", .herbs, 1),
            ("Smoked Paprika", .herbs, 1),
            ("Basmati Rice 1kg", .dry, 2),
            ("Penne Pasta 500g", .dry, 3),
            ("Chopped Tomatoes 400g", .tinned, 4),
            ("Greek Yoghurt", .fridge, 1),
            ("Frozen Peas", .freezer, 1),
        ]
        for (name, category, quantity) in samples {
            store.newItem(name: name, category: category, quantity: quantity)
        }
        store.newItem(name: "Milk", category: .fridge, quantity: 1, bestBefore: Calendar.current.date(byAdding: .day, value: 1, to: .now))
        if let chickpeas = store.newItem(name: "Chickpeas 400g", category: .tinned, quantity: 0, onList: true) {
            chickpeas.everStocked = true
        }
        store.save()
        return store
    }()

    static var kitchen: Kitchen { store.kitchen! }
}
