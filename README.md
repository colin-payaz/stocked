# Stocked

An iPhone app for keeping track of the food in your kitchen. Scan a barcode to see whether you already have something, sort your food into Herbs & Spices, Dry, Tinned, Fridge and Freezer, and keep a shopping list that fills itself when you run out.

Built with SwiftUI and SwiftData. It needs iOS 17 or later and no third-party code.

## What it does

- **Scan:** a live camera scanner (Apple's VisionKit). When it spots a barcode you get:
  - **"You have 2 at home"** if it's already in your kitchen, with buttons for *Bought One*, *Used One* and *Add to Shopping List*.
  - **"Not in your kitchen"** if it's new. The name and category are filled in from [Open Food Facts](https://world.openfoodfacts.org), a free product database, and you can change them before adding.
  - You can also type the number under the barcode, or add things that have no barcode.
- **Kitchen:** everything you have, grouped by category, with search and a category filter. Swipe right to add one, or swipe left for *Used One* and *Delete*. Tap an item to edit it.
- **Shopping List:** using the last of something puts it on the list automatically. Tick items off as you shop and each one goes back into your kitchen. Share the list by text or WhatsApp with the share button.

## Run it on your iPhone

You need a Mac with **Xcode 16 or newer** (free from the Mac App Store).

1. Clone this repository on your Mac (or download it with Code › Download ZIP) and double-click **`Stocked.xcodeproj`**.
2. In Xcode, click **Stocked** at the top of the left sidebar, then the **Signing & Capabilities** tab.
3. Under **Team**, choose your Apple ID. If it isn't listed, choose *Add an Account…* and sign in. A free Apple ID works.
4. Change **Bundle Identifier** from `com.example.Stocked` to something unique to you, such as `com.yourname.Stocked`.
5. Plug your iPhone into the Mac and pick it from the device menu at the top of the Xcode window.
6. Press **⌘R** (Run).
7. The first time only:
   - On the iPhone, turn on **Settings › Privacy & Security › Developer Mode** and restart the phone when asked.
   - Go to **Settings › General › VPN & Device Management**, then trust your developer certificate.

The scanner needs a real iPhone. In the Simulator, use *Type Number* instead.

**Free Apple ID vs paid developer account:** with a free Apple ID the app stops opening after 7 days, and you run it from Xcode again to refresh it. The Apple Developer Program ($99/year) removes that limit. It also lets you use TestFlight to put the app on family members' phones, and is needed for the App Store and iCloud sync.

## Project layout

```
Stocked/
  StockedApp.swift            App entry and data store
  Models/Item.swift           A food item: name, barcode, category, quantity, on-list
  Models/Category.swift       The categories, their icons and colours
  Services/ProductLookup.swift  Barcode → product name via Open Food Facts
  Views/ContentView.swift     The three tabs
  Views/KitchenView.swift     Kitchen list, search, filter
  Views/ScanView.swift        Camera screen and scan results
  Views/BarcodeScannerView.swift  Wraps Apple's DataScannerViewController
  Views/NewItemView.swift     Add a new item
  Views/FoundItemView.swift   "You have this" sheet
  Views/ItemDetailView.swift  Edit an item
  Views/ShoppingListView.swift  Shopping list
  Views/Components.swift      Category tiles, rows, headers, preview data
```

## Ideas for next steps

- iCloud sync, so your phone, iPad and partner's phone share one kitchen. The data model is already set up for it, and it needs the paid developer account.
- Best-before dates and a "use soon" list.
- Your own categories, such as Baking or Garage Freezer.
- A "running low" level so items join the list before they run out.
- A home-screen widget showing the shopping list.
