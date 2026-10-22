import XCTest
@testable import GameCore

final class SimulationTests: XCTestCase {
    private func sandbox(_ plot: String = "ilkley", seed: UInt64 = 42) -> GameEngine {
        GameEngine.newSandbox(plotID: plot, seed: seed, startDate: "2026-10-04")
    }

    func testThirtyHeadlessDaysWithAnOpenCourse() {
        var game = sandbox()
        XCTAssertNil(game.openingProblem("ilkley"))
        XCTAssertTrue(game.setOpen("ilkley", true))
        let cashAfterBuild = game.state.cash
        var weathers = Set<Weather>()
        for _ in 0..<30 {
            weathers.insert(game.course("ilkley")!.weather)
            game.simulateDays(1)
        }

        XCTAssertEqual(game.state.day, 31)
        XCTAssertEqual(game.state.minute, balance.clock.dayStartMinute)
        XCTAssertNotEqual(game.state.cash, cashAfterBuild)
        XCTAssertGreaterThan(game.state.lifetime[.greenFees, default: 0], 0, "golfers paid green fees")
        XCTAssertGreaterThan(game.state.lifetime[.upkeep, default: 0], 0, "upkeep is charged while open")
        let course = game.course("ilkley")!
        XCTAssertTrue((20...100).contains(course.condition))
        XCTAssertGreaterThan(weathers.count, 1, "the weather changes from day to day")
    }

    func testBooksAlwaysReconcile() {
        var game = sandbox()
        game.setOpen("ilkley", true)
        game.simulateDays(30)
        let s = game.state
        let income = s.lifetime.filter { $0.key.isIncome }.values.reduce(0, +)
        let spending = s.lifetime.filter { !$0.key.isIncome }.values.reduce(0, +)
        XCTAssertEqual(s.openingCash + income - spending, s.cash)
        for (yesterday, today) in zip(s.pastDays, s.pastDays.dropFirst()) {
            XCTAssertEqual(yesterday.closingCash, today.openingCash)
        }
        XCTAssertEqual(s.pastDays.last?.closingCash, s.today.openingCash)
    }

    func testSameSeedReplaysExactly() {
        func play(_ seed: UInt64) -> GameState {
            var game = sandbox(seed: seed)
            game.setOpen("ilkley", true)
            game.simulateDays(10)
            return game.state
        }
        XCTAssertEqual(play(7), play(7))
        XCTAssertNotEqual(play(7), play(8))
    }

    func testEveryHandMadePlotCanStartASandbox() {
        for id in data.plotOrder where !(data.plot(id)!.isLegendary) {
            var game = sandbox(id, seed: 3)
            XCTAssertNil(game.openingProblem(id), id)
            XCTAssertTrue(game.setOpen(id, true), id)
            game.simulateDays(1)
            XCTAssertEqual(game.state.day, 2, id)
            XCTAssertGreaterThan(game.course(id)!.yesterday?.rounds ?? 0, 0, "\(id) had golfers")
        }
    }

    func testClockStopsAtCloseOfPlay() {
        var game = sandbox()
        XCTAssertFalse(game.advance(minutes: 60))
        XCTAssertEqual(GameCalendar.clockLabel(minute: game.state.minute), "08:00")
        XCTAssertTrue(game.advance(minutes: 10_000))
        XCTAssertTrue(game.state.isDayOver)
        XCTAssertEqual(game.state.minute, 1140)
        XCTAssertFalse(game.advance(minutes: 10), "the clock waits for Start [date]")
        game.startNextDay()
        XCTAssertEqual(game.state.day, 2)
        XCTAssertFalse(game.state.isDayOver)
    }

    func testCalendar() {
        let cal = GameCalendar(startDate: "2026-10-04", balance: balance)
        XCTAssertEqual(cal.shortLabel(day: 1), "Sun 4 Oct")
        XCTAssertEqual(cal.shortLabel(day: 2), "Mon 5 Oct")
        XCTAssertEqual(cal.longLabel(day: 89), "Thursday 31 December 2026")
        XCTAssertEqual(cal.shortLabel(day: 90), "Fri 1 Jan")
        XCTAssertEqual(cal.weekdayDemand(day: 1), 1.35)
        XCTAssertEqual(cal.weekdayDemand(day: 2), 1.0)
        XCTAssertEqual(cal.weekdayDemand(day: 6), 1.1)
        XCTAssertEqual(cal.seasonDemand(day: 1), 0.92)
        XCTAssertTrue(cal.isWinter(day: 1))
        XCTAssertEqual(cal.seasonName(day: 1), "Autumn")
    }

    func testUpkeepFormula() {
        let game = sandbox()
        let course = game.course("ilkley")!
        var expected = 60.0
        for h in course.holes {
            expected += 12 + Double(h.count(of: .fairway)) * 0.15 + Double(h.count(of: .green)) * 0.8
                + Double(h.count(of: .bunker)) * 0.2 + Double(h.count(of: .water)) * 0.1
        }
        XCTAssertEqual(game.upkeep(of: course), Int(expected.rounded()))
        XCTAssertEqual(game.wages(of: course), 0, "skeleton crew is unpaid")
    }
}
