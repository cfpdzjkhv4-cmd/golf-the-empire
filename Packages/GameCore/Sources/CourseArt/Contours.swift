import GameCore

public struct ArtPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// One or more closed outlines, filled with the even odd rule (so islands and holes both work).
public struct ArtPath: Equatable, Sendable {
    public var loops: [[ArtPoint]]

    public init(loops: [[ArtPoint]]) {
        self.loops = loops
    }

    public var isEmpty: Bool { loops.isEmpty }

    public func offset(_ dx: Double, _ dy: Double) -> ArtPath {
        ArtPath(loops: loops.map { $0.map { ArtPoint($0.x + dx, $0.y + dy) } })
    }

    public static func polygon(_ pts: [(Double, Double)]) -> ArtPath {
        ArtPath(loops: [pts.map { ArtPoint($0.0, $0.1) }])
    }

    public static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> ArtPath {
        ArtPath(loops: [[ArtPoint(x, y), ArtPoint(x + w, y), ArtPoint(x + w, y + h), ArtPoint(x, y + h)]])
    }
}

/// Turns blocky tile regions into smooth, organic outlines.
///
/// Each tile type gets a soft "membership" field (how much of the surrounding area is that tile),
/// sampled several times per tile; marching squares traces where it crosses a threshold, and
/// Chaikin's corner cutting rounds off what is left. Units are tiles.
public struct ContourTracer: Sendable {
    /// Samples per tile edge.
    public let resolution: Int
    /// How far a tile's influence reaches, in tiles.
    public let reach: Double
    /// Rounds of corner cutting.
    public let smoothing: Int

    /// Points closer than this to a straight line are dropped before smoothing, so corners
    /// round off into broad curves instead of tiny bevels. In tiles.
    public let simplify: Double

    public init(resolution: Int = 4, reach: Double = 1.1, smoothing: Int = 4, simplify: Double = 0.14) {
        self.simplify = simplify
        self.resolution = resolution
        self.reach = reach
        self.smoothing = smoothing
    }

    /// Outline of every tile matching `include`. A lower threshold gives a fatter shape.
    public func outline(_ hole: Hole, threshold: Double = 0.5, include: (Tile) -> Bool) -> ArtPath {
        let margin = 2
        let s = Double(resolution)
        let w = (hole.columns + margin * 2) * resolution + 1
        let h = (hole.rows + margin * 2) * resolution + 1
        let r = Int(reach.rounded(.up))
        var field = [Double](repeating: 0, count: w * h)
        var any = false
        for j in 0..<h {
            let py = Double(j) / s - Double(margin)
            for i in 0..<w {
                let px = Double(i) / s - Double(margin)
                var inside = 0.0, total = 0.0
                let cx = Int(px.rounded(.down)), cy = Int(py.rounded(.down))
                for ty in (cy - r)...(cy + r) {
                    for tx in (cx - r)...(cx + r) {
                        let dx = Double(tx) + 0.5 - px, dy = Double(ty) + 0.5 - py
                        let d2 = (dx * dx + dy * dy) / (reach * reach)
                        guard d2 < 1 else { continue }
                        let weight = (1 - d2) * (1 - d2)
                        total += weight
                        if let t = hole[tx, ty], include(t) { inside += weight }
                    }
                }
                let v = total > 0 ? inside / total : 0
                if v > 0 { any = true }
                field[j * w + i] = v
            }
        }
        guard any else { return ArtPath(loops: []) }
        let loops = march(field, w: w, h: h, threshold: threshold).map { loop in
            smooth(simplified(loop.map { ArtPoint($0.x / s - Double(margin), $0.y / s - Double(margin)) }))
        }
        return ArtPath(loops: loops.filter { $0.count >= 3 })
    }

    // MARK: Marching squares

    private struct Segment {
        let a: Int, b: Int
        let pa: ArtPoint, pb: ArtPoint
    }

    private func march(_ f: [Double], w: Int, h: Int, threshold t: Double) -> [[ArtPoint]] {
        // Edge ids: horizontal edge from (i, j) to (i+1, j) is 2k, vertical from (i, j) to (i, j+1) is 2k+1, k = j*w + i.
        func hEdge(_ i: Int, _ j: Int) -> Int { (j * w + i) * 2 }
        func vEdge(_ i: Int, _ j: Int) -> Int { (j * w + i) * 2 + 1 }
        func lerp(_ v0: Double, _ v1: Double) -> Double { abs(v1 - v0) < 1e-9 ? 0.5 : (t - v0) / (v1 - v0) }
        func point(_ edge: Int) -> ArtPoint {
            let k = edge / 2, i = k % w, j = k / w
            if edge % 2 == 0 {
                return ArtPoint(Double(i) + lerp(f[k], f[k + 1]), Double(j))
            }
            return ArtPoint(Double(i), Double(j) + lerp(f[k], f[k + w]))
        }

        var segments: [Segment] = []
        for j in 0..<(h - 1) {
            for i in 0..<(w - 1) {
                let tl = f[j * w + i], tr = f[j * w + i + 1], br = f[(j + 1) * w + i + 1], bl = f[(j + 1) * w + i]
                let code = (tl > t ? 8 : 0) | (tr > t ? 4 : 0) | (br > t ? 2 : 0) | (bl > t ? 1 : 0)
                if code == 0 || code == 15 { continue }
                let top = hEdge(i, j), bottom = hEdge(i, j + 1), left = vEdge(i, j), right = vEdge(i + 1, j)
                var pairs: [(Int, Int)]
                switch code {
                case 1, 14: pairs = [(left, bottom)]
                case 2, 13: pairs = [(bottom, right)]
                case 3, 12: pairs = [(left, right)]
                case 4, 11: pairs = [(top, right)]
                case 6, 9: pairs = [(top, bottom)]
                case 7, 8: pairs = [(left, top)]
                case 5, 10:
                    // Saddle: decide from the centre.
                    let centre = (tl + tr + br + bl) / 4 > t
                    if (code == 5) == centre {
                        pairs = [(left, top), (bottom, right)]
                    } else {
                        pairs = [(left, bottom), (top, right)]
                    }
                default: pairs = []
                }
                for (a, b) in pairs { segments.append(Segment(a: a, b: b, pa: point(a), pb: point(b))) }
            }
        }

        // Join segments that share an edge crossing into closed loops.
        var byEdge: [Int: [Int]] = [:]
        for (n, s) in segments.enumerated() {
            byEdge[s.a, default: []].append(n)
            byEdge[s.b, default: []].append(n)
        }
        var used = [Bool](repeating: false, count: segments.count)
        var loops: [[ArtPoint]] = []
        for start in segments.indices where !used[start] {
            used[start] = true
            var loop = [segments[start].pa]
            let first = segments[start].a
            var edge = segments[start].b
            var guardCount = 0
            while edge != first && guardCount < segments.count {
                guardCount += 1
                loop.append(point(edge))
                guard let next = byEdge[edge]?.first(where: { !used[$0] }) else { break }
                used[next] = true
                edge = segments[next].a == edge ? segments[next].b : segments[next].a
            }
            loops.append(loop)
        }
        return loops
    }

    // MARK: Smoothing

    /// Ramer Douglas Peucker on a closed loop.
    private func simplified(_ loop: [ArtPoint]) -> [ArtPoint] {
        guard loop.count > 8 else { return loop }
        // Split the loop at its two most distant points and simplify each half.
        var far = 0, best = -1.0
        for (k, p) in loop.enumerated() {
            let d = (p.x - loop[0].x) * (p.x - loop[0].x) + (p.y - loop[0].y) * (p.y - loop[0].y)
            if d > best { best = d; far = k }
        }
        let first = rdp(Array(loop[0...far]))
        let second = rdp(Array(loop[far...]) + [loop[0]])
        let out = Array(first.dropLast()) + Array(second.dropLast())
        return out.count >= 3 ? out : loop
    }

    private func rdp(_ pts: [ArtPoint]) -> [ArtPoint] {
        guard pts.count > 2, let a = pts.first, let b = pts.last else { return pts }
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1e-9, (dx * dx + dy * dy).squareRoot())
        var index = 0, worst = 0.0
        for k in 1..<(pts.count - 1) {
            let d = abs((pts[k].x - a.x) * dy - (pts[k].y - a.y) * dx) / len
            if d > worst { worst = d; index = k }
        }
        guard worst > simplify else { return [a, b] }
        return Array(rdp(Array(pts[0...index])).dropLast()) + rdp(Array(pts[index...]))
    }

    private func smooth(_ loop: [ArtPoint]) -> [ArtPoint] {
        var pts = loop
        for _ in 0..<smoothing where pts.count >= 3 {
            var next: [ArtPoint] = []
            next.reserveCapacity(pts.count * 2)
            for k in pts.indices {
                let p = pts[k], q = pts[(k + 1) % pts.count]
                next.append(ArtPoint(0.75 * p.x + 0.25 * q.x, 0.75 * p.y + 0.25 * q.y))
                next.append(ArtPoint(0.25 * p.x + 0.75 * q.x, 0.25 * p.y + 0.75 * q.y))
            }
            pts = next
        }
        return pts
    }
}
