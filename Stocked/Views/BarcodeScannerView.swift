import SwiftUI
import VisionKit
import Vision

/// Live camera barcode scanner, using Apple's built-in DataScanner.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var isScanning: Bool
    var onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .itf14, .code39])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        if isScanning, !scanner.isScanning {
            context.coordinator.resumedAt = .now
            do {
                try scanner.startScanning()
            } catch {
                // The view may not be on screen yet; try once more shortly.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    try? scanner.startScanning()
                }
            }
        } else if !isScanning, scanner.isScanning {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        var resumedAt = Date.distantPast
        private var lastCode: String?
        private var lastEmit = Date.distantPast

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems, tapped: false)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item], tapped: true)
        }

        private func handle(_ items: [RecognizedItem], tapped: Bool) {
            for item in items {
                guard case .barcode(let barcode) = item,
                      let value = barcode.payloadStringValue, !value.isEmpty
                else { continue }

                // After a result sheet closes, the same barcode is often still in view.
                // Wait a moment before reporting it again so the sheet doesn't pop straight back.
                let now = Date.now
                let tooSoon = now.timeIntervalSince(resumedAt) < 2.5 || now.timeIntervalSince(lastEmit) < 2.5
                if !tapped, value == lastCode, tooSoon { return }

                lastCode = value
                lastEmit = now
                onScan(value)
                return
            }
        }
    }
}
