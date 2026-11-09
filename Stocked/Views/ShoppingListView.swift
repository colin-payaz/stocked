import SwiftUI
import CoreData

struct ShoppingListView: View {
    let kitchen: Kitchen

    @EnvironmentObject private var store: KitchenStore
    @FetchRequest private var items: FetchedResults<Item>
    @State private var newName = ""
    @State private var ticked: Set<NSManagedObjectID> = []
    @State private var tickCount = 0
    @FocusState private var addFieldFocused: Bool

    init(kitchen: Kitchen) {
        self.kitchen = kitchen
        _items = FetchRequest(fetchRequest: Item.request(in: kitchen), animation: .default)
    }

    private var onList: [Item] {
        items.filter(\.onList).sorted { ($0.category.order, $0.displayName) < ($1.category.order, $1.displayName) }
    }

    private var runOut: [Item] {
        items.filter { !$0.onList && !$0.inStock && $0.everStocked }
    }

    private var shareText: String {
        "Shopping list\n" + onList.map { "• \($0.displayName)" }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        TextField("Add to list", text: $newName)
                            .focused($addFieldFocused)
                            .submitLabel(.done)
                            .onSubmit(addTypedItem)
                    }
                }

                if onList.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Nothing to Buy",
                            systemImage: "checklist",
                            description: Text("Type above to add something. When you use the last of an item, it lands here on its own.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(Category.allCases) { category in
                        let rows = onList.filter { $0.category == category }
                        if !rows.isEmpty {
                            Section(category.name) {
                                ForEach(rows) { item in
                                    listRow(item)
                                }
                            }
                        }
                    }
                    Section {
                    } footer: {
                        Text("Ticking something off adds one to your kitchen. At the shop, you can also scan things in Shop mode to tick them off.")
                    }
                }

                if !runOut.isEmpty {
                    Section("Run Out") {
                        ForEach(runOut) { item in
                            HStack(spacing: 12) {
                                CategoryIcon(category: item.category)
                                Text(item.displayName)
                                Spacer()
                                Button {
                                    withAnimation { item.onList = true }
                                } label: {
                                    Image(systemName: "cart.badge.plus")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Add \(item.displayName) to list")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                if !onList.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share list")
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: tickCount)
        }
    }

    private func reason(for item: Item) -> String {
        if item.isLow { return "You have \(item.quantity), keep \(item.minQuantity)" }
        if item.inStock { return "You have \(item.quantity) at home" }
        return item.everStocked ? "Run out" : "New"
    }

    private func listRow(_ item: Item) -> some View {
        let isTicked = ticked.contains(item.objectID)
        return HStack(spacing: 12) {
            Button {
                tick(item)
            } label: {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isTicked ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Bought \(item.displayName)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .strikethrough(isTicked)
                    .foregroundStyle(isTicked ? .secondary : .primary)
                Text(reason(for: item))
                    .font(.footnote)
                    .foregroundStyle(item.isLow ? Color.orange : Color.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                remove(item)
            } label: {
                Label("Remove", systemImage: "cart.badge.minus")
            }
        }
    }

    @MainActor
    private func tick(_ item: Item) {
        let id = item.objectID
        guard !ticked.contains(id) else { return }
        withAnimation { _ = ticked.insert(id) }
        tickCount += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation {
                item.addOne()
                ticked.remove(id)
            }
        }
    }

    private func remove(_ item: Item) {
        if !item.everStocked && !item.inStock {
            // Typed straight onto the list and never bought: nothing to keep.
            store.delete(item)
        } else {
            item.onList = false
        }
    }

    private func addTypedItem() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = items.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.onList = true
        } else {
            store.newItem(name: name, category: .other, quantity: 0, onList: true)
        }
        newName = ""
        addFieldFocused = true
    }
}

#Preview {
    ShoppingListView(kitchen: PreviewData.kitchen)
        .environmentObject(PreviewData.store)
        .environment(\.managedObjectContext, PreviewData.store.context)
}
