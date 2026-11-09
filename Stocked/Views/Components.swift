import SwiftUI
import SwiftData

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
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: item.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.isEmpty ? "Unnamed Item" : item.name)
                    .lineLimit(1)
                if item.onList {
                    Text("On shopping list")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if item.inStock {
                Text("\(item.quantity)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Run Out")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red.opacity(0.12), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
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
    static let container: ModelContainer = {
        let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let samples: [Item] = [
            Item(name: "Ground Cumin", category: .herbs, quantity: 1),
            Item(name: "Smoked Paprika", category: .herbs, quantity: 1),
            Item(name: "Basmati Rice 1kg", category: .dry, quantity: 2),
            Item(name: "Penne Pasta 500g", category: .dry, quantity: 3),
            Item(name: "Chopped Tomatoes 400g", barcode: "5000157024671", category: .tinned, quantity: 4),
            Item(name: "Chickpeas 400g", category: .tinned, quantity: 0, onList: true),
            Item(name: "Greek Yoghurt", category: .fridge, quantity: 1),
            Item(name: "Frozen Peas", category: .freezer, quantity: 1),
        ]
        samples[5].everStocked = true
        samples.forEach { container.mainContext.insert($0) }
        return container
    }()
}
