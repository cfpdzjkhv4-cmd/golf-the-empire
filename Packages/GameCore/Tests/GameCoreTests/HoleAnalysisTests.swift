import XCTest
@testable import GameCore

final class HoleAnalysisTests: XCTestCase {
    func testUnplayableHolesScoreZero() {
        var s = plainPar4()
        s.hole.tee = nil
        XCTAssertEqual(analyze(s.hole).score, 0)
        XCTAssertEqual(HoleRules(balance: balance).issue(s.hole), .needsTee)

        var t = plainPar4()
        t.hole.pin = GridPoint(x: 0, y: 0)
        XCTAssertEqual(HoleRules(balance: balance).issue(t.hole), .needsPinOnGreen)
    }

    func testParFromYardage() {
        let rules = HoleRules(balance: balance)
        XCTAssertEqual(rules.par(forYards: 250), 3)
        XCTAssertEqual(rules.par(forYards: 251), 4)
        XCTAssertEqual(rules.par(forYards: 440), 4)
        XCTAssertEqual(rules.par(forYards: 441), 5)
        XCTAssertEqual(rules.par(plainPar4().hole), 4)
    }

    func testPlainHoleIsBland() {
        let a = analyze(plainPar4().hole)
        XCTAssertEqual(kinds(a), [.bland])
        XCTAssertEqual(a.score, 3.0, accuracy: 0.01, "3.8 base minus 0.8 for bland")
        XCTAssertTrue(a.tips.contains(HoleAnalyzer.tipDogleg))
    }

    func testIslandGreen() {
        let a = analyze(islandPar3().hole)
        XCTAssertTrue(kinds(a).contains(.island))
        XCTAssertFalse(kinds(a).contains(.p3water), "an island green isn't also counted as a carry")
        XCTAssertGreaterThanOrEqual(a.score, 7.0)
        XCTAssertEqual(a.par, 3)
    }

    func testTeeShotOverWater() {
        var s = HoleSketch()
        s.rect(.water, x: 5...11, y: 23...25)
        s.green(8, 17)
        s.tee(8, 30)
        let a = analyze(s.hole)
        XCTAssertTrue(kinds(a).contains(.p3water))
        XCTAssertEqual(a.score, 3.8 + 2.2, accuracy: 0.01)
    }

    func testDoglegAndRiskCorner() {
        var s = HoleSketch()
        // Straight out from the tee, then turns right for the last stretch.
        s.rect(.fairway, x: 7...9, y: 18...27)
        s.rect(.fairway, x: 9...13, y: 15...17)
        s.rect(.fairway, x: 11...13, y: 8...14)
        s.green(12, 5)
        s.tee(8, 30)
        let plain = analyze(s.hole)
        XCTAssertTrue(plain.features.contains { $0.kind == .dogleg && $0.name == "Dogleg right" }, "\(plain.features)")

        // Water inside the corner turns it into a risk and reward hole.
        s.rect(.water, x: 11...12, y: 18...20)
        let risky = analyze(s.hole)
        XCTAssertTrue(kinds(risky).contains(.risk), "\(risky.features)")
        XCTAssertGreaterThan(risky.score, plain.score)
    }

    func testBunkerFeatures() {
        var waste = plainPar4()
        waste.rect(.bunker, x: 11...13, y: 14...19) // 18 tiles in one piece
        XCTAssertTrue(kinds(analyze(waste.hole)).contains(.waste))

        var showcase = plainPar4()
        showcase.rect(.bunker, x: 11...12, y: 14...18) // 10 tiles
        XCTAssertTrue(kinds(analyze(showcase.hole)).contains(.showcase))

        var guarded = plainPar4()
        guarded.hole.set(4, 6, .bunker)
        guarded.hole.set(12, 6, .bunker)
        guarded.hole.set(8, 2, .bunker)
        XCTAssertTrue(kinds(analyze(guarded.hole)).contains(.guarded))

        var pots = plainPar4()
        for y in [10, 13, 16, 19, 22] { pots.hole.set(11, y, .bunker) }
        XCTAssertTrue(kinds(analyze(pots.hole)).contains(.pots))
    }

    func testNarrowFairwayIsPenalised() {
        var s = HoleSketch()
        s.rect(.fairway, x: 8...8, y: 9...26)
        s.green(8, 6)
        s.tee(8, 30)
        let a = analyze(s.hole)
        XCTAssertTrue(kinds(a).contains(.narrow))
        XCTAssertEqual(a.tips.first, HoleAnalyzer.tipNarrow)
    }

    func testTreeLined() {
        var s = plainPar4()
        s.rect(.trees, x: 5...5, y: 9...26)
        s.rect(.trees, x: 11...11, y: 9...26)
        XCTAssertTrue(kinds(analyze(s.hole)).contains(.trees))
    }

    func testDiminishingReturns() {
        // Two features: the better one counts in full, the second at 80%.
        var s = islandPar3()
        s.hole.set(3, 18, .bunker)
        s.rect(.bunker, x: 0...1, y: 10...14) // a showcase bunker away from the water
        let a = analyze(s.hole)
        XCTAssertTrue(kinds(a).contains(.showcase))
        let bunkers = Double(min(s.hole.count(of: .bunker), 10)) * 0.05
        XCTAssertEqual(a.score, ((3.8 + bunkers + 3.2 + 1.6 * 0.8) * 10).rounded() / 10, accuracy: 0.01)
    }

    func testFairnessBands() {
        let analyzer = HoleAnalyzer(balance: balance)
        XCTAssertEqual(analyzer.fairness(of: [.dogleg]).band, .fair)
        XCTAssertEqual(analyzer.fairness(of: [.watergreen, .carry]).band, .testing)
        let brutal = analyzer.fairness(of: [.island, .narrow, .wip, .pots])
        XCTAssertEqual(brutal.band, .brutal)
        XCTAssertEqual(brutal.penalty, (3.8 - 3.0) * 0.6, accuracy: 0.001)
    }

    func testBrutalHoleLosesRatingAndSaysWhy() {
        // Narrow fairway, water down both sides, guarded green.
        var s = HoleSketch()
        s.rect(.fairway, x: 8...8, y: 9...26)
        s.rect(.water, x: 6...7, y: 10...25)
        s.rect(.water, x: 9...10, y: 10...25)
        s.green(8, 6)
        s.hole.set(4, 6, .bunker)
        s.hole.set(12, 6, .bunker)
        s.hole.set(8, 2, .bunker)
        s.tee(8, 30)
        let a = analyze(s.hole)
        XCTAssertNotEqual(a.fairness.band, .fair, "\(a.features) severity \(a.fairness.severity)")
    }
}
