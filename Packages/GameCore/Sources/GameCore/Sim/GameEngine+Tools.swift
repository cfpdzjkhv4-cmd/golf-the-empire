/// The phone friendly build tools: smooth strokes, ringing a green, and bunker stamps.
public enum RingStyle: String, CaseIterable, Sendable {
    /// All the way round: water makes an island green.
    case all
    /// Only the side facing the tee: water or sand guarding the front.
    case front
}

extension GameEngine {
    /// Paints from the last touched square to this one, filling the gap, so a quick drag
    /// leaves an unbroken (and, with a big brush, curving) fairway.
    @discardableResult
    public mutating func buildStroke(_ tool: BuildTool, courseID: String, hole: Int, from: GridPoint?, to: GridPoint, brushRadius: Int = 0) -> BuildResult {
        guard case .paint = tool, let from, from != to else {
            return build(tool, courseID: courseID, hole: hole, at: to, brushRadius: brushRadius)
        }
        var total = 0
        var last: BuildResult = .nothingChanged
        let steps = max(abs(to.x - from.x), abs(to.y - from.y))
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let p = GridPoint(x: Int((Double(from.x) + Double(to.x - from.x) * t).rounded()),
                              y: Int((Double(from.y) + Double(to.y - from.y) * t).rounded()))
            let result = build(tool, courseID: courseID, hole: hole, at: p, brushRadius: brushRadius)
            if case .built(let cost) = result { total += cost }
            if case .notEnoughCash = result { return total > 0 ? .built(cost: total) : result }
            last = result
        }
        return total > 0 ? .built(cost: total) : last
    }

    /// Rings the green with water or sand. Water `all` the way round makes an island green;
    /// `front` guards the side facing the tee. Width is in tiles.
    @discardableResult
    public mutating func ringGreen(courseID: String, hole holeIndex: Int, with tile: Tile, style: RingStyle, width: Int = 2) -> BuildResult {
        guard let course = state.courses[courseID], course.holes.indices.contains(holeIndex) else { return .noSuchHole }
        let hole = course.holes[holeIndex]
        var greens: [GridPoint] = []
        for y in 0..<hole.rows { for x in 0..<hole.columns where hole[x, y] == .green { greens.append(GridPoint(x: x, y: y)) } }
        guard !greens.isEmpty else { return .pinMustBeOnGreen }
        let cx = Double(greens.reduce(0) { $0 + $1.x }) / Double(greens.count) + 0.5
        let cy = Double(greens.reduce(0) { $0 + $1.y }) / Double(greens.count) + 0.5
        let tee = hole.tee.map(Hole.centre(of:)) ?? GridVector(x: cx, y: Double(hole.rows))
        var changes: [GridPoint] = []
        for y in 0..<hole.rows {
            for x in 0..<hole.columns {
                guard let t = hole[x, y], t != .green, t != .tee, t != .sea, t != tile else { continue }
                let near = greens.contains { abs($0.x - x) <= width && abs($0.y - y) <= width }
                guard near else { continue }
                if style == .front {
                    let vx = Double(x) + 0.5 - cx, vy = Double(y) + 0.5 - cy
                    if vx * (tee.x - cx) + vy * (tee.y - cy) <= 0 { continue }
                }
                changes.append(GridPoint(x: x, y: y))
            }
        }
        return apply(changes.map { ($0, tile) }, courseID: courseID, hole: holeIndex)
    }

    /// Stamp ids, in tool bar order.
    public var stampIDs: [String] { data.balance.stamps.order }

    /// Drops a bunker shape centred where you tap. Leaves greens, tees and the sea alone.
    @discardableResult
    public mutating func stamp(_ id: String, courseID: String, hole holeIndex: Int, at point: GridPoint) -> BuildResult {
        guard let rows = data.balance.stamps.shapes[id] else { return .nothingChanged }
        guard let course = state.courses[courseID], course.holes.indices.contains(holeIndex) else { return .noSuchHole }
        let hole = course.holes[holeIndex]
        let height = rows.count, width = rows.map(\.count).max() ?? 0
        var changes: [(GridPoint, Tile)] = []
        for (j, row) in rows.enumerated() {
            for (i, ch) in row.enumerated() where ch == "#" {
                let x = point.x + i - width / 2, y = point.y + j - height / 2
                guard let t = hole[x, y], t != .green, t != .tee, t != .sea, t != .bunker else { continue }
                changes.append((GridPoint(x: x, y: y), .bunker))
            }
        }
        return apply(changes, courseID: courseID, hole: holeIndex)
    }

    /// Applies a set of tile changes as one undo step, all or nothing on cost.
    private mutating func apply(_ changes: [(GridPoint, Tile)], courseID: String, hole holeIndex: Int) -> BuildResult {
        guard !changes.isEmpty, var course = state.courses[courseID] else { return .nothingChanged }
        let before = course.holes[holeIndex]
        var hole = before
        let cost = changes.reduce(0) { $0 + data.balance.tileCost.cost(of: $1.1) }
        guard state.cash >= cost else { return .notEnoughCash(needed: cost) }
        for (p, t) in changes {
            if hole.pin == p { hole.pin = nil }
            hole.set(p.x, p.y, t)
        }
        endStroke()
        undoSteps.append(UndoStep(courseID: courseID, holeIndex: holeIndex, before: before, cost: cost))
        if undoSteps.count > Self.maxUndoSteps { undoSteps.removeFirst() }
        course.holes[holeIndex] = hole
        state.courses[courseID] = course
        if cost > 0 { spend(.buildingWork, cost) }
        return .built(cost: cost)
    }
}
