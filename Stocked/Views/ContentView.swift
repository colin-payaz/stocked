import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case kitchen, scan, list
}

struct ContentView: View {
    @State private var tab: AppTab = .kitchen
    @Query(filter: #Predicate<Item> { $0.onList == true }) private var listItems: [Item]

    var body: some View {
        TabView(selection: $tab) {
            KitchenView(onScan: { tab = .scan })
                .tabItem { Label("Kitchen", systemImage: "house.fill") }
                .tag(AppTab.kitchen)

            ScanView(isActive: tab == .scan)
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
                .tag(AppTab.scan)

            ShoppingListView()
                .tabItem { Label("Shopping List", systemImage: "checklist") }
                .badge(listItems.count)
                .tag(AppTab.list)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
