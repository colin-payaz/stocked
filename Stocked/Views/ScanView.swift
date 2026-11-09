import SwiftUI
import SwiftData
import VisionKit
import AVFoundation

struct ScannedCode: Identifiable {
    let id = UUID()
    let code: String
    let item: Item?
}

struct ScanView: View {
    /// Whether the Scan tab is on screen. The camera only runs while it is.
    let isActive: Bool

    @Query private var items: [Item]
    @State private var scanned: ScannedCode?
    @State private var camera: CameraState = .checking
    @State private var showingManualEntry = false
    @State private var manualCode = ""
    @State private var showingNoBarcode = false
    @State private var scanCount = 0

    enum CameraState {
        case checking, ready, denied, unsupported
    }

    private var scannerShouldRun: Bool {
        isActive && scanned == nil && !showingManualEntry && !showingNoBarcode
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
        .safeAreaInset(edge: .bottom) { controls }
        .sensoryFeedback(.success, trigger: scanCount)
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
            if camera == .ready {
                Label("Point your camera at a barcode", systemImage: "barcode")
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
                Button {
                    showingNoBarcode = true
                } label: {
                    Label("No Barcode", systemImage: "plus")
                }
            }
            .buttonStyle(OverlayButtonStyle())
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func handle(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = items.first { Barcode.matches($0.barcode, code) }
        scanCount += 1
        scanned = ScannedCode(code: code, item: match)
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
