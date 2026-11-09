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
        #if DEBUG
        // Lets the Simulator screenshots open on a chosen tab: -startTab list
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "list": _tab = State(initialValue: .list)
        case "scan": _tab = State(initialValue: .scan)
        default: break
        }
        #endif
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
        .onOpenURL { url in
            // stocked://list and stocked://scan, used by the widget.
            switch url.host {
            case "list": tab = .list
            case "scan": tab = .scan
            case "kitchen": tab = .kitchen
            default: break
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PreviewData.store)
        .environment(\.managedObjectContext, PreviewData.store.context)
}
