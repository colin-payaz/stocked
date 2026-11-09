import SwiftUI
import CoreData

@main
struct StockedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = KitchenStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.managedObjectContext, store.context)
        }
    }
}
