import SwiftUI
import SwiftData

struct KitchenView: View {
    var onScan: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Item.name) private var allItems: [Item]
    @State private var search = ""
    @State private var filter: Category?
    @State private var showingAdd = false

    private var kitchenItems: [Item] { allItems.filter(\.showsInKitchen) }

    private var visibleItems: [Item] {
        kitchenItems.filter { item in
            (filter == nil || item.category == filter)
                && (search.isEmpty
                    || item.name.localizedCaseInsensitiveContains(search)
                    || item.barcode.contains(search))
        }
    }

    private var summary: String {
        let inStock = kitchenItems.filter(\.inStock).count
        let runOut = kitchenItems.count - inStock
        return runOut > 0 ? "\(inStock) in stock · \(runOut) run out" : "\(inStock) in stock"
    }

    var body: some View {
        NavigationStack {
            List {
                if !kitchenItems.isEmpty && search.isEmpty {
                    Section {
                    } header: {
                        Text(summary)
                            .textCase(nil)
                    }
                }
                ForEach(Category.allCases) { category in
                    let rows = visibleItems.filter { $0.category == category }
                    if !rows.isEmpty {
                        Section(category.name) {
                            ForEach(rows) { item in
                                NavigationLink(value: item) {
                                    ItemRow(item: item)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(item)
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
                    }
                }
            }
            .navigationTitle("Kitchen")
            .searchable(text: $search, prompt: "Search your kitchen")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                ToolbarItem(placement: .topBarTrailing) {
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
        }
    }
}

#Preview {
    KitchenView(onScan: {})
        .modelContainer(PreviewData.container)
}
