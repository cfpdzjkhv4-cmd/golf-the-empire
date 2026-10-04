import Foundation

/// Every feature the analysis can detect. Raw values are the keys in balance.json.
public enum FeatureKind: String, Codable, CaseIterable, Sendable {
    case island, watergreen, p3water, carry, double, dogleg, risk
    case waste, showcase, guarded = "guard", pots, drive, trees, wip
    case narrow, bland

    public var name: String {
        switch self {
        case .island: "Island green"
        case .watergreen: "Water guarding the green"
        case .p3water: "Tee shot over water"
        case .carry: "Carry over water"
        case .double: "Double dogleg"
        case .dogleg: "Dogleg"
        case .risk: "Risk and reward corner"
        case .waste: "Vast waste bunker"
        case .showcase: "Showcase bunker"
        case .guarded: "Well guarded green"
        case .pots: "Pot bunkers"
        case .drive: "Driveable par 4"
        case .trees: "Tree lined"
        case .wip: "Water in play"
        case .narrow: "Fairway too narrow"
        case .bland: "Bland, nothing to think about"
        }
    }
}

public struct HoleFeature: Equatable, Sendable {
    public let kind: FeatureKind
    /// Display name; doglegs say which way they bend.
    public let name: String
    public let points: Double
}

/// How punishing a hole is for an ordinary golfer. A first estimate from the hazards;
/// Milestone 2 calibrates it against the shot simulation.
public struct Fairness: Equatable, Sendable {
    public enum Band: String, Sendable {
        case fair = "Fair"
        case testing = "Testing"
        case brutal = "Brutal"
    }
    public let severity: Double
    public let band: Band
    /// Taken off the hole's rating (zero unless brutal).
    public let penalty: Double
}

public struct HoleAnalysis: Equatable, Sendable {
    /// Positive features, best first, then negatives.
    public let features: [HoleFeature]
    /// 1 to 10, rounded to one decimal place. Zero for an unplayable hole.
    public let score: Double
    /// 3.8 plus the small bunker and tree bonuses; features are added on top.
    public let baseScore: Double
    public let fairness: Fairness
    /// The most useful tip first.
    public let tips: [String]
    public let par: Int
    public let yards: Double

    public static let unplayable = HoleAnalysis(
        features: [], score: 0, baseScore: 0,
        fairness: Fairness(severity: 0, band: .fair, penalty: 0),
        tips: [], par: 0, yards: 0
    )

    public var isPlayable: Bool { score > 0 }
    public var positiveKinds: [FeatureKind] { features.filter { $0.points > 0 }.map(\.kind) }
}

public struct HoleAnalyzer: Sendable {
    public let balance: Balance
    private var rules: HoleRules { HoleRules(balance: balance) }
    private var a: Balance.Analysis { balance.analysis }

    public init(balance: Balance) {
        self.balance = balance
    }

    public static let tipDogleg = "Bend the fairway round a corner to make a dogleg."
    public static let tipWater = "Water in front of or around the green is the quickest way to make a hole memorable."
    public static let tipShowcase = "A big sweeping bunker, ten tiles or more, gives a hole a signature look."
    public static let tipGuard = "Ring the green with three or more bunkers."
    public static let tipNarrow = "Widen the fairway to at least three tiles."
    public static let tipBrutal = "Give golfers somewhere safe to play to. Too many hazards on one hole and ordinary golfers walk off."

    private struct FairwayRow {
        let y: Double, x: Double, minX: Int, maxX: Int, count: Int
    }

    private struct BunkerGroup {
        let size: Int, centre: GridVector
    }

    public func analyze(_ hole: Hole) -> HoleAnalysis {
        guard rules.isPlayable(hole), let teeP = hole.tee, let pinP = hole.pin else { return .unplayable }
        let par = rules.par(hole)
        let yards = rules.yards(hole)
        let tee = Hole.centre(of: teeP)
        let pin = Hole.centre(of: pinP)
        let wet: (Tile?) -> Bool = { $0?.isWet ?? false }
        var found: [HoleFeature] = []
        func add(_ kind: FeatureKind, _ name: String? = nil) {
            found.append(HoleFeature(kind: kind, name: name ?? kind.name, points: a.points(kind)))
        }
        func has(_ kind: FeatureKind) -> Bool { found.contains { $0.kind == kind } }

        // Green surround: share of the tiles touching the green that are wet.
        var ring = 0, wetRing = 0
        for y in 0..<hole.rows {
            for x in 0..<hole.columns where hole[x, y] == .green {
                for j in -1...1 {
                    for i in -1...1 where !(i == 0 && j == 0) {
                        let t = hole[x + i, y + j]
                        if t != .green {
                            ring += 1
                            if wet(t) { wetRing += 1 }
                        }
                    }
                }
            }
        }
        let wetShare = ring > 0 ? Double(wetRing) / Double(ring) : 0
        if wetShare >= a.islandGreenWaterShare {
            add(.island)
        } else if wetShare >= a.guardedGreenWaterShare {
            add(.watergreen)
        }

        // Carry: water on the straight line from tee to pin.
        var carry = false
        for k in 0...40 {
            let s = 0.1 + 0.02 * Double(k)
            let x = Int(floor(tee.x + (pin.x - tee.x) * s))
            let y = Int(floor(tee.y + (pin.y - tee.y) * s))
            if wet(hole[x, y]) {
                carry = true
                break
            }
        }
        if carry && wetShare < a.islandGreenWaterShare {
            add(par == 3 ? .p3water : .carry)
        }

        // Fairway centreline, row by row between tee and pin.
        var fairwayRows: [FairwayRow] = []
        let yFrom = Int(floor(min(tee.y, pin.y)))
        let yTo = Int(floor(max(tee.y, pin.y)))
        if yFrom <= yTo {
            for y in yFrom...yTo {
                var sum = 0.0, n = 0, minX = 99, maxX = -1
                for x in 0..<hole.columns where hole[x, y] == .fairway {
                    sum += Double(x) + 0.5
                    n += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                }
                if n > 0 {
                    fairwayRows.append(FairwayRow(y: Double(y) + 0.5, x: sum / Double(n), minX: minX, maxX: maxX, count: n))
                }
            }
        }

        // How far the fairway strays from the tee to pin line, each way.
        var devRight = 0.0, devLeft = 0.0
        var corner: FairwayRow?
        let dy = pin.y - tee.y
        for row in fairwayRows {
            let t = (row.y - tee.y) / (dy == 0 ? 1 : dy)
            let d = row.x - (tee.x + (pin.x - tee.x) * t)
            if d > devRight {
                devRight = d
                if d >= -devLeft { corner = row }
            }
            if d < devLeft {
                devLeft = d
                if -d > devRight { corner = row }
            }
        }
        var dogleg = false
        if par > 3 && fairwayRows.count >= a.minFairwayRowsForShape {
            if devRight >= a.doubleDoglegDeviation && devLeft <= -a.doubleDoglegDeviation {
                add(.double)
                dogleg = true
            } else if max(devRight, -devLeft) >= a.doglegDeviation {
                let bendsLeft = pin.x < (corner?.x ?? 8)
                add(.dogleg, bendsLeft ? "Dogleg left" : "Dogleg right")
                dogleg = true
            }
            let width = Double(fairwayRows.reduce(0) { $0 + $1.count }) / Double(fairwayRows.count)
            if width < a.narrowFairwayWidth { add(.narrow) }
        }

        // Bunker groups (tiles joined edge to edge).
        let groups = bunkerGroups(hole)
        let biggest = groups.map(\.size).max() ?? 0
        if biggest >= a.wasteBunkerTiles {
            add(.waste)
        } else if biggest >= a.showcaseBunkerTiles {
            add(.showcase)
        }
        if groups.filter({ $0.centre.distance(to: pin) <= a.guardBunkerRadius }).count >= a.guardBunkerGroups {
            add(.guarded)
        }
        if groups.filter({ $0.size <= a.potBunkerMaxTiles }).count >= a.potBunkerCount {
            add(.pots)
        }

        // Water within a tile of the fairway, when not already a carry or a guarded green.
        if !carry && wetShare < a.guardedGreenWaterShare {
            var inPlay = false
            outer: for row in fairwayRows {
                let y = Int(floor(row.y - 0.5))
                for x in (row.minX - 1)...(row.maxX + 1) where wet(hole[x, y]) {
                    inPlay = true
                    break outer
                }
            }
            if inPlay { add(.wip) }
        }

        // Trees within two tiles on both sides of most fairway rows.
        if fairwayRows.count >= a.minFairwayRowsForShape {
            let lined = fairwayRows.filter { row in
                let y = Int(floor(row.y - 0.5))
                var left = false, right = false
                for k in 1...2 {
                    if hole[row.minX - k, y] == .trees { left = true }
                    if hole[row.maxX + k, y] == .trees { right = true }
                }
                return left && right
            }.count
            if Double(lined) / Double(fairwayRows.count) >= a.treeLinedShare { add(.trees) }
        }

        // Risk and reward: a hazard tucked inside the corner of a dogleg.
        if dogleg, let corner {
            var hazard = false
            let side = (pin.x - corner.x).sign
            search: for y in Int(floor(corner.y - 4))...Int(floor(corner.y + 3)) {
                for x in 0..<hole.columns {
                    guard let t = hole[x, y], t.isWet || t == .bunker || t == .trees else { continue }
                    let off = Double(x) + 0.5 - corner.x
                    if abs(off) > 1.5 && abs(off) < 5 && off.sign == side && pin.x != corner.x {
                        hazard = true
                        break search
                    }
                }
            }
            if hazard { add(.risk) }
        }

        let protectedGreen: Set<FeatureKind> = [.guarded, .watergreen, .island, .showcase, .waste]
        if par == 4 && yards <= a.driveableMaxYards && found.contains(where: { protectedGreen.contains($0.kind) }) {
            add(.drive)
        }
        if !found.contains(where: { $0.points > 0 }) { add(.bland) }

        let baseScore = a.baseScore
            + Double(min(hole.count(of: .bunker), a.bunkerTileBonusCap)) * a.bunkerTileBonus
            + Double(min(hole.count(of: .trees), a.treeTileBonusCap)) * a.treeTileBonus
        let fairness = fairness(of: found.map(\.kind))
        let positives = found.filter { $0.points > 0 }.sorted { $0.points > $1.points }
        let negatives = found.filter { $0.points < 0 }
        let score = Self.score(base: baseScore, positives: positives.map(\.points), negatives: negatives.map(\.points) + [-fairness.penalty], balance: balance)

        var tips: [String] = []
        if fairness.band == .brutal { tips.append(Self.tipBrutal) }
        if has(.narrow) { tips.append(Self.tipNarrow) }
        if par > 3 && !dogleg { tips.append(Self.tipDogleg) }
        if !has(.island) && !has(.watergreen) && !carry { tips.append(Self.tipWater) }
        if !has(.showcase) && !has(.waste) { tips.append(Self.tipShowcase) }
        if !has(.guarded) { tips.append(Self.tipGuard) }

        return HoleAnalysis(
            features: positives + negatives, score: score, baseScore: baseScore,
            fairness: fairness, tips: tips, par: par, yards: yards
        )
    }

    /// Best feature at full value, then 80%, 65%, 50%, 40%, 30%; penalties in full. Clamped 1 to 10.
    static func score(base: Double, positives: [Double], negatives: [Double], balance: Balance) -> Double {
        let dims = balance.analysis.diminishingReturns
        var s = base
        for (i, p) in positives.sorted(by: >).enumerated() {
            s += p * dims[min(i, dims.count - 1)]
        }
        s += negatives.reduce(0, +)
        return (min(10, max(1, s)) * 10).rounded() / 10
    }

    func fairness(of kinds: [FeatureKind]) -> Fairness {
        let f = balance.fairness
        let severity = kinds.reduce(0.0) { $0 + (f.severity[$1.rawValue] ?? 0) }
        let band: Fairness.Band = severity >= f.brutalFrom ? .brutal : severity >= f.testingFrom ? .testing : .fair
        let penalty = band == .brutal ? min(f.maxPenalty, (severity - f.brutalFrom) * f.penaltyPerPointOverBrutal) : 0
        return Fairness(severity: severity, band: band, penalty: penalty)
    }

    private func bunkerGroups(_ hole: Hole) -> [BunkerGroup] {
        var seen = Array(repeating: false, count: hole.tiles.count)
        var groups: [BunkerGroup] = []
        for start in hole.tiles.indices where hole.tiles[start] == .bunker && !seen[start] {
            var stack = [start]
            seen[start] = true
            var n = 0, sx = 0, sy = 0
            while let k = stack.popLast() {
                let x = k % hole.columns, y = k / hole.columns
                n += 1
                sx += x
                sy += y
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let xx = x + dx, yy = y + dy
                    guard hole.contains(xx, yy) else { continue }
                    let kk = hole.index(xx, yy)
                    if !seen[kk] && hole.tiles[kk] == .bunker {
                        seen[kk] = true
                        stack.append(kk)
                    }
                }
            }
            groups.append(BunkerGroup(size: n, centre: GridVector(x: Double(sx) / Double(n) + 0.5, y: Double(sy) / Double(n) + 0.5)))
        }
        return groups
    }
}
