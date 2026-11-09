# Stocked

An iPhone app for keeping track of the food in your kitchen. Scan a barcode to see whether you already have something, sort your food into Herbs & Spices, Dry, Tinned, Fridge and Freezer, and keep a shopping list that fills itself when you run out.

Built with SwiftUI, Core Data and CloudKit. It needs iOS 17 or later and has no third-party code.

## What it does

- **Scan, at home:** a live camera scanner (Apple's VisionKit). It shows **"You have 2 at home"** with *Bought One*, *Used One* and *Add to Shopping List*, or **"Not in your kitchen"** with the name and category filled in from [Open Food Facts](https://world.openfoodfacts.org). You can also type the number, or add things with no barcode.
- **Scan, at the shop:** switch the Scan tab to *At the Shop* and keep scanning as you go. Each scan gives a quick answer: *You have 3 at home*, *Buy it*, or *Ticked off* (if it was on your list, it's ticked off and added to your kitchen, with Undo).
- **Kitchen:** everything you have, grouped by category, with search and a filter. Food near its best-before date appears at the top under *Use Soon*. Swipe an item for *Add One*, *Used One* or *Delete*.
- **Best-before dates:** optional for each item, with a reminder at 9am the day before.
- **Keep at least:** set a minimum, such as 2 tins of tomatoes, and the item joins the shopping list as soon as you drop below it.
- **Shopping List:** fills itself when you run out or get low. Tick items off and they go back into your kitchen. You can share the list as text.
- **Household:** tap the people icon in Kitchen to invite others through iCloud. Everyone sees and updates the same kitchen and list.
- **Widget:** your shopping list on the home screen and lock screen.

## Run it on your iPhone

You need a Mac with **Xcode 16 or newer**.

1. Clone this repository, or download it with *Code › Download ZIP*, then open **`Stocked.xcodeproj`**.
2. Click **Stocked** at the top of the left sidebar. For **both** targets (*Stocked* and *StockedWidget*), open **Signing & Capabilities** and choose your team under **Team**.
3. If Xcode says a bundle identifier is taken, change `com.payaz` to something of your own in **every** place it appears: both bundle identifiers, the iCloud container (`iCloud.com.payaz.Stocked`) and the app group (`group.com.payaz.Stocked`). Those also appear in `Config/*.entitlements`, `Stocked/Store/Persistence.swift` and `Shared/WidgetSnapshot.swift`.
4. In the *Stocked* target's **Signing & Capabilities**:
   - **iCloud:** make sure *CloudKit* is ticked and the container `iCloud.com.payaz.Stocked` is ticked. If it's red, press the refresh button under the list so Xcode creates it.
   - **App Groups:** make sure `group.com.payaz.Stocked` is ticked. Do the same on the *StockedWidget* target.
5. Plug in your iPhone, choose it at the top of the Xcode window and press **⌘R**. On a new phone, turn on **Settings › Privacy & Security › Developer Mode** first.
6. On the phone, make sure you're signed in to iCloud and **Settings › [your name] › iCloud › Saved to iCloud** lets Stocked use iCloud.

The scanner needs a real iPhone. In the Simulator, use *Type Number* instead.

### Before TestFlight or the App Store

Builds you run from Xcode use the CloudKit **Development** environment. TestFlight and App Store builds use **Production**. Before your first TestFlight build:

1. Run the app from Xcode, add a few items and share the kitchen once. That creates the record types in Development.
2. Open [CloudKit Console](https://icloud.developer.apple.com), choose `iCloud.com.payaz.Stocked`, and click **Deploy Schema Changes…** to copy the schema to Production.

Do this again whenever the data model changes.

### Inviting your household

1. In **Kitchen**, tap the people icon, then **Invite Someone**, and send the link with Messages or Mail.
2. Each person installs Stocked (through TestFlight is easiest) and taps the link. The app opens and joins the shared kitchen. Anything they'd already logged is merged in.
3. To stop sharing, or to leave a kitchen, tap **Manage People**.

## How the code is checked

Every push to GitHub runs `.github/workflows/build.yml` on a Mac in the cloud. It builds the app and widget for the iOS Simulator, launches the app with sample data (`-demoData YES -disableCloudSync YES`) and takes screenshots in light and dark mode. The screenshots are pushed to the `ci-screenshots` branch.

## Project layout

```
Stocked/
  App/                        App entry, app and scene delegates (share invitations)
  Models/Item.swift           Kitchen and Item: the data that syncs
  Models/StockedModel.swift   The Core Data model, defined in code
  Store/Persistence.swift     Private and shared iCloud stores
  Store/KitchenStore.swift    Current kitchen, autosave, stock rules, sharing
  Store/Reminders.swift       Best-before notifications
  Views/HouseholdView.swift   Invite and manage people
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
Shared/                       Used by both the app and the widget
  Category.swift              The categories, their icons and colours
  WidgetSnapshot.swift        Shopping list copy the widget reads
StockedWidget/                Home-screen and lock-screen widget
Config/                       Info.plist additions and entitlements
prototype/                    The first web prototype
```

## Ideas for next steps

- Your own categories, such as Baking or Garage Freezer.
- Siri and Shortcuts: "Do I have chickpeas?"
- Recipes: see what you can cook with what's in the kitchen.
- An App Store listing: screenshots, description and privacy details.
