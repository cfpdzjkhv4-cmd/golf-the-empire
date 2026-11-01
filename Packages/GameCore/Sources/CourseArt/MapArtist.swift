import Foundation
import GameCore

/// The illustrated map of Britain: Ordnance Survey meets travel poster.
/// Works in "map units" (see `x(_:)` and `y(_:)`), which the renderer scales to fit;
/// pins are placed with the same two functions so they always land in the right place.
public struct MapArtist: Sendable {
    public let style: ArtStyle

    public init(style: ArtStyle = .shared) {
        self.style = style
    }

    /// East to west is squashed for Britain's latitude.
    public static func x(_ lon: Double) -> Double { (lon + 6.4) * 57.4 }
    public static func y(_ lat: Double) -> Double { (58.85 - lat) * 100 }

    /// The area the map covers, in map units, with a margin of sea all round.
    public static func bounds(_ map: MapData) -> (minX: Double, minY: Double, width: Double, height: Double) {
        let pts = map.mainland + map.islands.flatMap { $0 }
        let xs = pts.map { x($0.lon) }, ys = pts.map { y($0.lat) }
        let margin = 18.0
        let minX = (xs.min() ?? 0) - margin, minY = (ys.min() ?? 0) - margin
        return (minX, minY, (xs.max() ?? 1) + margin - minX, (ys.max() ?? 1) + margin - minY)
    }

    // Upland areas, as (lat, lon, radius north to south in degrees, radius east to west in degrees, strength).
    private static let hills: [(Double, Double, Double, Double, Double)] = [
        (57.2, -4.6, 0.75, 1.5, 1.0),    // Highlands
        (57.0, -3.6, 0.35, 0.6, 0.9),    // Cairngorms
        (58.1, -4.7, 0.4, 0.8, 0.7),     // Far north west
        (55.4, -3.5, 0.28, 0.9, 0.6),    // Southern Uplands
        (54.5, -3.1, 0.22, 0.3, 0.8),    // Lake District
        (54.3, -2.2, 0.75, 0.3, 0.6),    // Pennines
        (53.35, -1.85, 0.2, 0.25, 0.5),  // Peak District
        (54.38, -0.9, 0.15, 0.3, 0.4),   // North York Moors
        (52.95, -3.9, 0.35, 0.35, 0.8),  // Snowdonia
        (52.3, -3.7, 0.35, 0.35, 0.5),   // Cambrian Mountains
        (51.88, -3.45, 0.13, 0.4, 0.5),  // Brecon Beacons
        (50.58, -3.92, 0.13, 0.2, 0.5),  // Dartmoor
        (51.12, -3.65, 0.08, 0.2, 0.35), // Exmoor
    ]

    public func paint(_ map: MapData) -> [DrawOp] {
        let b = Self.bounds(map)
        let frame = ArtPath.rect(b.minX, b.minY, b.width, b.height)
        var ops: [DrawOp] = [.clip(frame)]
        let sea = RGBA(hex: style.mapColour("sea")), seaDeep = RGBA(hex: style.mapColour("seaDeep"))

        // Sea, deeper away from the coast, with a few lines of swell.
        ops.append(.fill(frame, sea))
        ops.append(.ellipse(centre: ArtPoint(b.minX + b.width * 0.05, b.minY + b.height * 0.55), rx: b.width * 0.5, ry: b.height * 0.75, seaDeep.opacity(0.14)))
        ops.append(.ellipse(centre: ArtPoint(b.minX + b.width * 0.95, b.minY + b.height * 0.25), rx: b.width * 0.45, ry: b.height * 0.55, seaDeep.opacity(0.12)))
        var rng = SeededRandom(seed: 1066)
        for _ in 0..<70 {
            let cx = b.minX + rng.unit() * b.width, cy = b.minY + rng.unit() * b.height
            let w = 6 + rng.unit() * 10
            ops.append(.stroke(ArtPath(loops: [[ArtPoint(cx - w, cy), ArtPoint(cx - w / 2, cy - 1.6), ArtPoint(cx, cy), ArtPoint(cx + w / 2, cy - 1.6), ArtPoint(cx + w, cy)]]),
                               RGBA(hex: "#FFFFFF", opacity: 0.18), width: 0.9))
        }

        // Land: a soft shadow, a pale coastal fringe, then the land itself.
        let shapes = ([map.mainland] + map.islands).map { smooth($0.map { ArtPoint(Self.x($0.lon), Self.y($0.lat)) }) }
        let land = ArtPath(loops: shapes)
        ops.append(.stroke(land, RGBA(hex: style.mapColour("shallows"), opacity: 0.9), width: 9))
        ops.append(.fill(land.offset(2.5, 3.5), RGBA(hex: style.mapColour("coast"), opacity: 0.35)))
        ops.append(.fill(land, RGBA(hex: style.mapColour("land"))))

        // Hills, shaded inside the coastline.
        ops.append(.clip(land))
        let hillColour = RGBA(hex: style.mapColour("hills"))
        for (lat, lon, rLat, rLon, strength) in Self.hills {
            let c = ArtPoint(Self.x(lon), Self.y(lat))
            for k in 0..<4 {
                let f = 1 - Double(k) * 0.22
                ops.append(.ellipse(centre: ArtPoint(c.x + Double(k) * 1.2, c.y + Double(k) * 1.2),
                                    rx: rLon * 57.4 * f, ry: rLat * 100 * f, hillColour.opacity(0.16 * strength)))
            }
        }
        // A little paper grain across the land.
        for _ in 0..<500 {
            let cx = b.minX + rng.unit() * b.width, cy = b.minY + rng.unit() * b.height
            ops.append(.ellipse(centre: ArtPoint(cx, cy), rx: 0.6, ry: 0.6, RGBA(hex: style.mapColour("hills"), opacity: 0.12)))
        }
        ops.append(.endClip)

        // Ordnance Survey style coastline: a firm line with a faint second one offshore.
        ops.append(.stroke(land, RGBA(hex: style.mapColour("coast")), width: 1.3))
        for loop in shapes {
            ops.append(.stroke(ArtPath(loops: [offsetOutward(loop, by: 3.2)]), RGBA(hex: style.mapColour("coast"), opacity: 0.35), width: 0.6))
        }

        // Compass rose, top right.
        let rose = ArtPoint(b.minX + b.width - 52, b.minY + 60)
        ops.append(contentsOf: compass(at: rose, size: 30))
        ops.append(.endClip)
        return ops
    }

    // MARK: Pieces

    private func compass(at c: ArtPoint, size r: Double) -> [DrawOp] {
        let ink = RGBA(hex: style.mapColour("ink"))
        var ops: [DrawOp] = [.ellipse(centre: c, rx: r * 0.72, ry: r * 0.72, RGBA(hex: style.mapColour("land"), opacity: 0.7)),
                             .stroke(ArtPath(loops: [circle(c, r * 0.72)]), ink.opacity(0.6), width: 0.8)]
        for (k, len) in [(0, 1.0), (1, 0.55), (2, 0.8), (3, 0.55), (4, 0.8), (5, 0.55), (6, 0.8), (7, 0.55)] {
            let a = Double(k) * .pi / 4 - .pi / 2
            let tip = ArtPoint(c.x + cos(a) * r * len, c.y + sin(a) * r * len)
            let l = ArtPoint(c.x + cos(a - 0.5) * r * 0.14, c.y + sin(a - 0.5) * r * 0.14)
            let rr = ArtPoint(c.x + cos(a + 0.5) * r * 0.14, c.y + sin(a + 0.5) * r * 0.14)
            ops.append(.fill(ArtPath(loops: [[l, tip, rr, c]]), k == 0 ? style.gold : ink.opacity(k % 2 == 0 ? 0.75 : 0.45)))
        }
        return ops
    }

    private func circle(_ c: ArtPoint, _ r: Double) -> [ArtPoint] {
        (0..<36).map { k in
            let a = Double(k) / 36 * 2 * .pi
            return ArtPoint(c.x + cos(a) * r, c.y + sin(a) * r)
        }
    }

    /// Chaikin corner cutting, twice, so the coastline flows instead of zigzagging.
    private func smooth(_ loop: [ArtPoint]) -> [ArtPoint] {
        var pts = loop
        for _ in 0..<2 {
            var next: [ArtPoint] = []
            for k in pts.indices {
                let p = pts[k], q = pts[(k + 1) % pts.count]
                next.append(ArtPoint(0.75 * p.x + 0.25 * q.x, 0.75 * p.y + 0.25 * q.y))
                next.append(ArtPoint(0.25 * p.x + 0.75 * q.x, 0.25 * p.y + 0.75 * q.y))
            }
            pts = next
        }
        return pts
    }

    /// The loop pushed outwards (away from its centre) by a fixed distance, for the offshore line.
    private func offsetOutward(_ loop: [ArtPoint], by d: Double) -> [ArtPoint] {
        let n = loop.count
        guard n > 2 else { return loop }
        // Work out which way is "out" from the winding direction.
        var area = 0.0
        for k in 0..<n { let p = loop[k], q = loop[(k + 1) % n]; area += p.x * q.y - q.x * p.y }
        let sign = area > 0 ? -1.0 : 1.0
        return (0..<n).map { k in
            let a = loop[(k + n - 1) % n], b = loop[(k + 1) % n]
            var nx = b.y - a.y, ny = -(b.x - a.x)
            let len = max(1e-9, (nx * nx + ny * ny).squareRoot())
            nx /= len
            ny /= len
            return ArtPoint(loop[k].x + nx * d * sign, loop[k].y + ny * d * sign)
        }
    }
}
