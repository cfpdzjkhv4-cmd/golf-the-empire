/// How a hole actually plays for ordinary golfers, from the shot simulation.
public struct Playtest: Equatable, Sendable {
    public let par: Int
    public let averageStrokes: Double
    public let averageOverPar: Double
    /// Penalty strokes (water, out of bounds) per golfer.
    public let ballsLost: Double
    /// Share of golfers who gave up and picked up.
    public let pickUpRate: Double
    public let band: Fairness.Band
}

extension ShotSimulator {
    /// Sends a fixed set of ordinary golfers (skill 0.3 to 0.6) round one hole in calm weather.
    /// Seeded from the hole itself, so the same hole always gives the same answer.
    public func playtest(_ hole: Hole) -> Playtest? {
        guard HoleRules(balance: balance).isPlayable(hole) else { return nil }
        let p = balance.fairness.playtest
        let prepared = prepare(hole)
        var rng = SeededRandom(seed: Self.fingerprint(hole))
        var strokes = 0, penalties = 0, pickUps = 0
        for i in 0..<p.golfers {
            let skill = p.skillMin + (p.skillMax - p.skillMin) * Double(i) / Double(max(1, p.golfers - 1))
            let golfer = Golfer(firstName: "Test", name: "Test golfer", skill: skill, handicap: 0)
            let result = play(prepared, golfer: golfer, wind: 1, rng: &rng)
            strokes += result.strokes
            penalties += result.penalties
            if result.pickedUp { pickUps += 1 }
        }
        let n = Double(p.golfers)
        let over = Double(strokes) / n - Double(prepared.par)
        let lost = Double(penalties) / n
        let band: Fairness.Band = over >= p.brutalOverPar || lost >= p.brutalPenalties ? .brutal
            : over >= p.testingOverPar || lost >= p.testingPenalties ? .testing : .fair
        return Playtest(par: prepared.par, averageStrokes: Double(strokes) / n, averageOverPar: over,
                        ballsLost: lost, pickUpRate: Double(pickUps) / n, band: band)
    }

    /// A stable number for a hole's layout (FNV-1a).
    static func fingerprint(_ hole: Hole) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ v: UInt64) { h = (h ^ v) &* 0x0000_0100_0000_01B3 }
        for t in hole.tiles { mix(UInt64(t.rawValue)) }
        for p in [hole.tee, hole.pin] {
            mix(UInt64(p?.x ?? 99))
            mix(UInt64(p?.y ?? 99))
        }
        return h
    }
}
