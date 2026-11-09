import SwiftUI
import CoreData

struct KitchenView: View {
    let kitchen: Kitchen
    var onScan: () -> Void

    @EnvironmentObject private var store: KitchenStore
    @FetchRequest private var allItems: FetchedResults<Item>
    @State private var search = ""
    @State private var filter: Category?
    @State private var showingAdd = false
    @State private var showingHousehold = false

    init(kitchen: Kitchen, onScan: @escaping () -> Void) {
        self.kitchen = kitchen
        self.onScan = onScan
        _allItems = FetchRequest(fetchRequest: Item.request(in: kitchen), animation: .default)
    }

    private var kitchenItems: [Item] { allItems.filter(\.showsInKitchen) }

    private var visibleItems: [Item] {
        kitchenItems.filter { item in
            (filter == nil || item.category == filter)
                && (search.isEmpty
                    || item.name.localizedCaseInsensitiveContains(search)
                    || item.barcode.contains(search))
        }
    }

    private var useSoon: [Item] {
        visibleItems.filter(\.useSoon).sorted { ($0.bestBefore ?? .distantFuture) < ($1.bestBefore ?? .distantFuture) }
    }

    private var summary: String {
        let inStock = kitchenItems.filter(\.inStock).count
        let runOut = kitchenItems.count - inStock
        var parts = ["\(inStock) in stock"]
        if runOut > 0 { parts.append("\(runOut) run out") }
        if store.share != nil { parts.append("shared") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            List {
                if !kitchenItems.isEmpty && search.isEmpty {
                    Section {
                    } header: {
                        Text(summary).textCase(nil)
                    }
                }

                if !useSoon.isEmpty {
                    Section {
                        ForEach(useSoon) { item in
                            itemLink(item)
                        }
                    } header: {
                        Label("Use Soon", systemImage: "clock.badge.exclamationmark")
                    }
                }

                ForEach(Category.allCases) { category in
                    let rows = visibleItems.filter { $0.category == category }
                    if !rows.isEmpty {
                        Section(category.name) {
                            ForEach(rows) { item in
                                itemLink(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kitchen")
            .searchable(text: $search, prompt: "Search your kitchen")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                        Picker("Show", selection: $filter) {
                            Label("All Items", systemImage: "square.stack").tag(Category?.none)
                            ForEach(Category.allCases) { category in
                                Label(category.name, systemImage: category.symbol).tag(Optional(category))
                            }
                        }
                    } label: {
                        Image(systemName: filter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter by category")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingHousehold = true
                    } label: {
                        Image(systemName: store.share == nil ? "person.2" : "person.2.fill")
                    }
                    .accessibilityLabel("Household")
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                }
            }
            .overlay {
                if kitchenItems.isEmpty {
                    ContentUnavailableView {
                        Label("Your Kitchen Is Empty", systemImage: "barcode.viewfinder")
                    } description: {
                        Text("Scan the barcode on a tin, jar or packet to add it. Start with the cupboard you use most.")
                    } actions: {
                        Button("Scan Your First Item", action: onScan)
                            .buttonStyle(.borderedProminent)
                    }
                } else if visibleItems.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView(
                            "Nothing in \(filter?.name ?? "Your Kitchen")",
                            systemImage: filter?.symbol ?? "tray",
                            description: Text("Items you add to this category show up here.")
                        )
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NewItemView(barcode: nil)
            }
            .sheet(isPresented: $showingHousehold) {
                HouseholdView()
            }
        }
    }

    private func itemLink(_ item: Item) -> some View {
        NavigationLink(value: item) {
            ItemRow(item: item)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            if item.inStock {
                Button {
                    withAnimation { item.useOne() }
                } label: {
                    Label("Used One", systemImage: "minus.circle")
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { item.addOne() }
            } label: {
                Label("Add One", systemImage: "plus.circle")
            }
            .tint(.green)
        }
    }
}

#Preview {
    KitchenView(kitchen: PreviewData.kitchen, onScan: {})
        .environmentObject(PreviewData.store)
        .environment(\.managedObjectContext, PreviewData.store.context)
}
