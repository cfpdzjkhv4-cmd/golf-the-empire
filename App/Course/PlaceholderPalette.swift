import GameCore
import UIKit

/// Flat Milestone 1 colours, taken from the prototype. Milestone 2 replaces this
/// with the shared style guide (ArtStyle) and the generated terrain textures.
enum PlaceholderPalette {
    static func colour(for tile: Tile, land: LandKind, variant: Bool) -> UIColor {
        switch tile {
        case .rough: return variant ? rough2(land) : rough(land)
        case .fairway: return UIColor(hex: variant ? 0x7AB754 : 0x74B04F)
        case .green: return UIColor(hex: 0xA3D46F)
        case .bunker: return UIColor(hex: 0xE9D8A6)
        case .water: return UIColor(hex: 0x3B7BB2)
        case .trees: return tree(land)
        case .tee: return UIColor(hex: 0xC8E6A0)
        case .sea: return UIColor(hex: 0x2E5E86)
        }
    }

    static func rough(_ land: LandKind) -> UIColor {
        switch land {
        case .links: UIColor(hex: 0x93A65C)
        case .heathland: UIColor(hex: 0x6C8046)
        case .parkland: UIColor(hex: 0x4E8A3A)
        case .moorland: UIColor(hex: 0x6F7E4A)
        }
    }

    static func rough2(_ land: LandKind) -> UIColor {
        switch land {
        case .links: UIColor(hex: 0x8A9D54)
        case .heathland: UIColor(hex: 0x647840)
        case .parkland: UIColor(hex: 0x4A8436)
        case .moorland: UIColor(hex: 0x687744)
        }
    }

    static func tree(_ land: LandKind) -> UIColor {
        switch land {
        case .links: UIColor(hex: 0x5F6B2C)
        case .heathland: UIColor(hex: 0x22472A)
        case .parkland: UIColor(hex: 0x2B5626)
        case .moorland: UIColor(hex: 0x3D5530)
        }
    }

    /// Hole rating colours: poor to masterpiece.
    static func rating(_ score: Double) -> UIColor {
        switch score {
        case ..<0.1: UIColor.systemGray
        case ..<4: UIColor(hex: 0xB5523B)
        case ..<5.5: UIColor(hex: 0xC98A2B)
        case ..<6.5: UIColor(hex: 0x8DA33A)
        case ..<7.5: UIColor(hex: 0x3F8F4A)
        default: UIColor(hex: 0xC9971A)
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
