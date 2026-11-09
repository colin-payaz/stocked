import WidgetKit
import SwiftUI

struct ListEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ListProvider: TimelineProvider {
    private static let sample = WidgetSnapshot(
        toBuy: [
            .init(name: "Milk", category: "fridge", note: ""),
            .init(name: "Chopped Tomatoes", category: "tinned", note: "Have 1"),
            .init(name: "Basmati Rice", category: "dry", note: ""),
            .init(name: "Frozen Peas", category: "freezer", note: ""),
        ],
        inStock: 42,
        useSoon: 2,
        updated: .now
    )

    private var current: WidgetSnapshot {
        WidgetSnapshot.read() ?? WidgetSnapshot(toBuy: [], inStock: 0, useSoon: 0, updated: .now)
    }

    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> Void) {
        completion(ListEntry(date: .now, snapshot: context.isPreview ? Self.sample : current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListEntry>) -> Void) {
        // The app asks for a reload whenever the list changes.
        completion(Timeline(entries: [ListEntry(date: .now, snapshot: current)], policy: .never))
    }
}

@main
struct StockedWidgets: WidgetBundle {
    var body: some Widget {
        ShoppingListWidget()
    }
}

struct ShoppingListWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShoppingList", provider: ListProvider()) { entry in
            ShoppingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "stocked://list"))
        }
        .configurationDisplayName("Shopping List")
        .description("See what you need to buy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
    }
}

struct ShoppingListWidgetView: View {
    let entry: ListEntry
    @Environment(\.widgetFamily) private var family

    private var items: [WidgetSnapshot.Entry] { entry.snapshot.toBuy }

    private var maxRows: Int {
        switch family {
        case .systemSmall: 4
        case .systemMedium: 4
        case .systemLarge: 11
        default: 2
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(items.isEmpty ? "Nothing to buy" : "\(items.count) to buy", systemImage: "cart")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(items.isEmpty ? "Nothing to buy" : "\(items.count) to buy")
                    .font(.headline)
                    .widgetAccentable()
                ForEach(items.prefix(2), id: \.self) { item in
                    Text(item.name).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary
                    .frame(width: 96, alignment: .leading)
                rows
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                header
                rows
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Shopping List")
                .font(.headline)
            Spacer()
            Text("\(items.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.tint)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(.tint)
            Spacer(minLength: 0)
            Text("\(items.count)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            Text("to buy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if entry.snapshot.useSoon > 0 {
                Text("\(entry.snapshot.useSoon) to use soon")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        if items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Nothing to buy")
                    .font(.subheadline.weight(.semibold))
                Text("\(entry.snapshot.inStock) items at home")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: family == .systemLarge ? 7 : 5) {
                ForEach(items.prefix(maxRows), id: \.self) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill((Category(rawValue: item.category) ?? .other).color)
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !item.note.isEmpty, family != .systemSmall {
                            Text(item.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if items.count > maxRows {
                    Text("+\(items.count - maxRows) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#Preview(as: .systemMedium) {
    ShoppingListWidget()
} timeline: {
    ListEntry(date: .now, snapshot: WidgetSnapshot(
        toBuy: [.init(name: "Milk", category: "fridge", note: ""), .init(name: "Chopped Tomatoes", category: "tinned", note: "Have 1")],
        inStock: 42, useSoon: 1, updated: .now))
}
