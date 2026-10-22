import XCTest
@testable import GameCore

/// How golfers of different handicaps score, so the shot sim stays believable.
final class ScoringTests: XCTestCase {
    private func average(_ hole: Hole, skill: Double, rounds: Int = 300) -> (overPar: Double, lost: Double) {
        let sim = ShotSimulator(balance: balance)
        let prepared = sim.prepare(hole)
        var rng = SeededRandom(seed: 5)
        var strokes = 0, lost = 0
        let golfer = Golfer(firstName: "T", name: "T", skill: skill, handicap: 0)
        for _ in 0..<rounds {
            let r = sim.play(prepared, golfer: golfer, wind: 1, rng: &rng)
            strokes += r.strokes
            lost += r.penalties
        }
        return (Double(strokes) / Double(rounds) - Double(prepared.par), Double(lost) / Double(rounds))
    }

    func testHandicapsScoreRoughlyTrue() {
        print("\nSCORING  skill  handicap  plain par 4   island par 3")
        for skill in [0.25, 0.45, 0.65, 0.85] {
            let hcp = Int(((1 - skill) * 40 - 2).rounded())
            let plain = average(plainPar4().hole, skill: skill)
            let island = average(islandPar3().hole, skill: skill)
            print(String(format: "         %.2f   %2d        %+.2f          %+.2f (%.2f lost)", skill, hcp, plain.overPar, island.overPar, island.lost))
        }
        // A 20 handicapper drops about a shot a hole on an easy hole.
        let mid = average(plainPar4().hole, skill: 0.45).overPar
        XCTAssertEqual(mid, 1.0, accuracy: 0.45)
        // Good players are better than poor ones, and the island green costs balls.
        XCTAssertLessThan(average(plainPar4().hole, skill: 0.85).overPar, average(plainPar4().hole, skill: 0.25).overPar)
        XCTAssertGreaterThan(average(islandPar3().hole, skill: 0.45).lost, 0.25)
    }
}
