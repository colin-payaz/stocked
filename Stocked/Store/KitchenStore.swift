import CoreData
import CloudKit
import UIKit

/// Owns the current kitchen, saves changes, applies the stock rules, and
/// handles sharing the kitchen with a household through iCloud.
@MainActor
final class KitchenStore: NSObject, ObservableObject {
    static let shared = KitchenStore(persistence: .shared)

    let persistence: PersistenceController
    @Published private(set) var kitchen: Kitchen?
    @Published private(set) var share: CKShare?
    /// A message to show the user, such as a sharing problem.
    @Published var notice: Notice?

    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var context: NSManagedObjectContext { persistence.container.viewContext }

    /// True when this kitchen belongs to someone else who shared it with you.
    var isParticipant: Bool {
        guard let kitchen, let sharedStore = persistence.sharedStore else { return false }
        return kitchen.objectID.persistentStore == sharedStore
    }

    var ownerName: String? {
        guard let identity = share?.owner.userIdentity else { return nil }
        return identity.nameComponents.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
    }

    private var saveTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private static let mergeAfterJoiningKey = "stocked.mergeAfterJoining"

    init(persistence: PersistenceController) {
        self.persistence = persistence
        super.init()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .NSPersistentStoreRemoteChange, object: persistence.container.persistentStoreCoordinator, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: persistence.container.viewContext, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSave() }
        })
        observers.append(center.addObserver(forName: .NSManagedObjectContextWillSave, object: persistence.container.viewContext, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyStockRules() }
        })
        refresh()
    }

    // MARK: - Kitchen

    /// Picks the kitchen to show: a shared one if you've joined a household,
    /// otherwise your own (created on first launch).
    func refresh() {
        let request = NSFetchRequest<Kitchen>(entityName: "Kitchen")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let kitchens = (try? context.fetch(request)) ?? []
        let joined = kitchens.filter { $0.objectID.persistentStore == persistence.sharedStore }
        let mine = kitchens.filter { $0.objectID.persistentStore == persistence.privateStore }

        let chosen: Kitchen
        if let sharedKitchen = joined.first {
            chosen = sharedKitchen
            if UserDefaults.standard.bool(forKey: Self.mergeAfterJoiningKey) {
                UserDefaults.standard.set(false, forKey: Self.mergeAfterJoiningKey)
                move(itemsFrom: mine, into: sharedKitchen)
            }
        } else if let first = mine.first {
            chosen = first
            // Two devices on one Apple ID can each create a kitchen before they sync. Merge them.
            for extra in mine.dropFirst() {
                for item in extra.itemsArray { item.kitchen = first }
                context.delete(extra)
            }
        } else {
            guard let privateStore = persistence.privateStore else { return }
            let created = Kitchen(context: context)
            context.assign(created, to: privateStore)
            created.uuid = UUID()
            created.name = "My Kitchen"
            created.createdAt = .now
            chosen = created
        }
        save()

        if kitchen != chosen { kitchen = chosen }
        share = (try? persistence.container.fetchShares(matching: [chosen.objectID]))?[chosen.objectID]
    }

    /// Items currently in the kitchen.
    func allItems() -> [Item] {
        guard let kitchen else { return [] }
        return (try? context.fetch(Item.request(in: kitchen))) ?? []
    }

    @discardableResult
    func newItem(name: String, barcode: String = "", category: Category, quantity: Int64, onList: Bool = false, bestBefore: Date? = nil) -> Item? {
        guard let kitchen else { return nil }
        return makeItem(in: kitchen, name: name, barcode: barcode, category: category, quantity: quantity, onList: onList, bestBefore: bestBefore)
    }

    func delete(_ item: Item) {
        context.delete(item)
        save()
    }

    private func makeItem(in kitchen: Kitchen, name: String, barcode: String, category: Category, quantity: Int64, onList: Bool, bestBefore: Date?) -> Item {
        let item = Item(context: context)
        if let store = kitchen.objectID.persistentStore {
            context.assign(item, to: store)
        }
        item.uuid = UUID()
        item.name = name
        item.barcode = barcode
        item.category = category
        item.quantity = quantity
        item.onList = onList
        item.everStocked = quantity > 0
        item.bestBefore = bestBefore
        item.createdAt = .now
        item.updatedAt = .now
        item.kitchen = kitchen
        return item
    }

    /// After joining a household, bring the food you'd already logged into the shared kitchen.
    private func move(itemsFrom kitchens: [Kitchen], into target: Kitchen) {
        let existing = target.itemsArray
        for source in kitchens {
            for old in source.itemsArray {
                let match = existing.first { (Barcode.matches($0.barcode, old.barcode)) || (!old.name.isEmpty && $0.name.caseInsensitiveCompare(old.name) == .orderedSame) }
                if let match {
                    match.quantity += old.quantity
                    match.onList = match.onList || old.onList
                    match.everStocked = match.everStocked || old.everStocked
                } else {
                    let copy = makeItem(in: target, name: old.name, barcode: old.barcode, category: old.category, quantity: old.quantity, onList: old.onList, bestBefore: old.bestBefore)
                    copy.minQuantity = old.minQuantity
                    copy.everStocked = old.everStocked
                }
                context.delete(old)
            }
        }
    }

    // MARK: - Saving

    private func scheduleSave() {
        guard context.hasChanges else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Stocked: save failed: \(error)")
        }
        let items = allItems()
        Reminders.sync(items)
        WidgetSnapshot.write(items)
    }

    /// Runs just before every save, so the rules hold however an item was changed.
    private func applyStockRules() {
        let changed = context.insertedObjects.union(context.updatedObjects).compactMap { $0 as? Item }
        for item in changed {
            let values = item.changedValues()
            guard !values.isEmpty else { continue }

            if values["quantity"] != nil {
                let before = (item.committedValues(forKeys: ["quantity"])["quantity"] as? Int64) ?? item.quantity
                // Used the last one, or dropped below the minimum: add it to the list.
                if item.quantity < before, item.quantity < max(1, item.minQuantity) {
                    item.onList = true
                }
            }
            if values["minQuantity"] != nil, item.minQuantity > 0, item.quantity < item.minQuantity {
                item.onList = true
            }
            if item.quantity > 0, !item.everStocked {
                item.everStocked = true
            }
            if values["updatedAt"] == nil {
                item.updatedAt = .now
            }
        }
    }

    // MARK: - Sharing

    /// Opens Apple's sharing sheet to invite people, or to manage who's in the kitchen.
    func manageSharing() async {
        guard let kitchen else { return }
        save()
        do {
            let activeShare: CKShare
            if let share {
                activeShare = share
            } else {
                let (_, newShare, _) = try await persistence.container.share([kitchen], to: nil)
                activeShare = newShare
                share = newShare
            }
            let controller = UICloudSharingController(share: activeShare, container: CKContainer(identifier: PersistenceController.cloudKitContainerID))
            controller.delegate = self
            controller.availablePermissions = [.allowReadWrite, .allowPrivate]
            Self.topViewController()?.present(controller, animated: true)
        } catch {
            notice = Notice(title: "Couldn't Start Sharing", message: "Check that you're signed in to iCloud in Settings and connected to the internet, then try again.")
        }
    }

    /// Called when someone taps an invitation link.
    func accept(_ metadata: CKShare.Metadata) async {
        guard let sharedStore = persistence.sharedStore else { return }
        UserDefaults.standard.set(true, forKey: Self.mergeAfterJoiningKey)
        do {
            _ = try await persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore)
            notice = Notice(title: "You've Joined the Kitchen", message: "The shared kitchen can take a minute to appear. Anything you'd already logged will be added to it.")
            refresh()
        } catch {
            UserDefaults.standard.set(false, forKey: Self.mergeAfterJoiningKey)
            notice = Notice(title: "Couldn't Join", message: "The invitation couldn't be opened. Ask for a new invitation and try again.")
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension KitchenStore: UICloudSharingControllerDelegate {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        notice = Notice(title: "Couldn't Share", message: "Your invitation wasn't sent. Check your internet connection and try again.")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Our Kitchen"
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        UIImage(named: "AppIcon")?.pngData()
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        refresh()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        share = nil
        refresh()
    }
}
