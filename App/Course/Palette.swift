import CourseArt
import SwiftUI
import UIKit

/// UI colours from the shared style guide (style.json), so the screens match the course art.
enum Palette {
    static let style = ArtStyle.shared

    /// Hole and course rating colours, poor to masterpiece.
    static func rating(_ score: Double) -> Color {
        score <= 0 ? Color.gray : Color(style.rating(score))
    }

    static var gold: Color { Color(style.gold) }
    static var ink: Color { Color(style.ink) }
    static var accent: Color { Color(style.accent) }
}

extension Color {
    init(_ c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
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
