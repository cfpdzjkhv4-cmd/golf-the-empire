import XCTest
@testable import GameCore

final class BuildTests: XCTestCase {
    private func game() -> GameEngine {
        GameEngine.newSandbox(plotID: "derwent", seed: 1, startDate: "2026-10-04")
    }

    func testPaintingChargesPerTileAndUndoRefunds() {
        var g = game()
        let start = g.state.cash
        let spentBefore = g.state.today[.buildingWork]
        let hole = g.course("derwent")!.holes[0]
        let spot = GridPoint(x: 0, y: 0)
        XCTAssertNotEqual(hole[0, 0], .water)

        XCTAssertEqual(g.build(.paint(.water), courseID: "derwent", hole: 0, at: spot), .built(cost: 400))
        XCTAssertEqual(g.build(.paint(.water), courseID: "derwent", hole: 0, at: spot), .nothingChanged)
        g.endStroke()
        XCTAssertEqual(g.state.cash, start - 400)

        XCTAssertTrue(g.undo())
        XCTAssertEqual(g.state.cash, start)
        XCTAssertEqual(g.course("derwent")!.holes[0], hole)
        XCTAssertEqual(g.state.today[.buildingWork], spentBefore, "the refund comes off today's building spend")
        XCTAssertFalse(g.undo())
    }

    func testOneDragIsOneUndoStep() {
        var g = game()
        let before = g.course("derwent")!.holes[2]
        for x in 0...3 { g.build(.paint(.bunker), courseID: "derwent", hole: 2, at: GridPoint(x: x, y: 1)) }
        g.endStroke()
        g.build(.paint(.trees), courseID: "derwent", hole: 2, at: GridPoint(x: 0, y: 3))
        g.endStroke()
        g.undo()
        g.undo()
        XCTAssertEqual(g.course("derwent")!.holes[2], before)
    }

    func testLargeBrushPaintsNineTiles() {
        var g = game()
        g.build(.paint(.rough), courseID: "derwent", hole: 1, at: GridPoint(x: 2, y: 2), brushRadius: 1)
        let result = g.build(.paint(.fairway), courseID: "derwent", hole: 1, at: GridPoint(x: 2, y: 2), brushRadius: 1)
        XCTAssertEqual(result, .built(cost: 9 * 30))
    }

    func testPinAndTeeRules() {
        var g = game()
        XCTAssertEqual(g.build(.pin, courseID: "derwent", hole: 0, at: GridPoint(x: 0, y: 31)), .pinMustBeOnGreen)
        let oldTee = g.course("derwent")!.holes[0].tee!
        XCTAssertEqual(g.build(.tee, courseID: "derwent", hole: 0, at: GridPoint(x: 5, y: 31)), .built(cost: 500))
        let hole = g.course("derwent")!.holes[0]
        XCTAssertEqual(hole.tee, GridPoint(x: 5, y: 31))
        XCTAssertEqual(hole[oldTee.x, oldTee.y], .rough)
    }

    func testCannotBuildWithoutCash() {
        var g = game()
        g.spend(.landBought, g.state.cash)
        XCTAssertEqual(g.build(.paint(.water), courseID: "derwent", hole: 0, at: GridPoint(x: 0, y: 0)), .notEnoughCash(needed: 400))
    }

    func testBreakingAHoleClosesTheCourseOnUndo() {
        var g = game()
        g.setOpen("derwent", true)
        let tee = g.course("derwent")!.holes[0].tee!
        // Painting over the tee removes it, so the course can't reopen until it's back.
        g.build(.paint(.rough), courseID: "derwent", hole: 0, at: tee)
        g.endStroke()
        XCTAssertNotNil(g.openingProblem("derwent"))
        XCTAssertFalse(g.setOpen("derwent", true))
    }
}

final class SaveTests: XCTestCase {
    func testRoundTrip() throws {
        var game = GameEngine.newSandbox(plotID: "tatton", seed: 99, startDate: "2026-10-04")
        game.setOpen("tatton", true)
        game.simulateDays(5)
        let data = try SaveFile.encode(game.state)
        XCTAssertEqual(try SaveFile.decode(data), game.state)
    }

    func testRoundTripThroughDisk() throws {
        let game = GameEngine.newSandbox(plotID: "embo", seed: 5, startDate: "2026-10-04")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gte-\(UUID().uuidString)/save.json")
        try SaveFile.write(game.state, to: url)
        XCTAssertEqual(try SaveFile.read(from: url), game.state)
    }

    func testRejectsNewerAndGarbage() {
        let newer = #"{"version": 99, "savedAt": "x", "state": {}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try SaveFile.decode(newer)) { XCTAssertEqual($0 as? SaveFile.SaveError, .fromNewerVersion(99)) }
        XCTAssertThrowsError(try SaveFile.decode(Data("hello".utf8))) { XCTAssertEqual($0 as? SaveFile.SaveError, .notASave) }
    }

    func testOlderSaveWithNoMigrationIsReported() {
        let old = #"{"version": 0, "savedAt": "x", "state": {}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try SaveFile.decode(old)) { XCTAssertEqual($0 as? SaveFile.SaveError, .missingMigration(from: 0)) }
    }
}
