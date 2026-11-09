import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.name) private var items: [Item]
    @State private var newName = ""
    @State private var ticked: Set<PersistentIdentifier> = []
    @State private var tickCount = 0
    @FocusState private var addFieldFocused: Bool

    private var onList: [Item] {
        items.filter(\.onList).sorted { ($0.category.order, $0.name) < ($1.category.order, $1.name) }
    }

    private var runOut: [Item] {
        items.filter { !$0.onList && !$0.inStock && $0.everStocked }
    }

    private var shareText: String {
        "Shopping list\n" + onList.map { "• \($0.name)" }.joined(separator: "\n")
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
                    Section {
                        ForEach(onList) { item in
                            listRow(item)
                        }
                    } footer: {
                        Text("Ticking something off adds one to your kitchen.")
                    }
                }

                if !runOut.isEmpty {
                    Section("Run Out") {
                        ForEach(runOut) { item in
                            HStack(spacing: 12) {
                                CategoryIcon(category: item.category)
                                Text(item.name)
                                Spacer()
                                Button {
                                    withAnimation {
                                        item.onList = true
                                        item.touch()
                                    }
                                } label: {
                                    Image(systemName: "cart.badge.plus")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Add \(item.name) to list")
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

    private func listRow(_ item: Item) -> some View {
        let isTicked = ticked.contains(item.persistentModelID)
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
            .accessibilityLabel("Bought \(item.name)")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(isTicked)
                    .foregroundStyle(isTicked ? .secondary : .primary)
                Text(item.inStock ? "You have \(item.quantity) at home" : item.category.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        let id = item.persistentModelID
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
            context.delete(item)
        } else {
            item.onList = false
            item.touch()
        }
    }

    private func addTypedItem() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = items.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            existing.onList = true
            existing.touch()
        } else {
            context.insert(Item(name: name, category: .other, quantity: 0, onList: true))
        }
        newName = ""
        addFieldFocused = true
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(PreviewData.container)
}
