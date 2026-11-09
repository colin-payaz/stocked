import SwiftUI
import SwiftData

/// Shown when a scanned barcode is already in the kitchen.
struct FoundItemView: View {
    let item: Item
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StatusHeader(
                        symbol: item.inStock ? "checkmark" : "exclamationmark",
                        color: item.inStock ? .green : .orange,
                        title: item.inStock ? "You Have \(item.quantity) at Home" : "You've Run Out",
                        subtitle: "\(item.name) · \(item.category.name)"
                    )
                    .listRowBackground(Color.clear)
                } footer: {
                    if item.onList {
                        Text("Already on your shopping list.")
                            .frame(maxWidth: .infinity)
                    }
                }

                Section {
                    Button {
                        item.addOne()
                        dismiss()
                    } label: {
                        Label("Bought One, Add to Kitchen", systemImage: "plus.circle.fill")
                    }

                    Button {
                        item.useOne()
                        dismiss()
                    } label: {
                        Label("Used One", systemImage: "minus.circle.fill")
                    }
                    .disabled(!item.inStock)

                    Button {
                        item.onList = true
                        item.touch()
                        dismiss()
                    } label: {
                        Label("Add to Shopping List", systemImage: "cart.badge.plus")
                    }
                    .disabled(item.onList)
                }

                Section {
                    NavigationLink("Edit Item") {
                        ItemDetailView(item: item)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
