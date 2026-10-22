import Foundation
import GameCore

/// A colour in sRGB, 0 to 1.
public struct RGBA: Equatable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// "#86BA55"
    public init(hex: String, opacity: Double = 1) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt32(digits, radix: 16) ?? 0
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255, a: opacity)
    }

    public func opacity(_ a: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: a) }

    /// "#RRGGBB", for SVG previews.
    public var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// The shared style guide, loaded from style.json. Every art generator and the renderer read it.
public struct ArtStyle: Sendable {
    public struct Land: Decodable, Sendable {
        public let rough: String
        public let roughMottle: String
        public let deepRough: String
        public let tree: String
        public let treeLight: String
        public let flower: String
    }

    private struct File: Decodable {
        struct Shadow: Decodable { let colour: String; let opacity: Double; let offsetX: Double; let offsetY: Double }
        struct Grain: Decodable { let opacity: Double }
        struct UI: Decodable { let ink: String; let paper: String; let paperDark: String; let accent: String; let gold: String; let rating: [String] }
        let shadow: Shadow
        let grain: Grain
        let terrain: [String: String]
        let lands: [String: Land]
        let ui: UI
    }

    public let shadow: RGBA
    /// Where shadows fall, in tiles (light is top left, so down and right).
    public let shadowOffset: (x: Double, y: Double)
    public let grainOpacity: Double
    private let terrain: [String: String]
    private let lands: [String: Land]
    public let ratingColours: [RGBA]
    public let ink: RGBA
    public let paper: RGBA
    public let gold: RGBA
    public let accent: RGBA

    public static let shared: ArtStyle = {
        guard let url = Bundle.module.url(forResource: "style", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            fatalError("style.json is missing or unreadable")
        }
        return ArtStyle(file: file)
    }()

    private init(file: File) {
        shadow = RGBA(hex: file.shadow.colour, opacity: file.shadow.opacity)
        shadowOffset = (file.shadow.offsetX, file.shadow.offsetY)
        grainOpacity = file.grain.opacity
        terrain = file.terrain
        lands = file.lands
        ratingColours = file.ui.rating.map { RGBA(hex: $0) }
        ink = RGBA(hex: file.ui.ink)
        paper = RGBA(hex: file.ui.paper)
        gold = RGBA(hex: file.ui.gold)
        accent = RGBA(hex: file.ui.accent)
    }

    /// A terrain colour token, e.g. "fairway", "sandShade".
    public func terrain(_ token: String, opacity: Double = 1) -> RGBA {
        RGBA(hex: terrain[token] ?? "#FF00FF", opacity: opacity)
    }

    public func land(_ kind: LandKind) -> Land {
        lands[kind.rawValue] ?? lands["parkland"]!
    }

    /// Hole and course rating colour, poor to masterpiece.
    public func rating(_ score: Double) -> RGBA {
        let c = ratingColours
        guard c.count == 5 else { return ink }
        switch score {
        case ..<4: return c[0]
        case ..<5.5: return c[1]
        case ..<6.5: return c[2]
        case ..<7.5: return c[3]
        default: return c[4]
        }
    }
}
