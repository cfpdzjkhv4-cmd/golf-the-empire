import XCTest
@testable import GameCore

/// Compares the quick fairness estimate on the hole card with how holes really play in the shot sim.
final class CalibrationTests: XCTestCase {
    func testFairnessEstimateAgreesWithPlaytests() {
        let generator = HoleGenerator(balance: balance)
        let sim = ShotSimulator(balance: balance)
        let analyzer = HoleAnalyzer(balance: balance)
        var rows: [(String, Fairness.Band, Playtest)] = []
        var rng = SeededRandom(seed: 11)
        for land in LandKind.allCases {
            for par in [3, 4, 5] {
                for signature in [false, true] {
                    let base = generator.baseLand(land, rng: &rng)
                    let hole = signature
                        ? generator.signatureLayout(par: par, land: land, on: base, rng: &rng)
                        : generator.autoLayout(par: par, land: land, on: base, rng: &rng)
                    guard let test = sim.playtest(hole) else { continue }
                    rows.append(("\(land.rawValue) p\(par) \(signature ? "sig" : "auto")", analyzer.analyze(hole).fairness.band, test))
                }
            }
        }
        rows.append(("island p3", analyzer.analyze(islandPar3().hole).fairness.band, sim.playtest(islandPar3().hole)!))
        rows.append(("plain p4", analyzer.analyze(plainPar4().hole).fairness.band, sim.playtest(plainPar4().hole)!))

        print("\nFAIRNESS CALIBRATION   estimate  playtest  over par  balls lost  pick ups")
        var agree = 0
        for (name, estimate, test) in rows {
            if estimate == test.band { agree += 1 }
            print(name.padding(toLength: 22, withPad: " ", startingAt: 0),
                  estimate.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0),
                  test.band.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0),
                  String(format: "%+.2f     %.2f        %.0f%%", test.averageOverPar, test.ballsLost, test.pickUpRate * 100))
        }
        print("agree \(agree) of \(rows.count)")
        // Auto layouts are deliberately easy: they must play fair.
        for (name, _, test) in rows where name.hasSuffix("auto") {
            XCTAssertNotEqual(test.band, .brutal, name)
        }
    }

    func testPlaytestIsRepeatable() {
        let sim = ShotSimulator(balance: balance)
        XCTAssertEqual(sim.playtest(islandPar3().hole), sim.playtest(islandPar3().hole))
    }
}
