import Foundation
import GameCore

/// One drawing instruction. Coordinates are in tiles; the renderer scales them.
/// Every art decision lives in HoleArtist; renderers (CoreGraphics in the app,
/// SVG for previews) just follow these instructions.
public enum DrawOp: Equatable, Sendable {
    case fill(ArtPath, RGBA)
    case stroke(ArtPath, RGBA, width: Double)
    case ellipse(centre: ArtPoint, rx: Double, ry: Double, RGBA)
    /// Clip everything until the matching `endClip` to this path.
    case clip(ArtPath)
    case endClip
}

/// Paints a hole in the house style: flat illustration with soft shading, light from the top left.
public struct HoleArtist: Sendable {
    public let style: ArtStyle
    public let tracer: ContourTracer

    public init(style: ArtStyle = .shared, tracer: ContourTracer = ContourTracer()) {
        self.style = style
        self.tracer = tracer
    }

    /// `seed` should stay the same for a hole as it is edited (plot and hole number),
    /// so the rough's pattern doesn't jump about while painting.
    /// `condition` (20 to 100) browns the turf and scatters bare patches as it falls below 75.
    public func paint(_ hole: Hole, land: LandKind, seed: UInt64, condition: Double = 85) -> [DrawOp] {
        var ops: [DrawOp] = []
        let landStyle = style.land(land)
        let bounds = ArtPath.rect(0, 0, Double(hole.columns), Double(hole.rows))
        var rng = SeededRandom(seed: seed)
        ops.append(.clip(bounds))

        // Rough, with soft mottling so it reads as grass rather than a flat fill.
        ops.append(.fill(bounds, RGBA(hex: landStyle.rough)))
        for _ in 0..<(hole.columns * hole.rows / 2) {
            let c = ArtPoint(rng.unit() * Double(hole.columns), rng.unit() * Double(hole.rows))
            let rx = 0.18 + rng.unit() * 0.4
            ops.append(.ellipse(centre: c, rx: rx, ry: rx * (0.45 + rng.unit() * 0.3), RGBA(hex: landStyle.roughMottle, opacity: 0.45)))
        }

        // Sea, with a line of surf.
        let sea = tracer.outline(hole) { $0 == .sea }
        if !sea.isEmpty {
            ops.append(.fill(tracer.outline(hole, threshold: 0.3) { $0 == .sea }, style.terrain("beach")))
            ops.append(.fill(sea, style.terrain("sea")))
            ops.append(.stroke(sea, style.terrain("seaFoam", opacity: 0.8), width: 0.12))
        }

        // Water: bank shadow on the top left inside edge, a little sky reflected bottom right.
        let water = tracer.outline(hole) { $0 == .water || $0 == .bridge }
        if !water.isEmpty {
            ops.append(.fill(water, style.terrain("waterShade")))
            ops.append(.clip(water))
            ops.append(.fill(water.offset(0.14, 0.18), style.terrain("water")))
            for loop in water.loops {
                let c = centroid(loop)
                ops.append(.ellipse(centre: ArtPoint(c.x + 0.4, c.y + 0.35), rx: 0.7, ry: 0.12, style.terrain("waterHighlight", opacity: 0.55)))
                ops.append(.ellipse(centre: ArtPoint(c.x - 0.3, c.y + 0.75), rx: 0.4, ry: 0.08, style.terrain("waterHighlight", opacity: 0.4)))
            }
            ops.append(.endClip)
            ops.append(.stroke(water, style.terrain("waterShade", opacity: 0.8), width: 0.08))
        }
        ops.append(contentsOf: bridges(hole))

        // Fairway with mowing stripes across the line of play.
        let fairway = tracer.outline(hole) { $0 == .fairway }
        if !fairway.isEmpty {
            // First cut of rough round the fairway.
            ops.append(.fill(tracer.outline(hole, threshold: 0.28) { $0 == .fairway }, style.terrain("firstCut")))
            ops.append(.fill(fairway, style.terrain("fairway")))
            ops.append(.clip(fairway))
            for stripe in stripes(hole) { ops.append(.fill(stripe, style.terrain("fairwayStripe", opacity: 0.7))) }
            ops.append(.endClip)
        }

        // Tee box.
        if let tee = hole.tee {
            let x = Double(tee.x), y = Double(tee.y)
            ops.append(.fill(.rect(x - 0.15, y + 0.05, 1.3, 0.95), style.terrain("teeEdge")))
            ops.append(.fill(.rect(x - 0.1, y + 0.05, 1.2, 0.85), style.terrain("tee")))
        }

        // Green: a fringe, the putting surface, and a soft sheen.
        let fringe = tracer.outline(hole, threshold: 0.3) { $0 == .green }
        let green = tracer.outline(hole) { $0 == .green }
        if !green.isEmpty {
            // Greens sit slightly proud of the ground, so they cast a soft shadow.
            ops.append(.fill(fringe.offset(style.shadowOffset.x * 0.6, style.shadowOffset.y * 0.6), style.shadow.opacity(style.shadow.a * 0.6)))
            ops.append(.fill(fringe, style.terrain("fringe")))
            ops.append(.fill(green, style.terrain("green")))
            ops.append(.clip(green))
            for loop in green.loops {
                let c = centroid(loop)
                ops.append(.ellipse(centre: ArtPoint(c.x - 0.4, c.y - 0.35), rx: 1.3, ry: 0.9, style.terrain("greenHighlight", opacity: 0.6)))
            }
            ops.append(.endClip)
        }

        // A tired course: browner fairways and greens, with worn patches.
        let wear = max(0, min(1, (75 - condition) / 55))
        if wear > 0 && !(fairway.isEmpty && green.isEmpty) {
            let turf = ArtPath(loops: fringe.loops + fairway.loops)
            ops.append(.clip(turf))
            ops.append(.fill(bounds, style.terrain("straw", opacity: 0.45 * wear)))
            var wearRng = SeededRandom(seed: seed &+ 99)
            for _ in 0..<Int(wear * 60) {
                let c = ArtPoint(wearRng.unit() * Double(hole.columns), wearRng.unit() * Double(hole.rows))
                let r = 0.15 + wearRng.unit() * 0.35
                ops.append(.ellipse(centre: c, rx: r, ry: r * 0.7, style.terrain("wornTurf", opacity: 0.7)))
            }
            ops.append(.endClip)
        }

        // Bunkers: a grassy lip, then sand with the top left inside in shade (they are hollows).
        let sand = tracer.outline(hole, threshold: 0.45) { $0 == .bunker }
        if !sand.isEmpty {
            ops.append(.fill(tracer.outline(hole, threshold: 0.3) { $0 == .bunker }, style.terrain("sandLip", opacity: 0.7)))
            ops.append(.fill(sand, style.terrain("sandShade")))
            ops.append(.clip(sand))
            ops.append(.fill(sand.offset(0.2, 0.26), style.terrain("sand")))
            ops.append(.endClip)
        }

        // Trees and bushes: all the shadows first, then canopies from the top down.
        let trees = treePositions(hole, land: land, seed: seed)
        for t in trees {
            ops.append(.ellipse(centre: ArtPoint(t.centre.x + style.shadowOffset.x * t.radius * 2.2, t.centre.y + style.shadowOffset.y * t.radius * 2.2),
                                rx: t.radius * 1.05, ry: t.radius * 0.8, style.shadow))
        }
        for t in trees {
            ops.append(contentsOf: canopy(t, land: land))
        }

        ops.append(.endClip)
        return ops
    }

    // MARK: Pieces

    struct TreeSpot {
        let centre: ArtPoint
        let radius: Double
        let variant: Int
    }

    /// One canopy per tree tile, jittered by a seed tied to that square so trees don't move when you paint elsewhere.
    func treePositions(_ hole: Hole, land: LandKind, seed: UInt64) -> [TreeSpot] {
        let size: ClosedRange<Double>
        switch land {
        case .parkland: size = 0.62...0.85
        case .heathland: size = 0.5...0.68
        case .links: size = 0.42...0.58
        case .moorland: size = 0.4...0.55
        }
        var spots: [TreeSpot] = []
        for y in 0..<hole.rows {
            for x in 0..<hole.columns where hole[x, y] == .trees {
                var rng = SeededRandom(seed: seed &+ UInt64(y * 977 + x * 131 + 7))
                let r = size.lowerBound + rng.unit() * (size.upperBound - size.lowerBound)
                spots.append(TreeSpot(centre: ArtPoint(Double(x) + 0.5 + (rng.unit() - 0.5) * 0.35, Double(y) + 0.5 + (rng.unit() - 0.5) * 0.35),
                                      radius: r, variant: rng.int(0...2)))
            }
        }
        return spots
    }

    func canopy(_ t: TreeSpot, land: LandKind) -> [DrawOp] {
        let l = style.land(land)
        let dark = RGBA(hex: l.tree), light = RGBA(hex: l.treeLight)
        let c = t.centre, r = t.radius
        var ops: [DrawOp] = []
        switch land {
        case .heathland:
            // Scots pine: a dark, lumpy crown of several clumps.
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi + Double(t.variant)
                ops.append(.ellipse(centre: ArtPoint(c.x + cos(a) * r * 0.45, c.y + sin(a) * r * 0.45), rx: r * 0.55, ry: r * 0.55, dark))
            }
            ops.append(.ellipse(centre: ArtPoint(c.x - r * 0.25, c.y - r * 0.3), rx: r * 0.35, ry: r * 0.3, light))
        case .links:
            // Gorse: low, round bushes with yellow flowers.
            ops.append(.ellipse(centre: c, rx: r, ry: r * 0.9, dark))
            ops.append(.ellipse(centre: ArtPoint(c.x - r * 0.3, c.y - r * 0.3), rx: r * 0.55, ry: r * 0.45, light))
            for k in 0..<4 {
                let a = Double(k) * 1.7 + Double(t.variant)
                ops.append(.ellipse(centre: ArtPoint(c.x + cos(a) * r * 0.55, c.y + sin(a) * r * 0.5), rx: 0.07, ry: 0.07, RGBA(hex: l.flower)))
            }
        default:
            // Broadleaf (oak) and moorland scrub: a round crown lit from the top left.
            ops.append(.ellipse(centre: c, rx: r, ry: r, dark))
            ops.append(.ellipse(centre: ArtPoint(c.x - r * 0.28, c.y - r * 0.3), rx: r * 0.62, ry: r * 0.58, light))
            ops.append(.ellipse(centre: ArtPoint(c.x - r * 0.42, c.y - r * 0.45), rx: r * 0.25, ry: r * 0.22, light.opacity(0.8)))
        }
        return ops
    }

    /// Wooden footbridges: a deck of planks with a rail each side, casting a shadow on the water.
    func bridges(_ hole: Hole) -> [DrawOp] {
        var ops: [DrawOp] = []
        let wood = style.terrain("bridgeWood"), rail = style.terrain("bridgeRail")
        for y in 0..<hole.rows {
            for x in 0..<hole.columns where hole[x, y] == .bridge {
                let fx = Double(x), fy = Double(y)
                let across = hole[x - 1, y] == .bridge || hole[x + 1, y] == .bridge
                let along = hole[x, y - 1] == .bridge || hole[x, y + 1] == .bridge
                // Decks run up and down unless the bridge clearly runs side to side.
                let vertical = along || !across
                let deck: ArtPath = vertical ? .rect(fx + 0.22, fy - 0.05, 0.56, 1.1) : .rect(fx - 0.05, fy + 0.22, 1.1, 0.56)
                ops.append(.fill(deck.offset(0.1, 0.14), style.shadow))
                ops.append(.fill(deck, wood))
                for k in 1...4 {
                    let t = Double(k) * 0.2
                    let plank: ArtPath = vertical ? .rect(fx + 0.22, fy + t, 0.56, 0.025) : .rect(fx + t, fy + 0.22, 0.025, 0.56)
                    ops.append(.fill(plank, rail.opacity(0.5)))
                }
                if vertical {
                    ops.append(.fill(.rect(fx + 0.2, fy - 0.05, 0.06, 1.1), rail))
                    ops.append(.fill(.rect(fx + 0.74, fy - 0.05, 0.06, 1.1), rail))
                } else {
                    ops.append(.fill(.rect(fx - 0.05, fy + 0.2, 1.1, 0.06), rail))
                    ops.append(.fill(.rect(fx - 0.05, fy + 0.74, 1.1, 0.06), rail))
                }
            }
        }
        return ops
    }

    /// Bands one and a bit tiles wide, square to the line from tee to pin.
    func stripes(_ hole: Hole) -> [ArtPath] {
        let tee = hole.tee.map(Hole.centre(of:)) ?? GridVector(x: Double(hole.columns) / 2, y: Double(hole.rows) - 1)
        let pin = hole.pin.map(Hole.centre(of:)) ?? GridVector(x: Double(hole.columns) / 2, y: 2)
        var dx = pin.x - tee.x, dy = pin.y - tee.y
        let len = max(0.001, (dx * dx + dy * dy).squareRoot())
        dx /= len
        dy /= len
        let px = -dy, py = dx
        let width = 1.3, reach = Double(hole.rows + hole.columns)
        var out: [ArtPath] = []
        var d = -reach
        while d < reach {
            let ax = tee.x + dx * d, ay = tee.y + dy * d
            let bx = ax + dx * width, by = ay + dy * width
            out.append(ArtPath(loops: [[ArtPoint(ax - px * reach, ay - py * reach), ArtPoint(ax + px * reach, ay + py * reach),
                                        ArtPoint(bx + px * reach, by + py * reach), ArtPoint(bx - px * reach, by - py * reach)]]))
            d += width * 2
        }
        return out
    }

    private func centroid(_ loop: [ArtPoint]) -> ArtPoint {
        let n = Double(max(1, loop.count))
        return ArtPoint(loop.reduce(0) { $0 + $1.x } / n, loop.reduce(0) { $0 + $1.y } / n)
    }
}

extension DrawOp {
    /// The same instruction moved by (dx, dy) tiles.
    public func translated(_ dx: Double, _ dy: Double) -> DrawOp {
        switch self {
        case .fill(let p, let c): .fill(p.offset(dx, dy), c)
        case .stroke(let p, let c, let w): .stroke(p.offset(dx, dy), c, width: w)
        case .ellipse(let centre, let rx, let ry, let c): .ellipse(centre: ArtPoint(centre.x + dx, centre.y + dy), rx: rx, ry: ry, c)
        case .clip(let p): .clip(p.offset(dx, dy))
        case .endClip: .endClip
        }
    }
}
