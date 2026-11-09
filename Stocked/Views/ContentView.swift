import SwiftUI
import CoreData

enum AppTab: Hashable {
    case kitchen, scan, list
}

struct ContentView: View {
    @EnvironmentObject private var store: KitchenStore

    var body: some View {
        Group {
            if let kitchen = store.kitchen {
                MainTabs(kitchen: kitchen)
                    .id(kitchen.objectID)
            } else {
                ProgressView("Opening your kitchen…")
            }
        }
        .alert(item: $store.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct MainTabs: View {
    let kitchen: Kitchen
    @State private var tab: AppTab = .kitchen
    @FetchRequest private var listItems: FetchedResults<Item>

    init(kitchen: Kitchen) {
        self.kitchen = kitchen
        _listItems = FetchRequest(fetchRequest: Item.request(in: kitchen, predicate: NSPredicate(format: "onList == YES")))
    }

    var body: some View {
        TabView(selection: $tab) {
            KitchenView(kitchen: kitchen, onScan: { tab = .scan })
                .tabItem { Label("Kitchen", systemImage: "house.fill") }
                .tag(AppTab.kitchen)

            ScanView(kitchen: kitchen, isActive: tab == .scan)
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
                .tag(AppTab.scan)

            ShoppingListView(kitchen: kitchen)
                .tabItem { Label("Shopping List", systemImage: "checklist") }
                .badge(listItems.count)
                .tag(AppTab.list)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PreviewData.store)
        .environment(\.managedObjectContext, PreviewData.store.context)
}
