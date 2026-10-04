import Foundation

/// Makes holes: the untouched land for a new course, the deliberately basic
/// auto layout, and the signature generator used by legendary venues and rivals.
/// All randomness comes from the caller's SeededRandom, so layouts replay exactly.
public struct HoleGenerator: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    private var columns: Int { balance.grid.columns }
    private var rows: Int { balance.grid.rows }
    private var teeRow: Int { balance.grid.teeRow }
    private var middle: Int { columns / 2 }

    /// Rounds like JavaScript's Math.round (halves go up), so shapes match the prototype.
    private func round(_ v: Double) -> Int { Int((v + 0.5).rounded(.down)) }
    private func clampColumn(_ v: Int) -> Int { min(columns - 4, max(3, v)) }

    // MARK: Untouched land

    /// The land as bought: rough with trees, bunkers or a pond depending on the land type.
    public func baseLand(_ land: LandKind, rng: inout SeededRandom) -> Hole {
        var hole = Hole(columns: columns, rows: rows)
        func blob(_ tile: Tile, _ cx: Double, _ cy: Double, _ r: Double, _ p: Double) {
            for y in 0..<rows {
                for x in 0..<columns {
                    let d = GridVector(x: Double(x), y: Double(y)).distance(to: GridVector(x: cx, y: cy))
                    if d < r && rng.chance(p - d / r * p * 0.6) { hole.set(x, y, tile) }
                }
            }
        }
        func edgeX() -> Double {
            Double(rng.chance(0.5) ? rng.int(0...2) : rng.int((columns - 3)...(columns - 1)))
        }
        func anyRow() -> Double { Double(rng.int(0...(rows - 1))) }

        switch land {
        case .links:
            for _ in 0..<5 { blob(.trees, edgeX(), anyRow(), 2, 0.6) }
            for _ in 0..<5 { hole.set(Int(edgeX()), Int(anyRow()), .bunker) }
        case .heathland:
            for _ in 0..<7 { blob(.trees, rng.unit() * Double(columns), rng.unit() * Double(rows), 3.2, 0.8) }
        case .parkland:
            for i in hole.tiles.indices where rng.chance(0.07) { hole.set(i % columns, i / columns, .trees) }
            for _ in 0..<3 { blob(.trees, edgeX(), anyRow(), 2.5, 0.8) }
        case .moorland:
            for i in hole.tiles.indices where rng.chance(0.025) { hole.set(i % columns, i / columns, .trees) }
            blob(.water, edgeX(), Double(rng.int(4...28)), 1.8, 1)
        }
        return hole
    }

    // MARK: Auto layout (deliberately basic, scores about 3.4)

    /// A straight, playable hole with a couple of greenside bunkers and no water.
    /// `lostRows` shortens it when the sea has taken the far end.
    public func autoLayout(par: Int, land: LandKind, on old: Hole, lostRows: Int = 0, rng: inout SeededRandom) -> Hole {
        var hole = old
        func set(_ x: Int, _ y: Int, _ t: Tile) {
            if hole[x, y] != nil && hole[x, y] != .sea { hole.set(x, y, t) }
        }
        let wanted = par == 3 ? rng.int(8...12) : par == 4 ? rng.int(19...24) : rng.int(27...29)
        let length = min(wanted, rows - 4 - lostRows)
        let greenY = teeRow - length
        let side = Double(rng.sign())
        let amplitude = par == 3 ? rng.unit() * 1.5 : rng.unit() * 3.2
        let centreAt = { (y: Int) -> Int in
            self.clampColumn(self.round(Double(self.middle) + side * amplitude * (Double(self.teeRow - y) / Double(length))))
        }

        for i in hole.tiles.indices where ![.trees, .water, .sea].contains(hole.tiles[i]) {
            hole.set(i % columns, i / columns, .rough)
        }
        // Clear a playing corridor through trees and water.
        for y in (greenY - 3)...(teeRow + 1) {
            let cx = centreAt(y)
            for x in (cx - 3)...(cx + 3) {
                guard let t = hole[x, y] else { continue }
                if t == .trees && (abs(x - cx) < 3 || rng.chance(0.5)) { hole.set(x, y, .rough) }
                if t == .water { hole.set(x, y, .rough) }
            }
        }
        if par > 3 {
            let width = rng.int(3...4)
            for y in (greenY + 3)...(teeRow - 4) {
                let left = centreAt(y) - width / 2
                for x in left..<(left + width) { set(x, y, .fairway) }
            }
        } else {
            for y in (greenY + 3)...(greenY + 4) {
                for x in (centreAt(y) - 1)...(centreAt(y) + 1) { set(x, y, .fairway) }
            }
        }
        let gx = centreAt(greenY)
        paintGreen(&hole, gx: gx, gy: greenY)

        let bunkers = rng.int(1...2) + (land == .links ? 1 : 0)
        for _ in 0..<bunkers {
            let angle = rng.unit() * .pi * 2
            let bx = round(Double(gx) + cos(angle) * 3.3), by = round(Double(greenY) + sin(angle) * 2.7)
            guard hole[bx, by] != nil, hole[bx, by] != .green else { continue }
            set(bx, by, .bunker)
            if rng.chance(0.5) {
                let bx2 = bx + (rng.chance(0.5) ? 1 : 0), by2 = by + (rng.chance(0.5) ? 0 : 1)
                if hole[bx2, by2] != nil && hole[bx2, by2] != .green { set(bx2, by2, .bunker) }
            }
        }
        if par > 3 && rng.chance(0.35) {
            let y = teeRow - rng.int(13...17)
            let x = centreAt(y) + (rng.chance(0.5) ? -3 : 2)
            set(x, y, .bunker)
            if rng.chance(0.6) { set(x, y + 1, .bunker) }
        }
        set(middle, teeRow, .tee)
        hole.tee = GridPoint(x: middle, y: teeRow)
        hole.pin = GridPoint(x: gx, y: greenY)
        return hole
    }

    // MARK: Signature generator (legendary venues and rivals, scores 7 to 9+)

    public func signatureLayout(par: Int, land: LandKind, on old: Hole, lostRows: Int = 0, rng: inout SeededRandom) -> Hole {
        var hole = old
        func set(_ x: Int, _ y: Int, _ t: Tile) {
            if hole[x, y] != nil && hole[x, y] != .sea { hole.set(x, y, t) }
        }
        func tileClamped(_ x: Int, _ y: Int) -> Tile? {
            hole[min(columns - 1, max(0, x)), min(rows - 1, max(0, y))]
        }
        for i in hole.tiles.indices where ![.trees, .sea].contains(hole.tiles[i]) {
            hole.set(i % columns, i / columns, .rough)
        }
        let wanted = par == 3 ? rng.int(8...12) : par == 4 ? rng.int(18...23) : rng.int(26...28)
        let length = min(wanted, rows - 4 - lostRows)
        let greenY = teeRow - length
        let side = Double(rng.sign())
        let dogleg = par > 3 && rng.chance(0.65)
        let cornerY = teeRow - round(Double(length) * (0.5 + rng.unit() * 0.12))
        let centreAt = { (y: Int) -> Int in
            if dogleg {
                let offset = y >= cornerY ? 0 : side * min(5, Double(cornerY - y) * 1.1)
                return self.clampColumn(self.round(Double(self.middle) + offset))
            }
            return self.clampColumn(self.round(Double(self.middle) + side * 1.2 * (Double(self.teeRow - y) / Double(length))))
        }

        for y in (greenY - 4)...(teeRow + 1) {
            let cx = centreAt(y)
            for x in (cx - 3)...(cx + 3) where hole[x, y] == .trees { hole.set(x, y, .rough) }
        }
        if par > 3 {
            for y in (greenY + 3)...(teeRow - 3) {
                for x in (centreAt(y) - 1)...(centreAt(y) + 2) { set(x, y, .fairway) }
            }
        } else {
            for y in (greenY + 3)...(greenY + 4) {
                for x in (centreAt(y) - 1)...(centreAt(y) + 1) { set(x, y, .fairway) }
            }
        }
        let gx = centreAt(greenY)
        let island = par == 3 && rng.chance(0.45)
        if island {
            for y in (greenY - 4)...(greenY + 4) {
                for x in (gx - 4)...(gx + 4) {
                    let dx = Double(x - gx) / 3.6, dy = Double(y - greenY) / 3.1
                    if dx * dx + dy * dy <= 1 { set(x, y, .water) }
                }
            }
        }
        paintGreen(&hole, gx: gx, gy: greenY)

        if !island {
            for k in 0..<rng.int(3...4) {
                let angle = Double(k) * .pi * 2 / 4 + rng.unit() * 0.8
                let bx = round(Double(gx) + cos(angle) * 3.2), by = round(Double(greenY) + sin(angle) * 2.6)
                guard hole[bx, by] != nil, hole[bx, by] != .green else { continue }
                set(bx, by, .bunker)
                let bx2 = bx + (cos(angle) > 0 ? 1 : -1)
                if hole[bx2, by] != nil && hole[bx2, by] != .green { set(bx2, by, .bunker) }
            }
        }
        if par == 3 && !island && rng.chance(0.5) {
            for y in (greenY + 3)...(greenY + 5) {
                for x in (gx - 3)...(gx + 3) where hole[x, y] != .fairway || y > greenY + 3 { set(x, y, .water) }
            }
        }
        if dogleg {
            let hx = middle + Int(side) * 3, hy = cornerY - 3
            let water = rng.chance(0.45)
            for y in (hy - 2)...(hy + 1) {
                for x in (hx - 1)...(hx + 1) where tileClamped(x, y) != .fairway { set(x, y, water ? .water : .bunker) }
            }
        } else if par > 3 && rng.chance(0.5) {
            let y0 = teeRow - rng.int(7...9)
            for y in y0...(y0 + 1) {
                let cx = centreAt(y)
                for x in (cx - 3)...(cx + 3) { set(x, y, .water) }
            }
        }
        if par > 3 && rng.chance(0.5) {
            let low = greenY + 6, high = max(greenY + 6, teeRow - 8)
            let y0 = rng.int(low...high)
            let sx = centreAt(y0) + (rng.chance(0.5) ? -4 : 4)
            for y in (y0 - 3)...(y0 + 3) {
                for x in (sx - 2)...(sx + 2) {
                    let dx = Double(x - sx) / 2.4, dy = Double(y - y0) / 3.4
                    if dx * dx + dy * dy <= 1 && tileClamped(x, y) != .fairway { set(x, y, .bunker) }
                }
            }
        }
        if land == .links {
            for _ in 0..<rng.int(3...6) {
                let y = rng.int((greenY + 4)...(teeRow - 4))
                let x = centreAt(y) + (rng.chance(0.5) ? -2 : 3)
                if hole[x, y] == .rough { set(x, y, .bunker) }
            }
        }
        set(middle, teeRow, .tee)
        hole.tee = GridPoint(x: middle, y: teeRow)
        hole.pin = GridPoint(x: gx, y: greenY)
        return hole
    }

    /// Best of several signature attempts, falling back to auto layout.
    public func bestSignatureLayout(par: Int, land: LandKind, on old: Hole, lostRows: Int = 0, tries: Int = 4, rng: inout SeededRandom) -> Hole {
        let analyzer = HoleAnalyzer(balance: balance)
        var best: (hole: Hole, score: Double)?
        for _ in 0..<tries {
            let candidate = signatureLayout(par: par, land: land, on: old, lostRows: lostRows, rng: &rng)
            let score = analyzer.analyze(candidate).score
            if score > 0 && (best == nil || score > best!.score) { best = (candidate, score) }
        }
        return best?.hole ?? autoLayout(par: par, land: land, on: old, lostRows: lostRows, rng: &rng)
    }

    // MARK: Shared shapes

    private func paintGreen(_ hole: inout Hole, gx: Int, gy: Int) {
        for y in (gy - 3)...(gy + 3) {
            for x in (gx - 3)...(gx + 3) {
                guard let t = hole[x, y], t != .sea else { continue }
                let dx = Double(x - gx) / 2.3, dy = Double(y - gy) / 1.9
                if dx * dx + dy * dy <= 1 { hole.set(x, y, .green) }
            }
        }
    }

    /// What it costs to turn `old` into `new`: the price of each changed tile.
    public func cost(from old: Hole, to new: Hole) -> Int {
        var total = 0
        for i in new.tiles.indices where new.tiles[i] != old.tiles[i] {
            total += balance.tileCost.cost(of: new.tiles[i])
        }
        return total
    }
}
