import XCTest
@testable import GameCore

final class CourseDesignTests: XCTestCase {
    let generator = HoleGenerator(balance: balance)
    let designer = CourseDesigner(balance: balance)

    private func course(_ land: LandKind, holes: Int, signature: Bool, seed: UInt64) -> [Hole] {
        var rng = SeededRandom(seed: seed)
        return data.standardPars(holes: holes).map { par in
            let base = generator.baseLand(land, rng: &rng)
            return signature
                ? generator.bestSignatureLayout(par: par, land: land, on: base, rng: &rng)
                : generator.autoLayout(par: par, land: land, on: base, rng: &rng)
        }
    }

    /// DESIGN.md: auto layout is deliberately basic and scores about 3.4.
    func testAutoLayoutIsBasic() {
        var scores: [Double] = []
        for seed in 1...20 {
            for land in LandKind.allCases {
                let holes = course(land, holes: 18, signature: false, seed: UInt64(seed))
                XCTAssertTrue(holes.allSatisfy { HoleRules(balance: balance).isPlayable($0) }, "auto layout must always be playable")
                scores.append(designer.design(of: holes).score)
            }
        }
        let average = scores.reduce(0, +) / Double(scores.count)
        XCTAssertEqual(average, 3.4, accuracy: 0.6, "auto layout course design averages \(average)")
    }

    /// DESIGN.md: the signature generator scores 7 to 9+.
    func testSignatureLayoutIsChampionshipClass() {
        var scores: [Double] = []
        for seed in 1...10 {
            for land in LandKind.allCases {
                scores.append(designer.design(of: course(land, holes: 18, signature: true, seed: UInt64(seed))).score)
            }
        }
        let average = scores.reduce(0, +) / Double(scores.count)
        XCTAssertGreaterThanOrEqual(average, 7.0, "signature courses average \(average)")
        XCTAssertGreaterThan(scores.min() ?? 0, 5.5)
    }

    func testRepeatingAFeatureEarnsLess() {
        let island = islandPar3().hole
        let design = designer.design(of: Array(repeating: island, count: 18))
        // 18 holes allow 3 island greens at full value; the 4th onwards decay.
        XCTAssertEqual(design.repeats.count, 15)
        XCTAssertEqual(design.repeats.first?.occurrence, 4)
        XCTAssertEqual(design.repeats.first?.valueShare ?? 0, 0.6, accuracy: 0.001)
        XCTAssertEqual(design.effectiveHoleScores[0], design.holes[0].score)
        XCTAssertLessThan(design.effectiveHoleScores[17], design.effectiveHoleScores[3])
        XCTAssertLessThan(design.effectiveHoleScores[3], design.effectiveHoleScores[2])

        // The same holes with no repetition penalty would rate far higher.
        let naive = design.holes.map(\.score).reduce(0, +) / 18 * 0.85
        XCTAssertLessThan(design.score, naive)
    }

    func testVarietyBeatsRepetition() {
        let island = islandPar3().hole
        var dogleg = HoleSketch()
        dogleg.rect(.fairway, x: 7...9, y: 18...27)
        dogleg.rect(.fairway, x: 9...13, y: 15...17)
        dogleg.rect(.fairway, x: 11...13, y: 8...14)
        dogleg.green(12, 5)
        dogleg.tee(8, 30)
        dogleg.rect(.water, x: 11...12, y: 18...20)
        var waste = plainPar4()
        waste.rect(.bunker, x: 11...13, y: 14...19)

        let samey = designer.design(of: Array(repeating: island, count: 9))
        let varied = designer.design(of: (0..<3).flatMap { _ in [island, dogleg.hole, waste.hole] })
        XCTAssertGreaterThan(varied.score, samey.score)
        XCTAssertGreaterThan(varied.featureKinds, samey.featureKinds)
    }

    func testSignatureHoleAndWords() {
        var star = islandPar3()
        star.rect(.bunker, x: 0...1, y: 10...14)
        let design = designer.design(of: [plainPar4().hole, star.hole, plainPar4().hole])
        XCTAssertEqual(design.signatureHole, 1)
        XCTAssertEqual(designer.word(for: 8.6), "Masterpiece")
        XCTAssertEqual(designer.word(for: 7.5), "Championship class")
        XCTAssertEqual(designer.word(for: 3.9), "Basic")
    }

    func testRelaidLayoutsCostMoney() {
        var rng = SeededRandom(seed: 9)
        let base = generator.baseLand(.parkland, rng: &rng)
        let laid = generator.autoLayout(par: 4, land: .parkland, on: base, rng: &rng)
        XCTAssertGreaterThan(generator.cost(from: base, to: laid), 2000)
        XCTAssertEqual(generator.cost(from: laid, to: laid), 0)
    }
}
