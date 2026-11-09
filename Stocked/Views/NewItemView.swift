import SwiftUI
import SwiftData

/// Add a new item, either from a scanned barcode or typed by hand.
struct NewItemView: View {
    let barcode: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: Category = .dry
    @State private var quantity = 1
    @State private var lookingUp = false
    @State private var filledFromDatabase = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                if let barcode {
                    Section {
                        StatusHeader(
                            symbol: "questionmark",
                            color: .orange,
                            title: "Not in Your Kitchen",
                            subtitle: "You don't have this one yet.",
                            code: barcode
                        )
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    HStack {
                        TextField(lookingUp ? "Looking up product…" : "e.g. Chopped tomatoes 400g", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .textInputAutocapitalization(.words)
                        if lookingUp {
                            ProgressView()
                        }
                    }
                } header: {
                    Text("Name")
                } footer: {
                    if filledFromDatabase {
                        Label("Filled in from Open Food Facts. Change it if it's wrong.", systemImage: "sparkles")
                    }
                }

                Section("Where does it live?") {
                    CategoryPicker(selection: $category)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Stepper(value: $quantity, in: 1...999) {
                        LabeledContent("How many", value: "\(quantity)")
                    }
                }

                if barcode != nil {
                    Section {
                        Button("Not Buying It Now? Add to Shopping List") {
                            save(toList: true)
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(trimmedName.isEmpty)
                    }
                }
            }
            .navigationTitle(barcode == nil ? "Add Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(toList: false) }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .task { await lookUp() }
        }
    }

    private func lookUp() async {
        guard let barcode, name.isEmpty else {
            nameFocused = true
            return
        }
        lookingUp = true
        if let info = await ProductLookup.lookup(barcode) {
            if name.isEmpty {
                name = info.name
                filledFromDatabase = true
            }
            if let guessed = info.category { category = guessed }
        }
        lookingUp = false
        if name.isEmpty { nameFocused = true }
    }

    private func save(toList: Bool) {
        guard !trimmedName.isEmpty else { return }
        let item = Item(
            name: trimmedName,
            barcode: barcode ?? "",
            category: category,
            quantity: toList ? 0 : quantity,
            onList: toList
        )
        context.insert(item)
        dismiss()
    }
}

#Preview {
    NewItemView(barcode: "5000157024671")
        .modelContainer(PreviewData.container)
}
