import SwiftUI
import CoreData
import VisionKit
import AVFoundation

struct ScannedCode: Identifiable {
    let id = UUID()
    let code: String
    let item: Item?
}

enum ScanMode: String, CaseIterable, Identifiable {
    case kitchen, shop
    var id: String { rawValue }
    var title: String { self == .kitchen ? "At Home" : "At the Shop" }
}

struct ScanView: View {
    let kitchen: Kitchen
    /// Whether the Scan tab is on screen. The camera only runs while it is.
    let isActive: Bool

    @EnvironmentObject private var store: KitchenStore
    @FetchRequest private var items: FetchedResults<Item>
    @AppStorage("scanMode") private var mode: ScanMode = .kitchen
    @State private var scanned: ScannedCode?
    @State private var shopResult: ShopResult?
    @State private var newFromShop: ScannedCode?
    @State private var camera: CameraState = .checking
    @State private var showingManualEntry = false
    @State private var manualCode = ""
    @State private var showingNoBarcode = false
    @State private var haveCount = 0
    @State private var needCount = 0

    enum CameraState {
        case checking, ready, denied, unsupported
    }

    init(kitchen: Kitchen, isActive: Bool) {
        self.kitchen = kitchen
        self.isActive = isActive
        _items = FetchRequest(fetchRequest: Item.request(in: kitchen))
    }

    private var scannerShouldRun: Bool {
        // In Shop mode the camera keeps going between scans so you can work down the aisle.
        isActive && scanned == nil && newFromShop == nil && !showingManualEntry && !showingNoBarcode
    }

    var body: some View {
        ZStack {
            switch camera {
            case .checking:
                Color.black.ignoresSafeArea()
            case .ready:
                BarcodeScannerView(isScanning: scannerShouldRun) { code in
                    handle(code)
                }
                .ignoresSafeArea()
            case .denied:
                ContentUnavailableView {
                    Label("Camera Access Is Off", systemImage: "camera.fill")
                } description: {
                    Text("Turn on camera access for Stocked in Settings to scan barcodes. You can still type the number.")
                } actions: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .unsupported:
                ContentUnavailableView(
                    "Scanning Isn't Available",
                    systemImage: "barcode.viewfinder",
                    description: Text("This device can't scan with the camera. Type the number under the barcode instead.")
                )
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Where are you?", selection: $mode) {
                ForEach(ScanMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 8)
            .onChange(of: mode) { _, _ in shopResult = nil }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let shopResult {
                    ShopResultCard(result: shopResult, onUndo: undo, onAction: shopAction, onClose: { withAnimation { self.shopResult = nil } })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                controls
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .animation(.snappy, value: shopResult?.id)
        }
        .sensoryFeedback(.success, trigger: haveCount)
        .sensoryFeedback(.warning, trigger: needCount)
        .task { await checkCamera() }
        .sheet(item: $scanned) { result in
            Group {
                if let item = result.item {
                    FoundItemView(item: item)
                        .presentationDetents([.medium, .large])
                } else {
                    NewItemView(barcode: result.code)
                        .presentationDetents([.large])
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $newFromShop) { result in
            NewItemView(barcode: result.code)
        }
        .sheet(isPresented: $showingNoBarcode) {
            NewItemView(barcode: nil)
        }
        .alert("Enter Barcode", isPresented: $showingManualEntry) {
            TextField("Digits under the barcode", text: $manualCode)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { manualCode = "" }
            Button("Look Up") {
                let code = manualCode.filter(\.isNumber)
                manualCode = ""
                if !code.isEmpty { handle(code) }
            }
        } message: {
            Text("Type the numbers printed under the barcode.")
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if camera == .ready, shopResult == nil {
                Label(mode == .shop ? "Scan things as you pick them up" : "Point your camera at a barcode", systemImage: "barcode")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            HStack(spacing: 12) {
                Button {
                    showingManualEntry = true
                } label: {
                    Label("Type Number", systemImage: "keyboard")
                }
                if mode == .kitchen {
                    Button {
                        showingNoBarcode = true
                    } label: {
                        Label("No Barcode", systemImage: "plus")
                    }
                }
            }
            .buttonStyle(OverlayButtonStyle())
        }
    }

    // MARK: - Handling scans

    @MainActor
    private func handle(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = items.first { Barcode.matches($0.barcode, code) }
        switch mode {
        case .kitchen:
            haveCount += 1
            scanned = ScannedCode(code: code, item: match)
        case .shop:
            handleAtShop(code: code, item: match)
        }
    }

    /// At the shop: answer "do I need this?" at a glance, and tick it off the list if it's on there.
    @MainActor
    private func handleAtShop(code: String, item: Item?) {
        guard let item else {
            needCount += 1
            shopResult = ShopResult(kind: .unknown, code: code, item: nil, name: nil)
            Task {
                let info = await ProductLookup.lookup(code)
                if shopResult?.code == code { shopResult?.name = info?.name }
            }
            return
        }
        if item.onList {
            let before = item.quantity
            item.addOne()
            haveCount += 1
            shopResult = ShopResult(kind: .tickedOff(previousQuantity: before), code: code, item: item, name: item.displayName)
        } else if item.inStock {
            haveCount += 1
            shopResult = ShopResult(kind: .haveIt, code: code, item: item, name: item.displayName)
        } else {
            needCount += 1
            shopResult = ShopResult(kind: .runOut, code: code, item: item, name: item.displayName)
        }
    }

    @MainActor
    private func undo() {
        guard let result = shopResult, case .tickedOff(let before) = result.kind, let item = result.item else { return }
        item.quantity = before
        item.onList = true
        withAnimation { shopResult = nil }
    }

    @MainActor
    private func shopAction() {
        guard let result = shopResult else { return }
        switch result.kind {
        case .haveIt, .runOut:
            result.item?.addOne()
            withAnimation { shopResult = nil }
        case .unknown:
            newFromShop = ScannedCode(code: result.code, item: nil)
            shopResult = nil
        case .tickedOff:
            break
        }
    }

    @MainActor
    private func checkCamera() async {
        guard DataScannerViewController.isSupported else {
            camera = .unsupported
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .ready
        case .notDetermined:
            camera = await AVCaptureDevice.requestAccess(for: .video) ? .ready : .denied
        default:
            camera = .denied
        }
    }
}

// MARK: - Shop mode result

struct ShopResult: Identifiable {
    enum Kind {
        case tickedOff(previousQuantity: Int64)
        case haveIt
        case runOut
        case unknown
    }

    let id = UUID()
    let kind: Kind
    let code: String
    let item: Item?
    var name: String?
}

struct ShopResultCard: View {
    let result: ShopResult
    var onUndo: () -> Void
    var onAction: () -> Void
    var onClose: () -> Void

    private var style: (symbol: String, color: Color, title: String, detail: String, action: String?) {
        let name = result.name ?? "This item"
        switch result.kind {
        case .tickedOff:
            return ("checkmark", .green, "Ticked Off", "\(name) is off your list and in your kitchen.", nil)
        case .haveIt:
            let count = result.item?.quantity ?? 0
            return ("house.fill", .green, "You Have \(count) at Home", "\(name). You probably don't need more.", "Buying Anyway")
        case .runOut:
            return ("cart.fill", .orange, "Buy It", "You've run out of \(name).", "Bought It")
        case .unknown:
            return ("questionmark", .orange, "Not in Your Kitchen", result.name ?? "Looking it up…", "Bought It, Add to Kitchen")
        }
    }

    var body: some View {
        let style = style
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: style.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(style.color.gradient, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title)
                        .font(.title3.weight(.bold))
                    Text(style.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }
            if case .tickedOff = result.kind {
                Button("Undo", action: onUndo)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let action = style.action {
                Button(action: onAction) {
                    Text(action).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// Frosted buttons that sit over the camera picture.
struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
