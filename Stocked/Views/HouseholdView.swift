import SwiftUI
import CloudKit

/// Share the kitchen with the people you live with.
struct HouseholdView: View {
    @EnvironmentObject private var store: KitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var opening = false

    private var people: [CKShare.Participant] {
        store.share?.participants.filter { $0.acceptanceStatus != .removed } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(Color.accentColor.gradient, in: Circle())
                        Text(store.isParticipant ? "Shared Kitchen" : "Share Your Kitchen")
                            .font(.title2.weight(.semibold))
                        Text(store.isParticipant
                             ? "You're using \(store.ownerName ?? "someone")'s kitchen. Everything you scan, use or tick off is shared."
                             : "Everyone you invite sees the same kitchen and shopping list, and can scan, use and tick things off. Changes sync through iCloud.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if !people.isEmpty {
                    Section("People") {
                        ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                            ParticipantRow(person: person)
                        }
                    }
                }

                Section {
                    Button {
                        opening = true
                        Task {
                            await store.manageSharing()
                            opening = false
                        }
                    } label: {
                        HStack {
                            Label(store.share == nil ? "Invite Someone" : "Manage People", systemImage: store.share == nil ? "person.badge.plus" : "person.2.badge.gearshape")
                            Spacer()
                            if opening { ProgressView() }
                        }
                    }
                    .disabled(opening)
                } footer: {
                    if store.isParticipant {
                        Text("To leave this kitchen, tap Manage People, then Remove Me. You'll go back to your own kitchen.")
                    } else {
                        Text("Invitations are sent with Messages, Mail or a link. Each person needs an iPhone signed in to iCloud.")
                    }
                }
            }
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ParticipantRow: View {
    let person: CKShare.Participant

    private var name: String {
        if let components = person.userIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !formatted.isEmpty { return formatted }
        }
        return person.userIdentity.lookupInfo?.emailAddress
            ?? person.userIdentity.lookupInfo?.phoneNumber
            ?? "Invited person"
    }

    private var status: String {
        if person.role == .owner { return "Owner" }
        switch person.acceptanceStatus {
        case .accepted: return "Joined"
        case .pending: return "Invited"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(name)
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
    }
}
