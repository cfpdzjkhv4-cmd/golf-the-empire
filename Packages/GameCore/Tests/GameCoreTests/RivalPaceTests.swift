import XCTest
@testable import GameCore

final class RivalPaceTests: XCTestCase {
    /// Courses rivals bought (sealed bids won or quiet sales snapped up) in a career nobody plays.
    static func purchases(seed: UInt64, days: Int) -> (bought: Int, owned: Int) {
        var g = GameEngine.newCareer(seed: seed, startDate: "2027-04-05")
        var seen = Set(g.state.rivalCourses.keys)
        var bought = 0
        for _ in 0..<days {
            g.simulateDays(1)
            for (id, c) in g.state.rivalCourses where c.sinceDay > 0 && !seen.contains(id) { bought += 1; seen.insert(id) }
            seen = seen.intersection(g.state.rivalCourses.keys)
        }
        return (bought, g.state.rivalCourses.count)
    }

    /// Rivals should be a presence, not a land grab: about 4 to 6 courses bought in 120 days, all three rivals together.
    func testRivalsBuyAtAMeasuredPace() {
        let runs = (1...12).map { Self.purchases(seed: UInt64($0), days: 120).bought }
        let mean = Double(runs.reduce(0, +)) / Double(runs.count)
        XCTAssert((4.0...6.5).contains(mean), "mean \(mean) from \(runs)")
        XCTAssertLessThanOrEqual(runs.max() ?? 0, 8, "\(runs)")
    }

    func testARivalWaitsAfterBuying() {
        var g = GameEngine.newCareer(seed: 5, startDate: "2027-04-05")
        let rival = g.data.rivals[0]
        XCTAssertTrue(g.rivalCanBuy(rival) || g.rivalCount(rival.id) >= rival.maxCourses)
        g.rivalBought(rival.id, plotID: "crail", for: 0, reputation: 3)
        XCTAssertFalse(g.rivalCanBuy(rival))
        let wait = g.state.rivals[rival.id]!.nextPurchaseDay! - g.state.day
        XCTAssert(g.data.balance.rivals.purchaseCooldownDays[0]...g.data.balance.rivals.purchaseCooldownDays[1] ~= wait)
    }
}
