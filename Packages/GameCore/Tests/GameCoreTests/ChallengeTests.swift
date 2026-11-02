import XCTest
@testable import GameCore

final class ChallengeTests: XCTestCase {
    /// Plays the day out, makes a change after close of play (so the daily reputation update
    /// doesn't undo it), then starts the next morning, which is when the goal is checked.
    private func playDay(_ g: inout GameEngine, then change: (inout GameEngine) -> Void = { _ in }) {
        while !g.advance(minutes: 10) {}
        change(&g)
        g.startNextDay()
    }

    func testOnlyVersionOneChallengesArePlayable() {
        XCTAssertEqual(GameData.bundled.playableChallenges.map(\.id), ["brink", "belt", "shoestring"])
        XCTAssertNil(GameEngine.newChallenge("tide", seed: 1), "needs storms, which come later")
        XCTAssertNil(GameEngine.newChallenge("nonsense", seed: 1))
    }

    func testChallengesStartOnTheirFixedDate() {
        let a = GameEngine.newChallenge("brink", seed: 1)!, b = GameEngine.newChallenge("brink", seed: 99)!
        XCTAssertEqual(a.state.startDate, "2026-04-01")
        XCTAssertEqual(a.state.startDate, b.state.startDate)
        XCTAssertEqual(GameEngine.newChallenge("belt", seed: 1)!.state.startDate, "2026-05-01")
        XCTAssertEqual(a.state.mode, .challenge(id: "brink"))
    }

    func testBackFromTheBrinkStartsWithATiredRunningCourse() {
        let g = GameEngine.newChallenge("brink", seed: 4)!
        XCTAssertEqual(g.state.cash, 60_000)
        XCTAssertEqual(g.state.courseOrder, ["crail"])
        let course = g.course("crail")!
        XCTAssertEqual(course.reputation, 1.8)
        XCTAssertEqual(course.condition, 42)
        XCTAssertEqual(course.facilities.clubhouse, 1)
        XCTAssertTrue(course.isOpen, "a running club, open from day one")
        XCTAssertNil(g.state.market.listings["crail"])
        let status = g.challengeStatus!
        XCTAssertEqual(status.daysLeft, 45)
        XCTAssertEqual(status.lines.count, 2)
        XCTAssertFalse(status.lines.contains { $0.met })
        XCTAssertNil(status.outcome)
    }

    func testStockbrokerBeltSetsUpMeridian() {
        let g = GameEngine.newChallenge("belt", seed: 4)!
        XCTAssertEqual(Set(g.state.courseOrder), ["norwood", "downs", "harpenden"])
        XCTAssertEqual(g.state.rivalCourses["chobham"]?.owner, "meridian")
        XCTAssertEqual(g.state.rivalCourses["cotswold"]?.owner, "meridian")
        XCTAssertNil(g.state.rivalCourses["harpenden"], "the player owns it in this challenge")
        XCTAssertEqual(g.state.rivals["meridian"]?.cash, 2_500_000)
        XCTAssertEqual(g.state.rivals["meridian"]?.targetReputation, 3.85)
        XCTAssertFalse(g.topOfRegion(southOf: 52.3).isTop)
    }

    func testShoestringCanAlwaysBuySomething() {
        for seed in 0..<12 as Range<UInt64> {
            let g = GameEngine.newChallenge("shoestring", seed: seed)!
            XCTAssertEqual(g.state.cash, 50_000)
            XCTAssertTrue(g.state.courses.isEmpty)
            XCTAssert(g.state.market.listings.values.contains { $0.kind == .quiet && $0.askingPrice <= 40_000 }, "seed \(seed)")
        }
    }

    func testWinningBackFromTheBrink() {
        var g = GameEngine.newChallenge("brink", seed: 4)!
        playDay(&g) {
            $0.state.courses["crail"]?.reputation = 4.1
            $0.state.cash = 320_000
        }
        XCTAssertEqual(g.challengeStatus?.outcome, .won(day: 2))
        XCTAssertTrue(g.state.letters.contains { $0.title.contains("done") })
        // The outcome sticks, even if things slip afterwards.
        g.state.cash = 0
        g.simulateDays(1)
        XCTAssertEqual(g.challengeStatus?.outcome, .won(day: 2))
    }

    func testRunningOutOfTime() {
        var g = GameEngine.newChallenge("brink", seed: 4)!
        g.simulateDays(44)
        XCTAssertNil(g.challengeStatus?.outcome, "still the last day")
        XCTAssertEqual(g.challengeStatus?.daysLeft, 1)
        g.simulateDays(1)
        XCTAssertEqual(g.challengeStatus?.outcome, .outOfTime)
    }

    func testGoingBust() {
        var g = GameEngine.newChallenge("shoestring", seed: 4)!
        g.state.cash = -80_000
        g.simulateDays(1)
        XCTAssertEqual(g.challengeStatus?.outcome, .bankrupt)
    }

    func testTopOfTheRegionMustHoldForTenDays() {
        var g = GameEngine.newChallenge("belt", seed: 4)!
        func lift(_ g: inout GameEngine) { g.state.courses["norwood"]?.reputation = 4.9 }
        for day in 1...9 {
            playDay(&g, then: lift)
            XCTAssertEqual(g.state.challenge?.streak, day)
            XCTAssertNil(g.challengeStatus?.outcome)
        }
        // A bad day resets the run.
        playDay(&g) { g in g.state.courses.keys.forEach { g.state.courses[$0]?.reputation = 1 } }
        XCTAssertEqual(g.state.challenge?.streak, 0)
        XCTAssertEqual(g.state.challenge?.bestStreak, 9)
        for _ in 1...10 { playDay(&g, then: lift) }
        XCTAssertEqual(g.challengeStatus?.outcome, .won(day: g.state.day))
    }

    func testHostingTheChampionshipWinsShoestring() {
        var g = GameEngine.newChallenge("shoestring", seed: 4)!
        let plot = g.state.market.listings.values.filter { $0.kind == .quiet }.min { $0.askingPrice < $1.askingPrice }!.plotID
        XCTAssertEqual(g.buyNow(plot), .done)
        XCTAssertEqual(g.challengeStatus?.lines.first?.met, false)
        g.state.courses[plot]?.eventsHosted["champ"] = g.state.day
        g.simulateDays(1)
        XCTAssertEqual(g.challengeStatus?.outcome, .won(day: 2))
    }

    func testChallengeProgressSavesAndLoads() throws {
        var g = GameEngine.newChallenge("belt", seed: 4)!
        for _ in 0..<3 { playDay(&g) { $0.state.courses["downs"]?.reputation = 4.9 } }
        let restored = try SaveFile.decode(SaveFile.encode(g.state))
        XCTAssertEqual(restored, g.state)
        XCTAssertEqual(restored.challenge?.streak, 3)
    }

    func testCareerSavesWithoutChallengeStillLoad() throws {
        let g = GameEngine.newCareer(seed: 2, startDate: "2027-04-05")
        var json = try JSONSerialization.jsonObject(with: SaveFile.encode(g.state)) as! [String: Any]
        var state = json["state"] as! [String: Any]
        state["challenge"] = nil
        json["state"] = state
        let restored = try SaveFile.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.challenge)
        XCTAssertNil(GameEngine(state: restored).challengeStatus)
    }
}
