import Foundation
import GameCore

/// The fine detail that makes a hole look lived in: grass, heather, reeds, rake lines, grain.
/// Every mark is placed by a random seed tied to its own square, so painting one part of a
/// hole never shuffles the detail anywhere else.
extension HoleArtist {
    /// A random generator for one square, stable as the rest of the hole changes.
    func squareRandom(_ seed: UInt64, _ x: Int, _ y: Int, salt: UInt64) -> SeededRandom {
        SeededRandom(seed: seed &+ UInt64(y &* 7919 &+ x &* 104_729) &* 2_654_435_761 &+ salt)
    }

    /// Rough well away from play: no fairway, green, tee or sand next to it.
    private func isOpenRough(_ hole: Hole, _ x: Int, _ y: Int) -> Bool {
        guard hole[x, y] == .rough else { return false }
        for j in -1...1 {
            for i in -1...1 {
                if let t = hole[x + i, y + j], [.fairway, .green, .tee, .bunker].contains(t) { return false }
            }
        }
        return true
    }

    private func blades(_ c: ArtPoint, height: Double, spread: Double, count: Int, colour: RGBA, width: Double) -> [DrawOp] {
        (0..<count).map { k in
            let t = count == 1 ? 0 : Double(k) / Double(count - 1) - 0.5
            let tip = ArtPoint(c.x + t * spread, c.y - height * (1 - abs(t) * 0.5))
            let mid = ArtPoint(c.x + t * spread * 0.4, c.y - height * 0.5)
            return .stroke(ArtPath(loops: [[c, mid, tip, mid]]), colour, width: width)
        }
    }

    // MARK: Rough

    func roughDetail(_ hole: Hole, land: LandKind, seed: UInt64) -> [DrawOp] {
        var ops: [DrawOp] = []
        let l = style.land(land)
        let mottle = RGBA(hex: l.roughMottle), deep = RGBA(hex: l.deepRough)
        let w = Double(hole.columns), h = Double(hole.rows)

        // Broad, soft variation in the grass.
        var broad = SeededRandom(seed: seed &+ 5)
        for _ in 0..<(hole.columns * hole.rows / 10) {
            let c = ArtPoint(broad.unit() * w, broad.unit() * h)
            let r = 0.6 + broad.unit() * 1.2
            ops.append(.ellipse(centre: c, rx: r, ry: r * 0.6, mottle.opacity(0.22)))
        }
        // Deeper, darker rough towards the edges of the hole.
        for k in 0..<3 {
            let inset = Double(k) * 0.55
            ops.append(.fill(.rect(0, 0, 1.6 - inset, h), deep.opacity(0.16)))
            ops.append(.fill(.rect(w - 1.6 + inset, 0, 1.6 - inset, h), deep.opacity(0.16)))
        }

        for y in 0..<hole.rows {
            for x in 0..<hole.columns where hole[x, y] == .rough {
                var rng = squareRandom(seed, x, y, salt: 11)
                // Grass tufts everywhere in the rough.
                for _ in 0..<2 {
                    let c = ArtPoint(Double(x) + rng.unit(), Double(y) + rng.unit())
                    ops += blades(c, height: 0.16 + rng.unit() * 0.08, spread: 0.14, count: 3, colour: mottle.opacity(0.8), width: 0.035)
                }
                guard isOpenRough(hole, x, y) else { continue }
                let roll = rng.unit()
                let c = ArtPoint(Double(x) + 0.2 + rng.unit() * 0.6, Double(y) + 0.2 + rng.unit() * 0.6)
                switch land {
                case .links:
                    if roll < 0.22 {
                        // Marram grass: a pale fan of long blades.
                        ops += blades(c, height: 0.42, spread: 0.36, count: 6, colour: RGBA(hex: "#C9BE84"), width: 0.04)
                        ops += blades(ArtPoint(c.x + 0.05, c.y), height: 0.3, spread: 0.2, count: 3, colour: RGBA(hex: "#8E9152"), width: 0.035)
                    } else if roll < 0.26 {
                        // A sandy blowout.
                        ops.append(.ellipse(centre: c, rx: 0.32, ry: 0.2, style.terrain("beach", opacity: 0.85)))
                    }
                case .heathland:
                    if roll < 0.3 { ops += heather(c, rng: &rng, flower: RGBA(hex: l.flower)) }
                case .parkland:
                    if roll < 0.1 {
                        for _ in 0..<3 {
                            ops.append(.ellipse(centre: ArtPoint(c.x + (rng.unit() - 0.5) * 0.5, c.y + (rng.unit() - 0.5) * 0.4),
                                                rx: 0.045, ry: 0.045, RGBA(hex: "#F6F2E4")))
                        }
                    } else if roll < 0.18 {
                        ops.append(.ellipse(centre: c, rx: 0.4, ry: 0.26, RGBA(hex: l.deepRough, opacity: 0.35)))
                    }
                case .moorland:
                    if roll < 0.2 {
                        ops += heather(c, rng: &rng, flower: RGBA(hex: l.flower))
                    } else if roll < 0.34 {
                        // Bracken fronds, rusty brown.
                        for k in 0..<4 {
                            let a = -Double.pi / 2 + (Double(k) - 1.5) * 0.45
                            let tip = ArtPoint(c.x + cos(a) * 0.35, c.y + sin(a) * 0.35)
                            ops.append(.stroke(ArtPath(loops: [[c, tip, c]]), RGBA(hex: "#A0663A"), width: 0.06))
                        }
                    } else if roll < 0.37 {
                        // A lichened rock.
                        ops.append(.ellipse(centre: ArtPoint(c.x + 0.05, c.y + 0.06), rx: 0.26, ry: 0.17, style.shadow))
                        ops.append(.ellipse(centre: c, rx: 0.24, ry: 0.16, RGBA(hex: "#9A9A8C")))
                        ops.append(.ellipse(centre: ArtPoint(c.x - 0.07, c.y - 0.05), rx: 0.12, ry: 0.07, RGBA(hex: "#C2C2B4")))
                    }
                }
            }
        }
        return ops
    }

    private func heather(_ c: ArtPoint, rng: inout SeededRandom, flower: RGBA) -> [DrawOp] {
        var ops: [DrawOp] = [.ellipse(centre: ArtPoint(c.x + 0.04, c.y + 0.05), rx: 0.3, ry: 0.2, RGBA(hex: "#4E5530", opacity: 0.55))]
        for _ in 0..<8 {
            ops.append(.ellipse(centre: ArtPoint(c.x + (rng.unit() - 0.5) * 0.46, c.y + (rng.unit() - 0.5) * 0.3),
                                rx: 0.06, ry: 0.06, flower.opacity(0.75 + rng.unit() * 0.25)))
        }
        return ops
    }

    // MARK: Water

    func waterDetail(_ hole: Hole, land: LandKind, seed: UInt64) -> [DrawOp] {
        var ops: [DrawOp] = []
        for y in 0..<hole.rows {
            for x in 0..<hole.columns where hole[x, y] == .water {
                var rng = squareRandom(seed, x, y, salt: 23)
                // Ripples.
                if rng.chance(0.45) {
                    let c = ArtPoint(Double(x) + rng.unit(), Double(y) + rng.unit())
                    let w = 0.25 + rng.unit() * 0.2
                    ops.append(.stroke(ArtPath(loops: [[ArtPoint(c.x - w, c.y), ArtPoint(c.x, c.y - 0.06), ArtPoint(c.x + w, c.y), ArtPoint(c.x, c.y - 0.06)]]),
                                       RGBA(hex: "#FFFFFF", opacity: 0.28), width: 0.04))
                }
                let bank = [(0, -1), (1, 0), (0, 1), (-1, 0)].contains { dx, dy in
                    guard let t = hole[x + dx, y + dy] else { return false }
                    return !t.isWet
                }
                // Reeds along the banks of inland ponds.
                if bank && land != .links && rng.chance(0.5) {
                    let c = ArtPoint(Double(x) + 0.2 + rng.unit() * 0.6, Double(y) + 0.3 + rng.unit() * 0.5)
                    ops += blades(c, height: 0.38, spread: 0.24, count: 4, colour: RGBA(hex: "#4E6B36"), width: 0.04)
                    ops.append(.ellipse(centre: ArtPoint(c.x + 0.02, c.y - 0.34), rx: 0.035, ry: 0.07, RGBA(hex: "#6E4A2E")))
                }
                // Lily pads in parkland ponds.
                if !bank && land == .parkland && rng.chance(0.18) {
                    let c = ArtPoint(Double(x) + rng.unit(), Double(y) + rng.unit())
                    ops.append(.ellipse(centre: c, rx: 0.16, ry: 0.12, RGBA(hex: "#5E8F4A")))
                    ops.append(.fill(ArtPath(loops: [[c, ArtPoint(c.x + 0.17, c.y - 0.04), ArtPoint(c.x + 0.17, c.y + 0.04)]]), style.terrain("water")))
                    if rng.chance(0.4) { ops.append(.ellipse(centre: ArtPoint(c.x - 0.05, c.y - 0.03), rx: 0.04, ry: 0.04, RGBA(hex: "#F2E6EC"))) }
                }
            }
        }
        return ops
    }

    // MARK: Greens, tees and bunkers

    /// Fine two way mowing across the putting surface. Call inside a clip to the green.
    func greenStripes(_ hole: Hole) -> [DrawOp] {
        var ops: [DrawOp] = []
        let w = Double(hole.columns), h = Double(hole.rows)
        var x = 0.0
        while x < w {
            ops.append(.fill(.rect(x, 0, 0.45, h), RGBA(hex: "#FFFFFF", opacity: 0.07)))
            x += 0.9
        }
        var y = 0.0
        while y < h {
            ops.append(.fill(.rect(0, y, w, 0.45), RGBA(hex: "#000000", opacity: 0.035)))
            y += 0.9
        }
        return ops
    }

    func cup(_ hole: Hole) -> [DrawOp] {
        guard let pin = hole.pin else { return [] }
        let c = ArtPoint(Double(pin.x) + 0.5, Double(pin.y) + 0.5)
        return [.ellipse(centre: c, rx: 0.13, ry: 0.11, RGBA(hex: "#F4F0E6")),
                .ellipse(centre: ArtPoint(c.x + 0.01, c.y + 0.015), rx: 0.09, ry: 0.075, RGBA(hex: "#22301E"))]
    }

    func teeMarkers(_ hole: Hole) -> [DrawOp] {
        guard let tee = hole.tee else { return [] }
        let x = Double(tee.x), y = Double(tee.y)
        var ops: [DrawOp] = []
        // A couple of divots, then the two markers.
        ops.append(.ellipse(centre: ArtPoint(x + 0.45, y + 0.62), rx: 0.08, ry: 0.04, RGBA(hex: "#8A7A4A", opacity: 0.6)))
        ops.append(.ellipse(centre: ArtPoint(x + 0.62, y + 0.38), rx: 0.07, ry: 0.035, RGBA(hex: "#8A7A4A", opacity: 0.5)))
        for mx in [x + 0.12, x + 0.88] {
            ops.append(.ellipse(centre: ArtPoint(mx + 0.03, y + 0.5), rx: 0.09, ry: 0.06, style.shadow))
            ops.append(.ellipse(centre: ArtPoint(mx, y + 0.46), rx: 0.08, ry: 0.08, RGBA(hex: "#F4F0E6")))
            ops.append(.ellipse(centre: ArtPoint(mx - 0.02, y + 0.44), rx: 0.035, ry: 0.035, RGBA(hex: "#FFFFFF")))
        }
        return ops
    }

    /// Rake lines across the sand. Call inside a clip to the bunkers.
    func rakeLines(_ hole: Hole) -> [DrawOp] {
        var ops: [DrawOp] = []
        let w = Double(hole.columns), h = Double(hole.rows)
        var d = -h
        while d < w + h {
            // Gently wavy diagonal lines.
            var pts: [ArtPoint] = []
            var t = 0.0
            while t <= h {
                pts.append(ArtPoint(d + t * 0.55 + sin(t * 2.2) * 0.05, t))
                t += 0.5
            }
            ops.append(.stroke(ArtPath(loops: [pts + pts.reversed()]), RGBA(hex: "#F6EDCB", opacity: 0.7), width: 0.035))
            d += 0.22
        }
        return ops
    }

    // MARK: Grain

    /// A very fine speckle over everything, for the printed poster feel.
    func grain(_ hole: Hole, seed: UInt64) -> [DrawOp] {
        var rng = SeededRandom(seed: seed &+ 77)
        let w = Double(hole.columns), h = Double(hole.rows)
        return (0..<(hole.columns * hole.rows * 3)).map { k in
            let c = ArtPoint(rng.unit() * w, rng.unit() * h)
            return .ellipse(centre: c, rx: 0.035, ry: 0.035, RGBA(hex: k % 2 == 0 ? "#000000" : "#FFFFFF", opacity: 0.06))
        }
    }
}
