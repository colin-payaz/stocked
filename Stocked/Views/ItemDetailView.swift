import SwiftUI
import CoreData

/// Edit one item. Changes save as you make them.
struct ItemDetailView: View {
    @ObservedObject var item: Item
    @EnvironmentObject private var store: KitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private var hasBestBefore: Binding<Bool> {
        Binding(
            get: { item.bestBefore != nil },
            set: { on in
                if on {
                    item.bestBefore = Calendar.current.date(byAdding: .day, value: 7, to: .now)
                    Reminders.requestPermission()
                } else {
                    item.bestBefore = nil
                }
            }
        )
    }

    private var bestBefore: Binding<Date> {
        Binding(get: { item.bestBefore ?? .now }, set: { item.bestBefore = $0 })
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    CategoryIcon(category: item.category, size: 64)
                    Text(item.inStock ? "You have \(item.quantity) at home" : "You've run out")
                        .font(.title3.weight(.semibold))
                    if !item.barcode.isEmpty {
                        Text(item.barcode)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("Name", text: $item.name)
            }

            Section {
                Stepper(value: $item.quantity, in: 0...999) {
                    LabeledContent("At home", value: "\(item.quantity)")
                }
                Stepper(value: $item.minQuantity, in: 0...99) {
                    LabeledContent("Keep at least", value: item.minQuantity == 0 ? "Off" : "\(item.minQuantity)")
                }
                Toggle("On shopping list", isOn: $item.onList)
            } footer: {
                Text("With a minimum set, the item joins your shopping list as soon as you drop below it.")
            }

            Section {
                Toggle("Best-before date", isOn: hasBestBefore)
                if item.bestBefore != nil {
                    DatePicker("Best before", selection: bestBefore, displayedComponents: .date)
                }
            } footer: {
                if item.bestBefore != nil {
                    Text("You'll get a reminder the day before.")
                }
            }

            Section("Where it lives") {
                CategoryPicker(selection: $item.category)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    confirmingDelete = true
                }
                .frame(maxWidth: .infinity)
            } footer: {
                if let updated = item.updatedAt {
                    Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                }
            }
        }
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: item.quantity)
        .confirmationDialog("Delete \(item.displayName)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let doomed = item
                dismiss()
                // Delete after the screen has gone so it never shows a removed item.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    store.delete(doomed)
                }
            }
        } message: {
            Text("It will be removed from the kitchen and the shopping list for everyone in your household.")
        }
    }
}
