import Foundation

public struct Golfer: Codable, Equatable, Sendable {
    public let firstName: String
    public let name: String
    /// 0 to 1. Higher hits it further and straighter.
    public let skill: Double
    public let handicap: Int
}

/// What happened to one shot. Keys match Percy's line categories.
public enum ShotOutcome: String, Codable, Sendable {
    case fairway, rough, bunker, green, trees, water
    case outOfBounds = "ob"
    case puttMissed = "putt_miss"
    case holedPutt = "holed_putt"
    case holedLong = "holed_long"
}

public struct Shot: Codable, Equatable, Sendable {
    public let from: GridVector
    /// Where the ball first lands (same as `end` for a putt).
    public let landing: GridVector
    /// Where the ball finishes and the next shot is played from.
    public let end: GridVector
    public let outcome: ShotOutcome
    public let isPutt: Bool
    /// Penalty strokes added (water, out of bounds).
    public let penalty: Int
    public let holed: Bool
    /// Yards the ball flew, for animation height.
    public let carryYards: Double
}

public struct HoleResult: Codable, Equatable, Sendable {
    public let strokes: Int
    public let penalties: Int
    public let pickedUp: Bool
    public let shots: [Shot]
}

/// Plays golf shots on a hole: where a golfer aims, and where the ball ends up.
/// Ported from prototype 5; every random number comes from the caller's SeededRandom.
public struct ShotSimulator: Sendable {
    public let balance: Balance
    private var s: Balance.Shots { balance.shots }
    private var yardsPerTile: Double { balance.grid.yardsPerTile }

    public init(balance: Balance) {
        self.balance = balance
    }

    struct Target: Sendable {
        let point: GridVector
        let penalty: Double
        let nearWater: Bool
        /// Yards from here to the pin, worked out once per hole.
        let toPin: Double
    }

    /// A hole made ready for many rounds: aim points and distances worked out once.
    public struct PreparedHole: Sendable {
        public let hole: Hole
        public let par: Int
        /// Sorted nearest the pin first, so the search can skip most of them.
        let targets: [Target]
        let lowestPenalty: Double
    }

    public func prepare(_ hole: Hole) -> PreparedHole {
        let targets = targets(hole).sorted { $0.toPin < $1.toPin }
        return PreparedHole(hole: hole, par: HoleRules(balance: balance).par(hole), targets: targets,
                            lowestPenalty: targets.map(\.penalty).min() ?? 0)
    }

    // MARK: Golfers

    public func makeGolfer(reputation: Double, names: GolferNames, rng: inout SeededRandom) -> Golfer {
        let g = balance.golfers
        let skill = min(g.skillMax, max(g.skillMin, g.skillBase + rng.unit() * g.skillRandom + reputation * g.skillPerReputation))
        let first = rng.pick(names.first)
        let last = rng.pick(names.last)
        let handicap = min(36, max(0, Int(((1 - skill) * 40 - 2 + 0.5).rounded(.down))))
        return Golfer(firstName: first, name: "\(first) \(last)", skill: skill, handicap: handicap)
    }

    public func windFactor(_ weather: Weather) -> Double {
        s.windFactor[weather.rawValue] ?? 1
    }

    // MARK: A whole hole

    /// Every square a golfer might aim at: everything but water, trees and sea.
    func targets(_ hole: Hole) -> [Target] {
        var out: [Target] = []
        out.reserveCapacity(hole.tiles.count)
        for y in 0..<hole.rows {
            for x in 0..<hole.columns {
                guard let t = hole[x, y], !t.isWet, t != .trees else { continue }
                var nearWater = false
                outer: for j in -1...1 {
                    for i in -1...1 where hole[x + i, y + j]?.isWet == true {
                        nearWater = true
                        break outer
                    }
                }
                let penalty = s.targetPenalty[String(describing: t)] ?? 0
                let point = GridVector(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let toPin = hole.pin.map { yards(point, Hole.centre(of: $0)) } ?? 0
                out.append(Target(point: point, penalty: penalty, nearWater: nearWater, toPin: toPin))
            }
        }
        return out
    }

    /// Plays a hole to the end, or until the golfer picks up after 10 shots.
    public func play(_ hole: Hole, golfer: Golfer, wind: Double, rng: inout SeededRandom) -> HoleResult {
        play(prepare(hole), golfer: golfer, wind: wind, rng: &rng)
    }

    public func play(_ prepared: PreparedHole, golfer: Golfer, wind: Double, rng: inout SeededRandom) -> HoleResult {
        let hole = prepared.hole
        guard let tee = hole.tee, hole.pin != nil else {
            return HoleResult(strokes: 0, penalties: 0, pickedUp: true, shots: [])
        }
        let par = prepared.par
        var position = Hole.centre(of: tee)
        var strokes = 0, penalties = 0
        var shots: [Shot] = []
        while strokes < balance.golfers.pickUpAfterShots {
            let shot = take(prepared, golfer: golfer, from: position, wind: wind, rng: &rng)
            shots.append(shot)
            strokes += 1 + shot.penalty
            penalties += shot.penalty
            position = shot.end
            if shot.holed {
                return HoleResult(strokes: min(strokes, par + balance.golfers.pickUpOverPar), penalties: penalties, pickedUp: false, shots: shots)
            }
        }
        return HoleResult(strokes: par + balance.golfers.pickUpOverPar, penalties: penalties, pickedUp: true, shots: shots)
    }

    // MARK: One shot

    func tile(_ hole: Hole, _ p: GridVector) -> Tile? {
        hole[Int(floor(p.x)), Int(floor(p.y))]
    }

    func yards(_ a: GridVector, _ b: GridVector) -> Double {
        a.distance(to: b) * yardsPerTile
    }

    func take(_ prepared: PreparedHole, golfer: Golfer, from position: GridVector, wind: Double, rng: inout SeededRandom) -> Shot {
        let hole = prepared.hole
        let targets = prepared.targets
        let pin = Hole.centre(of: hole.pin!)
        let lie = tile(hole, position)
        let toPin = yards(position, pin)

        if lie == .green { return putt(hole, golfer: golfer, from: position, pin: pin, distance: toPin, rng: &rng) }

        // Choose a target: the pin if it's in reach, otherwise the best spot nearer the hole.
        let lieFactor: Double
        switch lie {
        case .rough: lieFactor = s.lieDistance["rough"] ?? 1
        case .tee: lieFactor = s.lieDistance["tee"] ?? 1
        case .trees: lieFactor = s.lieDistance["trees"] ?? 1
        case .bunker: lieFactor = toPin < s.bunkerShortYards ? 1 : (s.lieDistance["bunkerLong"] ?? 1)
        default: lieFactor = 1
        }
        let maxCarry = (s.baseCarry + s.carryPerSkill * golfer.skill) * lieFactor
        var best: GridVector?
        var bestScore = Double.infinity
        if toPin <= maxCarry * s.pinReachFactor {
            best = pin
            bestScore = s.pinTargetScore
        }
        let waterPenalty = s.nearWaterPenalty * (s.nearWaterSkillOffset - golfer.skill)
        let reach = maxCarry / yardsPerTile, reachSquared = reach * reach
        let minSquared = (s.minTargetYards / yardsPerTile) * (s.minTargetYards / yardsPerTile)
        // Anything in reach is at least (toPin - maxCarry) from the pin, so start the search there,
        // and stop once nothing further out could beat the best score found.
        let nearest = toPin - maxCarry - 1
        var lo = 0, hi = targets.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if targets[mid].toPin < nearest { lo = mid + 1 } else { hi = mid }
        }
        for t in targets[lo...] {
            let after = t.toPin
            if after >= toPin - s.mustGainYards || after + prepared.lowestPenalty >= bestScore { break }
            let score = after + t.penalty + (t.nearWater ? waterPenalty : 0)
            if score >= bestScore { continue }
            let dx = t.point.x - position.x, dy = t.point.y - position.y
            let d2 = dx * dx + dy * dy
            if d2 > reachSquared || d2 < minSquared { continue }
            if score < bestScore {
                bestScore = score
                best = t.point
            }
        }
        let target: GridVector
        if let best {
            target = best
        } else {
            let a = atan2(pin.y - position.y, pin.x - position.x)
            target = GridVector(x: position.x + cos(a) * maxCarry / yardsPerTile, y: position.y + sin(a) * maxCarry / yardsPerTile)
        }
        return fullShot(hole, golfer: golfer, from: position, target: target, pin: pin, lie: lie, wind: wind, rng: &rng)
    }

    private func putt(_ hole: Hole, golfer: Golfer, from position: GridVector, pin: GridVector, distance d: Double, rng: inout SeededRandom) -> Shot {
        if rng.chance(exp(-d / (s.puttHoleBase + s.puttHolePerSkill * golfer.skill))) {
            return Shot(from: position, landing: pin, end: pin, outcome: d > s.puttLongYards ? .holedLong : .holedPutt,
                        isPutt: true, penalty: 0, holed: true, carryYards: 0)
        }
        let leave = max(s.puttLeaveMin, d * (s.puttLeaveBase + rng.unit() * s.puttLeaveRandom * (s.puttLeaveSkillOffset - golfer.skill)))
        let a = rng.unit() * .pi * 2
        var end = GridVector(x: pin.x + cos(a) * leave / yardsPerTile, y: pin.y + sin(a) * leave / yardsPerTile)
        for _ in 0..<12 where tile(hole, end) != .green {
            end = GridVector(x: (end.x + pin.x) / 2, y: (end.y + pin.y) / 2)
        }
        return Shot(from: position, landing: end, end: end, outcome: .puttMissed, isPutt: true, penalty: 0, holed: false, carryYards: 0)
    }

    private func fullShot(_ hole: Hole, golfer: Golfer, from position: GridVector, target: GridVector, pin: GridVector,
                          lie: Tile?, wind: Double, rng: inout SeededRandom) -> Shot {
        let lieError: Double
        switch lie {
        case .rough: lieError = s.lieError["rough"] ?? 1
        case .bunker: lieError = s.lieError["bunker"] ?? 1
        case .trees: lieError = s.lieError["trees"] ?? 1
        default: lieError = 1
        }
        let missing = 1 - golfer.skill
        var angle = atan2(target.y - position.y, target.x - position.x)
            + gauss(&rng) * (s.aimErrorBase + s.aimErrorPerMissingSkill * missing) * lieError * wind
        if rng.chance(s.shankChancePerMissingSkill * missing) {
            angle += Double(rng.sign()) * (s.shankAngleMin + rng.unit() * s.shankAngleRandom)
        }
        let planned = yards(position, target)
        let carry = max(s.minCarry, planned * (1 + gauss(&rng) * (s.lengthErrorBase + s.lengthErrorPerMissingSkill * missing) * lieError * wind))
        let landing = GridVector(x: position.x + cos(angle) * carry / yardsPerTile, y: position.y + sin(angle) * carry / yardsPerTile)

        let r = s.roll
        let roll: Double
        switch tile(hole, landing) {
        case .fairway: roll = (r["fairwayMin"] ?? 0) + rng.unit() * (r["fairwayRandom"] ?? 0)
        case .green: roll = (r["greenMin"] ?? 0) + rng.unit() * (r["greenRandom"] ?? 0)
        case .rough: roll = (r["roughMin"] ?? 0) + rng.unit() * (r["roughRandom"] ?? 0)
        case .tee: roll = r["tee"] ?? 0
        default: roll = 0
        }
        var end = landing
        if roll > 0 {
            let steps = Int(ceil(roll / yardsPerTile / 0.25))
            for step in 1...max(1, steps) {
                let f = roll / yardsPerTile * Double(step) / Double(steps)
                end = GridVector(x: landing.x + cos(angle) * f, y: landing.y + sin(angle) * f)
                let t = tile(hole, end)
                if t == nil || t == .bunker || t == .water || t == .trees || t == .sea { break }
            }
        }

        func shot(_ end: GridVector, _ outcome: ShotOutcome, penalty: Int = 0, holed: Bool = false) -> Shot {
            Shot(from: position, landing: landing, end: end, outcome: outcome, isPutt: false, penalty: penalty, holed: holed, carryYards: carry)
        }

        switch tile(hole, end) {
        case nil:
            // Out of bounds: stroke and distance.
            return shot(position, .outOfBounds, penalty: 1)
        case .water, .sea:
            // Drop back along the line of flight on the first dry ground.
            let a = atan2(position.y - end.y, position.x - end.x)
            var p = end
            for _ in 0..<80 {
                p = GridVector(x: p.x + cos(a) * 0.25, y: p.y + sin(a) * 0.25)
                if let q = tile(hole, p), !q.isWet { break }
            }
            if tile(hole, p) == nil || tile(hole, p)?.isWet == true { p = position }
            return Shot(from: position, landing: landing, end: p, outcome: .water, isPutt: false, penalty: 1, holed: false, carryYards: carry)
        case .trees:
            // Chip out sideways to the nearest open square.
            let fx = Int(floor(end.x)), fy = Int(floor(end.y))
            var bestPoint: GridVector?
            var bestDistance = Double.infinity
            for j in -1...1 {
                for i in -1...1 {
                    guard let q = hole[fx + i, fy + j], !q.isWet, q != .trees else { continue }
                    let c = GridVector(x: Double(fx + i) + 0.5, y: Double(fy + j) + 0.5)
                    let d = yards(c, position)
                    if d < bestDistance {
                        bestDistance = d
                        bestPoint = c
                    }
                }
            }
            return shot(bestPoint ?? end, .trees)
        case .green:
            if yards(end, pin) < s.chipInYards && rng.chance(s.chipInChance) {
                return shot(pin, .holedLong, holed: true)
            }
            return shot(end, .green)
        case .bunker: return shot(end, .bunker)
        case .rough: return shot(end, .rough)
        default: return shot(end, .fairway)
        }
    }

    private func gauss(_ rng: inout SeededRandom) -> Double {
        var u = 0.0, v = 0.0
        while u == 0 { u = rng.unit() }
        while v == 0 { v = rng.unit() }
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }
}
