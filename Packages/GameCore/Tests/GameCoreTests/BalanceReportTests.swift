import XCTest
@testable import GameCore

/// Prints the numbers that matter for tuning, so balance changes are visible in the test log.
/// Grows in Milestone 2 with daily rounds, revenue and reputation once golfers play.
final class BalanceReportTests: XCTestCase {
    func testPrintBalanceReport() {
        let plots = ["embo", "derwent", "ilkley", "tatton", "chobham"]
        print("\nBALANCE REPORT (auto layout, seed 1)")
        print("plot        holes  land      layout   design  upkeep/day  fee")
        for id in plots {
            let game = GameEngine.newSandbox(plotID: id, seed: 1, startDate: "2026-10-04")
            let plot = data.plot(id)!
            let course = game.course(id)!
            let layout = game.state.today[.buildingWork]
            let design = game.design(of: id)!.score
            let line = [
                id.padding(toLength: 11, withPad: " ", startingAt: 0),
                String(plot.holes).padding(toLength: 6, withPad: " ", startingAt: 0),
                "£\(data.basePrice(of: plot))".padding(toLength: 9, withPad: " ", startingAt: 0),
                "£\(layout)".padding(toLength: 8, withPad: " ", startingAt: 0),
                String(format: "%.1f", design).padding(toLength: 7, withPad: " ", startingAt: 0),
                "£\(game.upkeep(of: course))".padding(toLength: 11, withPad: " ", startingAt: 0),
                "£\(course.fee)",
            ].joined(separator: " ")
            print(line)
            XCTAssertGreaterThan(layout, 0)
        }
    }
}
