import SwiftUI

/// Where an item lives in the kitchen.
enum Category: String, CaseIterable, Identifiable, Codable {
    case herbs, dry, tinned, fridge, freezer, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .herbs: "Herbs & Spices"
        case .dry: "Dry"
        case .tinned: "Tinned"
        case .fridge: "Fridge"
        case .freezer: "Freezer"
        case .other: "Other"
        }
    }

    /// SF Symbol shown in the coloured category tile.
    var symbol: String {
        switch self {
        case .herbs: "leaf.fill"
        case .dry: "bag.fill"
        case .tinned: "cylinder.fill"
        case .fridge: "refrigerator.fill"
        case .freezer: "snowflake"
        case .other: "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .herbs: .green
        case .dry: .orange
        case .tinned: .gray
        case .fridge: .blue
        case .freezer: .cyan
        case .other: .purple
        }
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
