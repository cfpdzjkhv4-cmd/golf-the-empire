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

        lawn(&ops, w: w, h: h, rng: &rng)
        if club.range > 0 { range(&ops, level: club.range, rng: &rng) }
        carPark(&ops, x: w - 4.6, y: 1.0, cars: club.carsParked, rng: &rng)
        if club.shop > 0 { proShop(&ops, level: club.shop, north: club.north) }

        // The clubhouse itself, growing with each level.
        switch club.clubhouse {
        case 0: portacabin(&ops)
        case 1: house(&ops, x: 5.6, y: 2.4, width: 4.8, wall: 1.4, roofDepth: 1.4, north: club.north, windows: 3, chimneys: [6.3])
            bench(&ops, x: 6.0, y: 4.05)
        case 2:
            // Terrace with parasols first, so the building sits behind it.
            terrace(&ops, x: 4.3, y: 3.95, width: 6.8)
            house(&ops, x: 4.5, y: 2.3, width: 5.4, wall: 1.5, roofDepth: 1.5, north: club.north, windows: 4, chimneys: [5.1, 9.0], dormers: 2)
            conservatory(&ops, x: 9.95, y: 2.9, width: 1.1, height: 1.6)
            parasols(&ops, at: [9.35], y: 4.2, rng: &rng)
            bench(&ops, x: 4.7, y: 4.15)
        default:
            terrace(&ops, x: 3.7, y: 4.0, width: 7.6)
            house(&ops, x: 4.0, y: 2.2, width: 7.0, wall: 1.7, roofDepth: 1.6, north: club.north, windows: 6, chimneys: [4.5, 10.1], dormers: 3)
            grandFront(&ops, north: club.north)
            parasols(&ops, at: [4.45, 10.6], y: 4.2, rng: &rng)
            for x in [6.5, 8.5] { topiary(&ops, x: x, y: 4.15) }
        }

        ops.append(.endClip)
        return ops
    }

    // MARK: Grounds

    private func lawn(_ ops: inout [DrawOp], w: Double, h: Double, rng: inout SeededRandom) {
        ops.append(.fill(.rect(0, 0, w, h), style.terrain("firstCut")))
        // Mown stripes, then mottles.
        for k in stride(from: 0.0, to: w, by: 1.2) where Int(k / 1.2) % 2 == 0 {
            ops.append(.fill(.rect(k, 0, 0.6, h), style.terrain("fairwayStripe", opacity: 0.18)))
        }
        for _ in 0..<50 {
            let c = ArtPoint(rng.unit() * w, rng.unit() * h)
            ops.append(.ellipse(centre: c, rx: 0.25 + rng.unit() * 0.3, ry: 0.12 + rng.unit() * 0.1, style.terrain("fairway", opacity: 0.3)))
        }
        // Gravel path up to the first tee, edged, with a little scatter of stones.
        let path: [(Double, Double)] = [(w / 2 - 0.35, 0), (w / 2 + 0.35, 0), (w / 2 + 0.5, 2.4), (w / 2 - 0.5, 2.4)]
        ops.append(.fill(.polygon(path), style.terrain("gravel")))
        ops.append(.stroke(.polygon(path), style.terrain("sandShade", opacity: 0.6), width: 0.05))
        for _ in 0..<26 {
            let y = rng.unit() * 2.3
            let half = 0.35 + y / 2.4 * 0.13
            ops.append(.ellipse(centre: ArtPoint(w / 2 + (rng.unit() * 2 - 1) * half * 0.85, y), rx: 0.04, ry: 0.03,
                                RGBA(hex: rng.unit() < 0.5 ? "#A99F86" : "#E6DCC4")))
        }
        // A path from the car park round to the clubhouse door.
        ops.append(.fill(.rect(w / 2 - 0.3, 3.6, 0.6, 1.57), style.terrain("gravel", opacity: 0.85)))
        ops.append(.fill(.rect(w / 2 - 0.3, 4.75, w - 4.6 - w / 2 + 0.3, 0.42), style.terrain("gravel", opacity: 0.85)))
    }

    private func range(_ ops: inout [DrawOp], level: Int, rng: inout SeededRandom) {
        let x = 0.3, y = 0.3, rw = 4.4, rh = 1.6
        ops.append(.fill(.rect(x, y, rw, rh), style.terrain("fairway")))
        for k in 0..<4 { ops.append(.fill(.rect(x, y + Double(k) * 0.4, rw, 0.2), style.terrain("fairwayStripe", opacity: 0.4))) }
        // Target flags and yardage boards out on the range.
        for (k, fx) in [1.1, 2.5, 3.8].enumerated() {
            let fy = y + 0.35 + Double(k % 2) * 0.25
            ops.append(.ellipse(centre: ArtPoint(fx, fy + 0.12), rx: 0.22, ry: 0.1, style.terrain("green")))
            ops.append(.fill(.rect(fx - 0.01, fy - 0.25, 0.025, 0.37), RGBA(hex: "#F4F0E6")))
            ops.append(.fill(.polygon([(fx + 0.015, fy - 0.25), (fx + 0.18, fy - 0.2), (fx + 0.015, fy - 0.15)]),
                             RGBA(hex: ["#D94F3D", "#F2C230", "#2F6DB5"][k])))
        }
        // Balls scattered down the range.
        for _ in 0..<34 {
            ops.append(.ellipse(centre: ArtPoint(x + 0.2 + rng.unit() * (rw - 0.4), y + 0.1 + rng.unit() * 1.0), rx: 0.03, ry: 0.03,
                                RGBA(hex: "#FFFFFF", opacity: 0.9)))
        }
        // Hitting bays: mats with dividers, under a roof once the range is upgraded.
        let bayY = y + rh - 0.5
        if level >= 2 {
            ops.append(.fill(.rect(x, bayY - 0.12, rw, 0.62), RGBA(hex: "#5A4632")))
        }
        for k in 0..<5 {
            let bx = x + 0.2 + Double(k) * 0.85
            ops.append(.fill(.rect(bx, bayY, 0.6, 0.4), RGBA(hex: "#4E8A3E")))
            ops.append(.fill(.rect(bx + 0.05, bayY + 0.05, 0.5, 0.3), RGBA(hex: "#5F9E4C")))
            ops.append(.ellipse(centre: ArtPoint(bx + 0.3, bayY + 0.12), rx: 0.035, ry: 0.035, RGBA(hex: "#FFFFFF")))
            // A basket of balls.
            ops.append(.ellipse(centre: ArtPoint(bx + 0.48, bayY + 0.3), rx: 0.08, ry: 0.06, RGBA(hex: "#2F2F2F")))
            ops.append(.ellipse(centre: ArtPoint(bx + 0.48, bayY + 0.28), rx: 0.055, ry: 0.035, RGBA(hex: "#F4F0E6")))
            if k > 0 { ops.append(.fill(.rect(bx - 0.14, bayY - 0.05, 0.05, 0.5), RGBA(hex: "#3E3428"))) }
        }
        if level >= 2 {
            ops.append(.fill(.rect(x, bayY - 0.22, rw, 0.12), roofColourTile(false)))
        }
        // Net posts along the sides.
        ops.append(.stroke(.rect(x, y, rw, rh), RGBA(hex: "#3E4A3A", opacity: 0.55), width: 0.05))
        for k in 0...4 {
            ops.append(.ellipse(centre: ArtPoint(x, y + Double(k) * rh / 4), rx: 0.05, ry: 0.05, RGBA(hex: "#3E4A3A")))
            ops.append(.ellipse(centre: ArtPoint(x + rw, y + Double(k) * rh / 4), rx: 0.05, ry: 0.05, RGBA(hex: "#3E4A3A")))
        }
    }

    private func carPark(_ ops: inout [DrawOp], x lotX: Double, y lotY: Double, cars: Int, rng: inout SeededRandom) {
        let lw = 4.3, lh = 4.6
        // Hedge round the outside, then tarmac with a kerb.
        ops.append(.fill(roundedRect(lotX - 0.2, lotY - 0.2, lw + 0.4, lh + 0.4, 0.2), RGBA(hex: "#3F6B35")))
        for k in 0..<22 {
            let t = Double(k) / 22
            ops.append(.ellipse(centre: ArtPoint(lotX - 0.1 + t * (lw + 0.2), lotY - 0.12), rx: 0.16, ry: 0.1, RGBA(hex: "#4E7F41")))
        }
        ops.append(.fill(.rect(lotX, lotY, lw, lh), RGBA(hex: "#BDB6A6")))
        ops.append(.fill(.rect(lotX + 0.06, lotY + 0.06, lw - 0.12, lh - 0.12), style.terrain("tarmac")))
        for _ in 0..<40 {
            ops.append(.ellipse(centre: ArtPoint(lotX + rng.unit() * lw, lotY + rng.unit() * lh), rx: 0.12 + rng.unit() * 0.2, ry: 0.08,
                                RGBA(hex: rng.unit() < 0.5 ? "#000000" : "#FFFFFF", opacity: 0.05)))
        }
        // Bay lines and a painted arrow down the middle.
        for k in 0...6 {
            let x = lotX + 0.15 + Double(k) * 0.66
            ops.append(.fill(.rect(x, lotY + 0.2, 0.04, 1.4), RGBA(hex: "#F4F0E6", opacity: 0.8)))
            ops.append(.fill(.rect(x, lotY + 3.0, 0.04, 1.4), RGBA(hex: "#F4F0E6", opacity: 0.8)))
        }
        let ay = lotY + 2.3
        ops.append(.fill(.rect(lotX + 1.4, ay - 0.025, 1.2, 0.05), RGBA(hex: "#F4F0E6", opacity: 0.7)))
        ops.append(.fill(.polygon([(lotX + 1.4, ay - 0.14), (lotX + 1.15, ay), (lotX + 1.4, ay + 0.14)]), RGBA(hex: "#F4F0E6", opacity: 0.7)))
        // Cars, fuller on busy days.
        let colours = ["#B5523B", "#2F6DB5", "#C9C3B8", "#1F1F24", "#5A5F66", "#2E6B45", "#E9DAA9", "#7B4FA8", "#F4F2EC", "#8C1C24"]
        var bays: [(ArtPoint, Bool)] = []
        for (row, facingUp) in [(lotY + 0.9, false), (lotY + 3.7, true)] {
            for k in 0..<6 { bays.append((ArtPoint(lotX + 0.48 + Double(k) * 0.66, row), facingUp)) }
        }
        // Fill bays in a scattered but repeatable order, not left to right.
        var order = Array(bays.indices)
        for i in order.indices.reversed() { order.swapAt(i, Int(rng.unit() * Double(i + 1)) % (i + 1)) }
        for i in order.prefix(min(bays.count, cars)).sorted() {
            car(&ops, at: bays[i].0, facingUp: bays[i].1, colour: RGBA(hex: rng.pick(colours)), long: rng.unit() < 0.3)
        }
    }

    private func car(_ ops: inout [DrawOp], at c: ArtPoint, facingUp: Bool, colour: RGBA, long: Bool) {
        let len = long ? 1.08 : 0.96, half = len / 2
        let front = facingUp ? -1.0 : 1.0
        ops.append(.fill(roundedRect(c.x - 0.25 + 0.07, c.y - half + 0.1, 0.5, len, 0.15), style.shadow))
        ops.append(.fill(roundedRect(c.x - 0.25, c.y - half, 0.5, len, 0.15), colour))
        // Roof, windscreen and rear window.
        ops.append(.fill(roundedRect(c.x - 0.19, c.y - half * 0.42, 0.38, half * 0.84, 0.08), darker(colour, 0.88)))
        let screenY = c.y + front * half * 0.42
        ops.append(.fill(.rect(c.x - 0.19, front > 0 ? screenY : screenY - 0.2, 0.38, 0.2), RGBA(hex: "#3E4C59", opacity: 0.9)))
        let rearY = c.y - front * half * 0.42
        ops.append(.fill(.rect(c.x - 0.17, front > 0 ? rearY - 0.13 : rearY, 0.34, 0.13), RGBA(hex: "#3E4C59", opacity: 0.8)))
        ops.append(.fill(.rect(c.x - 0.15, c.y - half * 0.38, 0.06, half * 0.7), RGBA(hex: "#FFFFFF", opacity: 0.18)))
        // Headlights.
        for dx in [-0.16, 0.16] {
            ops.append(.ellipse(centre: ArtPoint(c.x + dx, c.y + front * (half - 0.04)), rx: 0.05, ry: 0.025, RGBA(hex: "#F6F0D8")))
        }
    }

    // MARK: Buildings

    private func proShop(_ ops: inout [DrawOp], level: Int, north: Bool) {
        let sw = level >= 2 ? 3.2 : 2.2, x = 0.6, y = 2.7, wall = 1.2
        if level >= 2 {
            house(&ops, x: x, y: y, width: sw, wall: wall, roofDepth: 0.9, north: north, windows: 3, chimneys: [])
        } else {
            flatBuilding(&ops, x: x, y: y, width: sw, wall: wall, roofDepth: 0.9, roof: roofColour(north), wallColour: wallColour(north), windows: 2)
        }
        // Striped awning over the door and a sign board.
        let ax = x + sw / 2 - 0.65
        for k in 0..<6 {
            ops.append(.fill(.rect(ax + Double(k) * 0.22, y + 0.02, 0.22, 0.24), RGBA(hex: k % 2 == 0 ? "#1F4D3A" : "#F4F0E6")))
        }
        for k in 0..<6 {
            ops.append(.ellipse(centre: ArtPoint(ax + 0.11 + Double(k) * 0.22, y + 0.26), rx: 0.11, ry: 0.05, RGBA(hex: k % 2 == 0 ? "#1F4D3A" : "#F4F0E6")))
        }
        ops.append(.fill(.rect(x + sw / 2 - 0.5, y + wall + 0.05, 1.0, 0.18), style.ink.opacity(0.75)))
        ops.append(.fill(.rect(x + sw / 2 - 0.35, y + wall + 0.11, 0.7, 0.05), style.gold.opacity(0.9)))
        // Trolleys lined up outside.
        for k in 0..<(level >= 2 ? 3 : 2) {
            let tx = x + sw + 0.15 + Double(k) * 0.24, ty = y + wall - 0.35
            ops.append(.stroke(ArtPath(loops: [[ArtPoint(tx, ty), ArtPoint(tx + 0.08, ty + 0.4), ArtPoint(tx, ty)]]), RGBA(hex: "#5A5F66"), width: 0.04))
            ops.append(.fill(roundedRect(tx - 0.06, ty + 0.02, 0.14, 0.3, 0.05), RGBA(hex: ["#1F1F24", "#7A2E3A", "#2F4A7A"][k])))
            ops.append(.ellipse(centre: ArtPoint(tx + 0.08, ty + 0.42), rx: 0.05, ry: 0.05, RGBA(hex: "#2A2A2A")))
        }
    }

    private func portacabin(_ ops: inout [DrawOp]) {
        let x = 6.4, y = 2.8, width = 3.2, wall = 1.1
        flatBuilding(&ops, x: x, y: y, width: width, wall: wall, roofDepth: 0.8, roof: style.terrain("cabinRoof"),
                     wallColour: style.terrain("cabinWall"), windows: 2)
        // Corrugated panels and a rust streak or two.
        for k in stride(from: x + 0.12, to: x + width, by: 0.18) {
            ops.append(.fill(.rect(k, y, 0.03, wall), RGBA(hex: "#000000", opacity: 0.07)))
        }
        ops.append(.fill(.rect(x + 0.4, y, 0.06, 0.5), RGBA(hex: "#9A5A2E", opacity: 0.35)))
        ops.append(.fill(.rect(x + width - 0.7, y, 0.05, 0.35), RGBA(hex: "#9A5A2E", opacity: 0.3)))
        // Puddle stain on the roof, wooden steps, a gas bottle and a wheelie bin.
        ops.append(.ellipse(centre: ArtPoint(x + 1.2, y - 0.4), rx: 0.6, ry: 0.2, RGBA(hex: "#000000", opacity: 0.08)))
        ops.append(.fill(.rect(x + width / 2 - 0.35, y + wall, 0.7, 0.14), RGBA(hex: "#8A6A48")))
        ops.append(.fill(.rect(x + width / 2 - 0.3, y + wall + 0.14, 0.6, 0.12), RGBA(hex: "#7A5C3E")))
        ops.append(.fill(roundedRect(x + width + 0.1, y + wall - 0.45, 0.22, 0.45, 0.1), RGBA(hex: "#D94F3D")))
        ops.append(.fill(.rect(x + width + 0.4, y + wall - 0.55, 0.35, 0.55), RGBA(hex: "#2E6B45")))
        ops.append(.fill(.rect(x + width + 0.38, y + wall - 0.6, 0.39, 0.08), RGBA(hex: "#24563A")))
        // A hand painted sign.
        ops.append(.fill(.rect(x + 0.2, y + 0.08, 0.9, 0.22), RGBA(hex: "#F4F0E6")))
        ops.append(.fill(.rect(x + 0.28, y + 0.16, 0.74, 0.05), style.ink.opacity(0.6)))
    }

    /// A pitched roof building with tiles or slates, framed windows, chimneys and window boxes.
    private func house(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, wall: Double, roofDepth: Double, north: Bool,
                       windows: Int, chimneys: [Double], dormers: Int = 0) {
        let roofTop = y - roofDepth
        let roof = roofColour(north), walls = wallColour(north)
        ops.append(.fill(.rect(x + 0.2, roofTop + 0.25, width, roofDepth + wall), style.shadow))
        // Chimneys behind the ridge.
        for cx in chimneys {
            ops.append(.fill(.rect(cx, roofTop - 0.45, 0.36, 0.7), walls))
            ops.append(.fill(.rect(cx + 0.2, roofTop - 0.45, 0.16, 0.7), RGBA(hex: "#000000", opacity: 0.12)))
            ops.append(.fill(.rect(cx - 0.04, roofTop - 0.5, 0.44, 0.1), darker(walls, 0.8)))
            for k in 0..<2 { ops.append(.fill(.rect(cx + 0.05 + Double(k) * 0.16, roofTop - 0.62, 0.1, 0.14), RGBA(hex: "#B5523B"))) }
        }
        let outline: [(Double, Double)] = [(x - 0.15, y), (x + 0.35, roofTop), (x + width - 0.35, roofTop), (x + width + 0.15, y)]
        ops.append(.fill(.polygon(outline), roof))
        ops.append(.clip(.polygon(outline)))
        // Courses of tiles or slates, with staggered joints.
        let course = north ? 0.16 : 0.13
        var row = 0
        for cy in stride(from: roofTop + course, to: y, by: course) {
            ops.append(.fill(.rect(x - 0.2, cy, width + 0.4, 0.025), darker(roof, 0.78)))
            let step = north ? 0.3 : 0.2
            for jx in stride(from: x - 0.2 + (row % 2 == 0 ? 0 : step / 2), to: x + width + 0.2, by: step) {
                ops.append(.fill(.rect(jx, cy - course + 0.03, 0.018, course - 0.03), darker(roof, 0.85)))
            }
            row += 1
        }
        // Light on the upper slope, moss in places.
        ops.append(.fill(.rect(x - 0.2, roofTop, width + 0.4, roofDepth * 0.25), RGBA(hex: "#FFFFFF", opacity: 0.08)))
        ops.append(.endClip)
        ops.append(.fill(.rect(x + 0.35, roofTop - 0.04, width - 0.7, 0.08), darker(roof, 0.7)))
        // Dormer windows in the roof.
        if dormers > 0 {
            for k in 1...dormers {
                let dx = x + width * Double(k) / Double(dormers + 1) - 0.25
                let dy = roofTop + roofDepth * 0.35
                ops.append(.fill(.polygon([(dx - 0.08, dy + 0.1), (dx + 0.25, dy - 0.2), (dx + 0.58, dy + 0.1)]), darker(roof, 0.9)))
                ops.append(.fill(.rect(dx, dy + 0.08, 0.5, 0.42), walls))
                window(&ops, x: dx + 0.1, y: dy + 0.14, width: 0.3, height: 0.3)
            }
        }
        // Front wall with a darker plinth and a little texture.
        ops.append(.fill(.rect(x, y, width, wall), walls))
        ops.append(.fill(.rect(x, y, width, 0.08), RGBA(hex: "#000000", opacity: 0.18)))
        ops.append(.fill(.rect(x, y + wall - 0.12, width, 0.12), darker(walls, 0.82)))
        var rng = SeededRandom(seed: UInt64(x * 100 + y * 10))
        for _ in 0..<Int(width * 10) {
            ops.append(.fill(.rect(x + rng.unit() * (width - 0.2), y + 0.1 + rng.unit() * (wall - 0.3), north ? 0.18 : 0.14, 0.05),
                             darker(walls, rng.unit() < 0.5 ? 0.9 : 1.08)))
        }
        // Door with a canopy and a step.
        let doorX = x + width / 2 - 0.24
        ops.append(.fill(.rect(doorX - 0.06, y + wall - 0.84, 0.6, 0.84), RGBA(hex: "#F4F0E6")))
        ops.append(.fill(.rect(doorX, y + wall - 0.78, 0.48, 0.78), style.terrain("door")))
        ops.append(.fill(.rect(doorX + 0.06, y + wall - 0.7, 0.36, 0.2), RGBA(hex: "#FFFFFF", opacity: 0.12)))
        ops.append(.ellipse(centre: ArtPoint(doorX + 0.38, y + wall - 0.38), rx: 0.03, ry: 0.03, style.gold))
        ops.append(.fill(.polygon([(doorX - 0.16, y + wall - 0.84), (doorX + 0.24, y + wall - 1.06), (doorX + 0.64, y + wall - 0.84)]), darker(roof, 0.9)))
        ops.append(.fill(.rect(doorX - 0.12, y + wall, 0.72, 0.1), RGBA(hex: "#CFC4AA")))
        // Windows, each with a box of flowers.
        let spacing = width / Double(windows + 1)
        for k in 1...windows {
            var wx = x + spacing * Double(k) - 0.22
            if abs(wx + 0.22 - (x + width / 2)) < 0.45 { wx += 0.55 }
            window(&ops, x: wx, y: y + 0.28, width: 0.44, height: 0.5)
            flowers(&ops, x: wx - 0.03, y: y + 0.8, width: 0.5, seed: UInt64(k) &+ UInt64(x * 7))
        }
        // Hanging baskets either side of the door.
        for bx in [doorX - 0.3, doorX + 0.78] {
            ops.append(.fill(.rect(bx - 0.005, y + 0.12, 0.01, 0.16), RGBA(hex: "#3A3A3A")))
            ops.append(.ellipse(centre: ArtPoint(bx, y + 0.33), rx: 0.14, ry: 0.1, RGBA(hex: "#3E6B35")))
            for (k, c) in ["#D94F3D", "#F4F0E6", "#C2417A", "#7B4FA8"].enumerated() {
                ops.append(.ellipse(centre: ArtPoint(bx - 0.09 + Double(k) * 0.06, y + 0.3 + Double(k % 2) * 0.06), rx: 0.035, ry: 0.035, RGBA(hex: c)))
            }
        }
    }

    private func flatBuilding(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, wall: Double, roofDepth: Double,
                              roof: RGBA, wallColour: RGBA, windows: Int) {
        let roofTop = y - roofDepth
        ops.append(.fill(.rect(x + 0.2, roofTop + 0.25, width, roofDepth + wall), style.shadow))
        ops.append(.fill(.rect(x, roofTop, width, roofDepth), roof))
        ops.append(.stroke(.rect(x + 0.05, roofTop + 0.05, width - 0.1, roofDepth - 0.1), darker(roof, 0.8), width: 0.04))
        ops.append(.fill(.rect(x, y, width, wall), wallColour))
        ops.append(.fill(.rect(x, y, width, 0.06), RGBA(hex: "#000000", opacity: 0.18)))
        ops.append(.fill(.rect(x + width / 2 - 0.22, y + wall - 0.75, 0.44, 0.75), style.terrain("door")))
        let spacing = width / Double(windows + 1)
        for k in 1...windows {
            var wx = x + spacing * Double(k) - 0.2
            if abs(wx + 0.2 - (x + width / 2)) < 0.4 { wx += 0.5 }
            window(&ops, x: wx, y: y + 0.3, width: 0.4, height: 0.42)
        }
    }

    /// A sash window: white frame, glazing bars, a sill and a glint.
    private func window(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, height: Double) {
        let frame = RGBA(hex: "#F4F0E6")
        ops.append(.fill(.rect(x - 0.04, y - 0.04, width + 0.08, height + 0.08), frame))
        ops.append(.fill(.rect(x, y, width, height), style.terrain("window")))
        ops.append(.fill(.polygon([(x, y), (x + width * 0.45, y), (x, y + height * 0.6)]), RGBA(hex: "#FFFFFF", opacity: 0.18)))
        ops.append(.fill(.rect(x + width / 2 - 0.015, y, 0.03, height), frame))
        ops.append(.fill(.rect(x, y + height / 2 - 0.015, width, 0.03), frame))
        ops.append(.fill(.rect(x - 0.07, y + height + 0.02, width + 0.14, 0.06), RGBA(hex: "#DDD6C6")))
    }

    private func flowers(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        ops.append(.fill(.rect(x, y, width, 0.1), RGBA(hex: "#6B4A32")))
        for k in 0..<6 {
            let fx = x + 0.04 + Double(k) / 5 * (width - 0.08)
            ops.append(.ellipse(centre: ArtPoint(fx, y - 0.01), rx: 0.06, ry: 0.05, RGBA(hex: "#3E6B35")))
            ops.append(.ellipse(centre: ArtPoint(fx + 0.01, y - 0.04), rx: 0.03, ry: 0.03,
                                RGBA(hex: rng.pick(["#D94F3D", "#F2C230", "#F4F0E6", "#C2417A", "#7B4FA8"]))))
        }
    }

    private func bench(_ ops: inout [DrawOp], x: Double, y: Double) {
        ops.append(.fill(.rect(x + 0.05, y + 0.08, 0.8, 0.08), style.shadow))
        ops.append(.fill(.rect(x, y - 0.12, 0.8, 0.08), RGBA(hex: "#8A6A48")))
        ops.append(.fill(.rect(x, y, 0.8, 0.1), RGBA(hex: "#A07A50")))
        for lx in [x + 0.05, x + 0.7] { ops.append(.fill(.rect(lx, y + 0.1, 0.05, 0.1), RGBA(hex: "#3A3A3A"))) }
    }

    private func terrace(_ ops: inout [DrawOp], x: Double, y: Double, width: Double) {
        // York stone flags in front of the building.
        ops.append(.fill(.rect(x, y - 0.3, width, 0.75), RGBA(hex: "#D8CDB4")))
        for k in stride(from: x, to: x + width, by: 0.36) {
            ops.append(.fill(.rect(k, y - 0.3, 0.015, 0.75), RGBA(hex: "#B8AC92")))
        }
        ops.append(.fill(.rect(x, y + 0.07, width, 0.015), RGBA(hex: "#B8AC92")))
        ops.append(.fill(.rect(x, y + 0.42, width, 0.05), RGBA(hex: "#A99F86")))
    }

    /// Tables under parasols, drawn in front of the building.
    private func parasols(_ ops: inout [DrawOp], at xs: [Double], y: Double, rng: inout SeededRandom) {
        for px in xs {
            ops.append(.ellipse(centre: ArtPoint(px + 0.12, y + 0.25), rx: 0.42, ry: 0.16, style.shadow))
            ops.append(.ellipse(centre: ArtPoint(px, y + 0.15), rx: 0.18, ry: 0.1, RGBA(hex: "#F4F0E6")))
            for dx in [-0.3, 0.3] { ops.append(.ellipse(centre: ArtPoint(px + dx, y + 0.17), rx: 0.08, ry: 0.06, RGBA(hex: "#5A4632"))) }
            let colour = RGBA(hex: rng.pick(["#1F4D3A", "#F4F0E6", "#7A2E3A", "#2F4A7A"]))
            ops.append(.ellipse(centre: ArtPoint(px, y - 0.15), rx: 0.42, ry: 0.22, colour))
            for k in 0..<4 {
                let a = Double(k) / 4 * Double.pi
                ops.append(.stroke(ArtPath(loops: [[ArtPoint(px, y - 0.15), ArtPoint(px + cos(a) * 0.4, y - 0.15 + sin(a) * 0.2 - 0.02), ArtPoint(px, y - 0.15)]]),
                                   darker(colour, 0.8), width: 0.02))
            }
            ops.append(.ellipse(centre: ArtPoint(px, y - 0.17), rx: 0.04, ry: 0.04, darker(colour, 0.7)))
        }
    }

    private func conservatory(_ ops: inout [DrawOp], x: Double, y: Double, width: Double, height: Double) {
        let frame = RGBA(hex: "#F4F0E6")
        ops.append(.fill(.rect(x + 0.12, y + 0.15, width, height), style.shadow))
        ops.append(.fill(.polygon([(x - 0.05, y + 0.3), (x + width / 2, y), (x + width + 0.05, y + 0.3)]), RGBA(hex: "#DCEBF0", opacity: 0.95)))
        ops.append(.fill(.rect(x, y + 0.3, width, height - 0.3), RGBA(hex: "#CFE3EA", opacity: 0.92)))
        // Diners inside.
        for (k, c) in ["#7A2E3A", "#2F4A7A", "#C9A24A"].enumerated() {
            ops.append(.ellipse(centre: ArtPoint(x + 0.25 + Double(k) * 0.3, y + 0.9 + Double(k % 2) * 0.3), rx: 0.08, ry: 0.08, RGBA(hex: c, opacity: 0.6)))
        }
        for k in 0...4 { ops.append(.fill(.rect(x + Double(k) * width / 4 - 0.015, y + 0.3, 0.03, height - 0.3), frame)) }
        ops.append(.fill(.rect(x, y + 0.75, width, 0.03), frame))
        ops.append(.stroke(.rect(x, y + 0.3, width, height - 0.3), frame, width: 0.05))
        ops.append(.fill(.rect(x, y + height - 0.22, width, 0.22), RGBA(hex: "#F4F0E6", opacity: 0.85)))
        ops.append(.ellipse(centre: ArtPoint(x + width / 2, y - 0.02), rx: 0.05, ry: 0.05, style.gold))
    }

    /// The grand clubhouse's centrepiece: a gable with a clock, a pillared porch and the club flag.
    private func grandFront(_ ops: inout [DrawOp], north: Bool) {
        let walls = wallColour(north), roof = roofColour(north)
        ops.append(.fill(.polygon([(6.6, 2.25), (7.5, 1.05), (8.4, 2.25)]), darker(roof, 0.85)))
        ops.append(.fill(.polygon([(6.75, 2.2), (7.5, 1.25), (8.25, 2.2)]), walls))
        // Clock face.
        ops.append(.ellipse(centre: ArtPoint(7.5, 1.82), rx: 0.2, ry: 0.2, RGBA(hex: "#F4F0E6")))
        ops.append(.stroke(ArtPath(loops: [circle(ArtPoint(7.5, 1.82), 0.2)]), style.gold, width: 0.03))
        ops.append(.stroke(ArtPath(loops: [[ArtPoint(7.5, 1.82), ArtPoint(7.5, 1.68), ArtPoint(7.5, 1.82), ArtPoint(7.6, 1.86)]]), style.ink, width: 0.025))
        // Porch with columns over the door.
        ops.append(.fill(.rect(6.9, 2.9, 1.2, 0.1), RGBA(hex: "#F4F0E6")))
        ops.append(.fill(.polygon([(6.85, 2.92), (7.5, 2.6), (8.15, 2.92)]), RGBA(hex: "#EDE8DC")))
        for cx in [6.95, 7.2, 7.8, 8.05] {
            ops.append(.fill(.rect(cx - 0.04, 3.0, 0.08, 0.9), RGBA(hex: "#F4F0E6")))
            ops.append(.fill(.rect(cx + 0.01, 3.0, 0.03, 0.9), RGBA(hex: "#000000", opacity: 0.08)))
        }
        // Brass plaque and steps.
        ops.append(.fill(.rect(7.35, 3.1, 0.3, 0.12), style.gold))
        ops.append(.fill(.rect(6.8, 3.9, 1.4, 0.08), RGBA(hex: "#D8CDB4")))
        // Flagpole and the club flag.
        ops.append(.fill(.rect(7.47, 0.05, 0.05, 1.05), RGBA(hex: "#F4F0E6")))
        ops.append(.ellipse(centre: ArtPoint(7.495, 0.05), rx: 0.05, ry: 0.05, style.gold))
        ops.append(.fill(.polygon([(7.52, 0.1), (7.85, 0.06), (8.15, 0.16), (7.85, 0.3), (7.52, 0.38)]), RGBA(hex: "#1F4D3A")))
        ops.append(.fill(.polygon([(7.58, 0.17), (7.8, 0.15), (7.95, 0.21), (7.8, 0.27), (7.58, 0.3)]), style.gold))
        // Ivy up one corner.
        var rng = SeededRandom(seed: 77)
        for _ in 0..<40 {
            let iy = 2.2 + rng.unit() * 1.6
            ops.append(.ellipse(centre: ArtPoint(4.05 + rng.unit() * (0.5 - (iy - 2.2) * 0.15), iy), rx: 0.07, ry: 0.06,
                                RGBA(hex: rng.unit() < 0.5 ? "#3E6B35" : "#4E7F41")))
        }
    }

    private func topiary(_ ops: inout [DrawOp], x: Double, y: Double) {
        ops.append(.ellipse(centre: ArtPoint(x + 0.1, y + 0.18), rx: 0.22, ry: 0.08, style.shadow))
        ops.append(.fill(.rect(x - 0.12, y - 0.05, 0.24, 0.22), RGBA(hex: "#6B6B5E")))
        ops.append(.ellipse(centre: ArtPoint(x, y - 0.25), rx: 0.22, ry: 0.24, RGBA(hex: "#2F5A2A")))
        ops.append(.ellipse(centre: ArtPoint(x - 0.06, y - 0.31), rx: 0.1, ry: 0.1, RGBA(hex: "#4E7F41")))
    }

    private func wallColour(_ north: Bool) -> RGBA { style.terrain(north ? "stoneWall" : "brickWall") }
    private func roofColour(_ north: Bool) -> RGBA { style.terrain(north ? "slateRoof" : "tileRoof") }
    private func roofColourTile(_ north: Bool) -> RGBA { darker(roofColour(north), 0.9) }
    private func darker(_ c: RGBA, _ f: Double) -> RGBA { RGBA(r: min(1, c.r * f), g: min(1, c.g * f), b: min(1, c.b * f), a: c.a) }

    private func circle(_ c: ArtPoint, _ r: Double) -> [ArtPoint] {
        (0..<24).map { k in
            let a = Double(k) / 24 * 2 * .pi
            return ArtPoint(c.x + cos(a) * r, c.y + sin(a) * r)
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
