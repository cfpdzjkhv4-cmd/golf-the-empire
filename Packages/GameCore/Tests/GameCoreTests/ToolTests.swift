import XCTest
@testable import GameCore

final class ToolTests: XCTestCase {
    private func game(_ hole: Hole) -> GameEngine {
        var g = GameEngine.newSandbox(plotID: "derwent", seed: 1, startDate: "2026-10-04")
        g.state.courses["derwent"]!.holes[0] = hole
        return g
    }

    func testRingingTheGreenWithWaterMakesAnIsland() {
        var s = HoleSketch()
        s.green(8, 18)
        s.tee(8, 30)
        var g = game(s.hole)
        XCTAssertFalse(kinds(analyze(g.course("derwent")!.holes[0])).contains(.island))
        guard case .built(let cost) = g.ringGreen(courseID: "derwent", hole: 0, with: .water, style: .all) else { return XCTFail() }
        XCTAssertGreaterThan(cost, 0)
        let after = analyze(g.course("derwent")!.holes[0])
        XCTAssertTrue(kinds(after).contains(.island), "\(after.features)")
        g.undo()
        XCTAssertEqual(g.course("derwent")!.holes[0], s.hole)
    }

    func testIslandGreenWithABridge() {
        var s = HoleSketch()
        s.green(8, 18)
        s.tee(8, 30)
        var g = game(s.hole)
        guard case .built = g.ringGreen(courseID: "derwent", hole: 0, with: .water, style: .all, bridge: true) else { return XCTFail() }
        let hole = g.course("derwent")!.holes[0]
        XCTAssertGreaterThanOrEqual(hole.count(of: .bridge), 2, "a walkway across the water")
        // The bridge sits between the green and the tee.
        for y in 0..<hole.rows { for x in 0..<hole.columns where hole[x, y] == .bridge { XCTAssertGreaterThan(y, 18) } }
        XCTAssertTrue(kinds(analyze(hole)).contains(.island), "a bridge doesn't stop it being an island green")
        g.undo()
        XCTAssertEqual(g.course("derwent")!.holes[0], s.hole, "one undo removes water and bridge")
    }

    func testBridgesOnlyGoOverWater() {
        var s = plainPar4()
        s.rect(.water, x: 2...4, y: 12...14)
        var g = game(s.hole)
        XCTAssertEqual(g.build(.paint(.bridge), courseID: "derwent", hole: 0, at: GridPoint(x: 8, y: 20)), .bridgeNeedsWater)
        XCTAssertEqual(g.build(.paint(.bridge), courseID: "derwent", hole: 0, at: GridPoint(x: 3, y: 13)), .built(cost: 300))
        // A big brush only bridges the water under it.
        g.build(.paint(.bridge), courseID: "derwent", hole: 0, at: GridPoint(x: 4, y: 13), brushRadius: 2)
        let hole = g.course("derwent")!.holes[0]
        XCTAssertEqual(hole.count(of: .bridge) + hole.count(of: .water), 9)
        // Saves keep bridges.
        let data = try! SaveFile.encode(g.state)
        XCTAssertEqual(try! SaveFile.decode(data).courses["derwent"]!.holes[0].count(of: .bridge), hole.count(of: .bridge))
    }

    func testFrontRingGuardsTheGreen() {
        var s = plainPar4()
        s.rect(.rough, x: 0...15, y: 8...10)
        var g = game(s.hole)
        g.ringGreen(courseID: "derwent", hole: 0, with: .water, style: .front, width: 2)
        let a = analyze(g.course("derwent")!.holes[0])
        XCTAssertTrue(kinds(a).contains(.watergreen) || kinds(a).contains(.carry), "\(a.features)")
        XCTAssertFalse(kinds(a).contains(.island))
    }

    func testStampsMakeBunkerFeatures() {
        var g = game(plainPar4().hole)
        g.stamp("waste", courseID: "derwent", hole: 0, at: GridPoint(x: 12, y: 18))
        XCTAssertTrue(kinds(analyze(g.course("derwent")!.holes[0])).contains(.waste))

        var h = game(plainPar4().hole)
        h.stamp("showcase", courseID: "derwent", hole: 0, at: GridPoint(x: 12, y: 18))
        XCTAssertTrue(kinds(analyze(h.course("derwent")!.holes[0])).contains(.showcase))
        for id in h.stampIDs { XCTAssertNotNil(balance.stamps.shapes[id], id) }
    }

    func testDraggedStrokeHasNoGaps() {
        var g = game(Hole(columns: 16, rows: 32))
        g.buildStroke(.paint(.fairway), courseID: "derwent", hole: 0, from: GridPoint(x: 2, y: 2), to: GridPoint(x: 12, y: 20), brushRadius: 1)
        g.endStroke()
        let hole = g.course("derwent")!.holes[0]
        for y in 2...20 {
            XCTAssertTrue((0..<16).contains { hole[$0, y] == .fairway }, "row \(y) is unbroken")
        }
        g.undo()
        XCTAssertEqual(g.course("derwent")!.holes[0].count(of: .fairway), 0, "one drag is one undo")
    }

    func testBigRoundBrush() {
        var g = game(Hole(columns: 16, rows: 32))
        XCTAssertEqual(g.build(.paint(.bunker), courseID: "derwent", hole: 0, at: GridPoint(x: 8, y: 8), brushRadius: 2), .built(cost: 21 * 120))
    }
}
