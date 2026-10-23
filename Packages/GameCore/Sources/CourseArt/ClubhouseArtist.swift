import Foundation
import GameCore

/// The strip below the first hole: clubhouse, pro shop, range and car park, drawn to match
/// the club's facilities. Stone and slate in the north and Scotland, brick and tile in the south.
public struct ClubhouseArtist: Sendable {
    public let style: ArtStyle
    /// Rows of the club area, in tiles.
    public static let rows = 6

    public init(style: ArtStyle = .shared) {
        self.style = style
    }

    public struct Club: Sendable {
        public var clubhouse: Int
        public var shop: Int
        public var range: Int
        public var north: Bool
        public var carsParked: Int

        public init(clubhouse: Int, shop: Int, range: Int, north: Bool, carsParked: Int) {
            self.clubhouse = clubhouse
            self.shop = shop
            self.range = range
            self.north = north
            self.carsParked = carsParked
        }
    }

    /// Instructions for a `columns` wide strip, with (0, 0) at its top left.
    public func paint(_ club: Club, columns: Int, land: LandKind, seed: UInt64) -> [DrawOp] {
        let w = Double(columns), h = Double(Self.rows)
        var ops: [DrawOp] = [.clip(.rect(0, 0, w, h))]
        var rng = SeededRandom(seed: seed)

        // Mown lawn and a gravel path up to the first tee.
        ops.append(.fill(.rect(0, 0, w, h), style.terrain("firstCut")))
        for _ in 0..<40 {
            let c = ArtPoint(rng.unit() * w, rng.unit() * h)
            ops.append(.ellipse(centre: c, rx: 0.3, ry: 0.15, style.terrain("fairway", opacity: 0.35)))
        }
        ops.append(.fill(.polygon([(w / 2 - 0.35, 0), (w / 2 + 0.35, 0), (w / 2 + 0.5, 2.2), (w / 2 - 0.5, 2.2)]), style.terrain("gravel")))

        // Practice range along the left.
        if club.range > 0 {
            ops.append(.fill(.rect(0.3, 0.3, 4.4, 1.6), style.terrain("fairway")))
            for k in 0..<5 {
                ops.append(.fill(.rect(0.5 + Double(k) * 0.85, 1.35, 0.6, 0.4), style.terrain("tee")))
                ops.append(.ellipse(centre: ArtPoint(0.8 + Double(k) * 0.85, 0.8), rx: 0.05, ry: 0.05, RGBA(hex: "#FFFFFF")))
            }
            ops.append(.stroke(.rect(0.3, 0.3, 4.4, 1.6), RGBA(hex: "#3E4A3A", opacity: 0.5), width: 0.06))
        }

        // Car park on the right, fuller on busy days.
        let lotX = w - 4.6, lotY = 1.0
        ops.append(.fill(.rect(lotX, lotY, 4.3, 4.6), style.terrain("tarmac")))
        for k in 0...6 {
            let x = lotX + 0.15 + Double(k) * 0.66
            ops.append(.fill(.rect(x, lotY + 0.2, 0.04, 1.4), RGBA(hex: "#F4F0E6", opacity: 0.8)))
            ops.append(.fill(.rect(x, lotY + 3.0, 0.04, 1.4), RGBA(hex: "#F4F0E6", opacity: 0.8)))
        }
        let cars = ["#B5523B", "#2F6DB5", "#C9C3B8", "#1F1F24", "#5A5F66", "#2E6B45", "#E9DAA9", "#7B4FA8"]
        var bays: [ArtPoint] = []
        for row in [lotY + 0.9, lotY + 3.7] {
            for k in 0..<6 { bays.append(ArtPoint(lotX + 0.48 + Double(k) * 0.66, row)) }
        }
        for c in bays.prefix(min(bays.count, club.carsParked)) {
            let colour = RGBA(hex: rng.pick(cars))
            ops.append(.ellipse(centre: ArtPoint(c.x + 0.06, c.y + 0.08), rx: 0.3, ry: 0.55, style.shadow))
            ops.append(.fill(roundedRect(c.x - 0.25, c.y - 0.5, 0.5, 1.0, 0.15), colour))
            ops.append(.fill(.rect(c.x - 0.18, c.y - 0.22, 0.36, 0.18), RGBA(hex: "#3E4C59", opacity: 0.85)))
        }

        // Pro shop, bottom left.
        if club.shop > 0 {
            let sw = club.shop >= 2 ? 3.2 : 2.2
            building(&ops, x: 0.6, y: 2.7, width: sw, wall: 1.2, roofDepth: 0.9, north: club.north, windows: club.shop >= 2 ? 3 : 2, flat: club.shop < 2)
            ops.append(.fill(.rect(0.6 + sw / 2 - 0.5, 3.75, 1.0, 0.18), style.ink.opacity(0.75)))
        }

        // The clubhouse itself, growing with each level.
        switch club.clubhouse {
        case 0:
            building(&ops, x: 6.4, y: 2.8, width: 3.2, wall: 1.1, roofDepth: 0.8, north: club.north, windows: 2, flat: true, portacabin: true)
        case 1:
            building(&ops, x: 5.6, y: 2.4, width: 4.8, wall: 1.4, roofDepth: 1.4, north: club.north, windows: 3, flat: false)
        case 2:
            building(&ops, x: 4.5, y: 2.3, width: 5.4, wall: 1.5, roofDepth: 1.5, north: club.north, windows: 4, flat: false)
            // Restaurant conservatory.
            ops.append(.fill(.rect(9.95, 3.2, 0.95, 1.4), RGBA(hex: "#CFE3EA", opacity: 0.9)))
            ops.append(.stroke(.rect(9.95, 3.2, 0.95, 1.4), RGBA(hex: "#F4F0E6"), width: 0.06))
        default:
            // Chimneys behind the roof, then the house, then a central gable and a flag.
            for x in [4.5, 10.1] { ops.append(.fill(.rect(x, 0.35, 0.35, 0.6), wallColour(club.north))) }
            building(&ops, x: 4.0, y: 2.2, width: 7.0, wall: 1.7, roofDepth: 1.6, north: club.north, windows: 6, flat: false)
            ops.append(.fill(.polygon([(6.7, 2.2), (7.5, 1.2), (8.3, 2.2)]), wallColour(club.north)))
            ops.append(.stroke(.polygon([(6.6, 2.25), (7.5, 1.1), (8.4, 2.25)]), roofColour(club.north), width: 0.18))
            ops.append(.fill(.rect(7.47, 0.15, 0.06, 1.0), RGBA(hex: "#F4F0E6")))
            ops.append(.fill(.polygon([(7.53, 0.15), (8.1, 0.3), (7.53, 0.45)]), style.gold))
        }

        ops.append(.endClip)
        return ops
    }

    // MARK: Buildings, seen from the front and a little above

    private func wallColour(_ north: Bool) -> RGBA { style.terrain(north ? "stoneWall" : "brickWall") }
    private func roofColour(_ north: Bool) -> RGBA { style.terrain(north ? "slateRoof" : "tileRoof") }

    private func building(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, wall: Double, roofDepth: Double,
                          north: Bool, windows: Int, flat: Bool, portacabin: Bool = false) {
        let roofTop = y - roofDepth
        // Shadow, roof, then the front wall.
        ops.append(.fill(.rect(x + 0.2, roofTop + 0.25, width, roofDepth + wall), style.shadow))
        if flat {
            ops.append(.fill(.rect(x, roofTop, width, roofDepth), portacabin ? style.terrain("cabinRoof") : roofColour(north)))
        } else {
            ops.append(.fill(.polygon([(x - 0.15, y), (x + 0.35, roofTop), (x + width - 0.35, roofTop), (x + width + 0.15, y)]), roofColour(north)))
            ops.append(.fill(.rect(x + 0.35, roofTop + roofDepth * 0.45, width - 0.7, 0.05), RGBA(hex: "#000000", opacity: 0.15)))
        }
        let wallColour = portacabin ? style.terrain("cabinWall") : wallColour(north)
        ops.append(.fill(.rect(x, y, width, wall), wallColour))
        // Windows and a door.
        let door = width / 2
        ops.append(.fill(.rect(x + door - 0.22, y + wall - 0.75, 0.44, 0.75), style.terrain("door")))
        let spacing = width / Double(windows + 1)
        for k in 1...windows {
            var wx = x + spacing * Double(k) - 0.2
            if abs(wx + 0.2 - (x + door)) < 0.4 { wx += 0.5 }
            ops.append(.fill(.rect(wx, y + 0.3, 0.4, 0.42), style.terrain("window")))
            ops.append(.fill(.rect(wx, y + 0.3, 0.4, 0.08), RGBA(hex: "#FFFFFF", opacity: 0.35)))
        }
    }

    private func roundedRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> ArtPath {
        var pts: [ArtPoint] = []
        let corners = [(x + w - r, y + r, -Double.pi / 2), (x + w - r, y + h - r, 0.0), (x + r, y + h - r, Double.pi / 2), (x + r, y + r, Double.pi)]
        for (cx, cy, start) in corners {
            for k in 0...4 {
                let a = start + Double(k) / 4 * Double.pi / 2
                pts.append(ArtPoint(cx + cos(a) * r, cy + sin(a) * r))
            }
        }
        return ArtPath(loops: [pts])
    }
}
