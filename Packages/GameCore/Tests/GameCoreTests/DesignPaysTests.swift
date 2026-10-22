import XCTest
@testable import GameCore

/// The heart of the game: a well designed course must clearly out earn a lazy one.
final class DesignPaysTests: XCTestCase {
    struct Outcome {
        let design: Double
        let roundsPerDay: Double
        let takingsPerDay: Double
        let netPerDay: Double
        let reputation: Double
        let stars: Double
        let fee: Int
    }

    private func run(_ plot: String, signature: Bool, days: Int = 28) -> Outcome {
        var g = GameEngine.newSandbox(plotID: plot, seed: 21, startDate: "2027-05-03")
        g.state.cash = 10_000_000
        if signature {
            for i in 0..<g.course(plot)!.holes.count { g.relayHole(courseID: plot, hole: i, signature: true) }
        }
        g.setFee(courseID: plot, g.suggestedFee(plot))
        g.setOpen(plot, true)
        let start = g.state.pastDays.count
        var rounds = 0, takings = 0, net = 0, stars = 0, reviews = 0
        for _ in 0..<days {
            g.simulateDays(1)
            let d = g.course(plot)!.yesterday!
            rounds += d.rounds
            takings += d.takings
            net += d.net
            stars += d.starsTotal
            reviews += d.reviews
            // A sensible owner keeps the fee near what locals think is fair.
            if g.state.day % 7 == 0 { g.setFee(courseID: plot, g.suggestedFee(plot)) }
        }
        _ = start
        let n = Double(days)
        return Outcome(design: g.design(of: plot)!.score, roundsPerDay: Double(rounds) / n, takingsPerDay: Double(takings) / n,
                       netPerDay: Double(net) / n, reputation: g.course(plot)!.reputationOutOfTen,
                       stars: reviews > 0 ? Double(stars) / Double(reviews) : 0, fee: g.course(plot)!.fee)
    }

    func testGoodDesignEarnsMore() {
        print("\nDESIGN PAYS (May, 28 days, fee reset weekly to fair)")
        print("plot      layout     design  rounds/day  takings/day  net/day  stars  rep/10  fee")
        for plot in ["derwent", "ilkley", "embo", "tatton"] {
            let auto = run(plot, signature: false)
            let sig = run(plot, signature: true)
            for (name, o) in [("auto", auto), ("signature", sig)] {
                print(plot.padding(toLength: 9, withPad: " ", startingAt: 0),
                      name.padding(toLength: 10, withPad: " ", startingAt: 0),
                      String(format: "%5.1f   %7.1f     %8.0f    %6.0f   %4.2f   %4.1f   £%d",
                             o.design, o.roundsPerDay, o.takingsPerDay, o.netPerDay, o.stars, o.reputation, o.fee))
            }
            XCTAssertGreaterThan(sig.takingsPerDay, auto.takingsPerDay * 1.25, "\(plot): design should clearly pay")
            XCTAssertGreaterThan(sig.stars, auto.stars + 0.8, "\(plot): golfers notice good design")
            XCTAssertGreaterThan(sig.reputation, auto.reputation, plot)
        }
    }
}
