import CoreData
import CloudKit

/// Two stores, both synced with iCloud: your own kitchen (private database)
/// and kitchens other people have shared with you (shared database).
final class PersistenceController {
    static let shared = PersistenceController()
    static let cloudKitContainerID = "iCloud.com.payaz.Stocked"

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Stocked", managedObjectModel: StockedModel.shared)

        let directory: URL
        if inMemory {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        } else {
            directory = NSPersistentContainer.defaultDirectoryURL()
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Unsigned Simulator builds (like the screenshot run) have no iCloud entitlement,
        // and CloudKit stops the app if it tries to sync. `-disableCloudSync YES` turns sync off.
        var syncs = !inMemory
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "disableCloudSync") { syncs = false }
        #endif

        let privateURL = directory.appendingPathComponent("Stocked-private.sqlite")
        let sharedURL = directory.appendingPathComponent("Stocked-shared.sqlite")
        container.persistentStoreDescriptions = [
            Self.description(url: privateURL, scope: .private, syncs: syncs),
            Self.description(url: sharedURL, scope: .shared, syncs: syncs),
        ]

        container.loadPersistentStores { description, error in
            if let error {
                print("Stocked: couldn't open \(description.url?.lastPathComponent ?? "store"): \(error)")
            }
        }
        privateStore = container.persistentStoreCoordinator.persistentStore(for: privateURL)
        sharedStore = container.persistentStoreCoordinator.persistentStore(for: sharedURL)

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.transactionAuthor = "app"
    }

    private static func description(url: URL, scope: CKDatabase.Scope, syncs: Bool) -> NSPersistentStoreDescription {
        let description = NSPersistentStoreDescription(url: url)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        if syncs {
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
            options.databaseScope = scope
            description.cloudKitContainerOptions = options
        } else {
            description.cloudKitContainerOptions = nil
        }
        return description
    }
}
