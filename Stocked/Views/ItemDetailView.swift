import SwiftUI
import SwiftData

/// Edit one item. Changes save as you make them.
struct ItemDetailView: View {
    @Bindable var item: Item
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

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
                Toggle("On shopping list", isOn: $item.onList)
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
                Text("Added \(item.createdAt.formatted(date: .abbreviated, time: .omitted)) · updated \(item.updatedAt.formatted(.relative(presentation: .named)))")
            }
        }
        .navigationTitle(item.name.isEmpty ? "Item" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.increase, trigger: item.quantity)
        .onChange(of: item.quantity) { _, newValue in
            if newValue > 0 { item.everStocked = true }
            item.touch()
        }
        .onChange(of: item.onList) { _, _ in item.touch() }
        .confirmationDialog("Delete \(item.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let doomed = item
                dismiss()
                // Delete after the screen has gone so it never shows a removed item.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    context.delete(doomed)
                }
            }
        } message: {
            Text("It will be removed from your kitchen and your shopping list.")
        }
    }
}
