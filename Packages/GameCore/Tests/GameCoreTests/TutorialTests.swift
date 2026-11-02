import XCTest
@testable import GameCore

final class TutorialTests: XCTestCase {
    func testScriptLoadsAndUsesKnownConditions() {
        let script = GameData.bundled.tutorial
        XCTAssertGreaterThanOrEqual(script.steps.count, 10)
        XCTAssertEqual(Set(script.steps.map(\.id)).count, script.steps.count, "unique ids")
        let g = GameEngine.newCareer(seed: 1, startDate: "2027-04-05")
        let known = ["ownsCourse", "firstHoleHasTee", "firstHoleHasGreen", "firstHolePlayable", "courseReady", "courseOpen", "dayPassed", "facilityBought"]
        for step in script.steps {
            XCTAssertFalse(step.lines.isEmpty, step.id)
            if !step.doneWhen.hasPrefix("event:") { XCTAssert(known.contains(step.doneWhen), "\(step.id): \(step.doneWhen)") }
            // Steps finished only by a button must have one.
            if step.doneWhen == "event:next" { XCTAssertNotNil(step.button, step.id) }
            for line in step.lines { XCTAssertFalse(line.contains("\u{2014}") || line.contains("\u{2013}"), "no dashes in Percy's lines: \(step.id)") }
        }
        XCTAssertFalse(g.tutorialCondition("nonsense"))
    }

    func testWalkingThroughTheTutorial() {
        var g = GameEngine.newCareer(seed: 3, startDate: "2027-04-05")
        XCTAssertNil(g.tutorialStep, "off until the app starts it")
        g.startTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "welcome")
        XCTAssertFalse(g.tutorialEvent("watchedRound"), "events for later steps don't skip ahead")
        XCTAssertTrue(g.tutorialEvent("next"))
        XCTAssertEqual(g.tutorialStep?.id, "map")
        g.tutorialEvent("next")
        XCTAssertEqual(g.tutorialStep?.id, "buy")

        let plot = g.state.market.listings.values.filter { $0.kind == .quiet }.min { $0.askingPrice < $1.askingPrice }!.plotID
        XCTAssertEqual(g.buyNow(plot), .done)
        g.updateTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "tee")

        // Laying out the first hole by hand: tee, then green and pin, together skip both steps.
        g.relayHole(courseID: plot, hole: 0)
        g.updateTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "fairway")
        g.tutorialEvent("next")
        XCTAssertEqual(g.tutorialStep?.id, "allHoles")
        for i in 1..<g.course(plot)!.holes.count { g.relayHole(courseID: plot, hole: i) }
        g.updateTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "open")
        g.setOpen(plot, true)
        g.updateTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "watch")
        g.tutorialEvent("watchedRound")
        XCTAssertEqual(g.tutorialStep?.id, "closeOfPlay")
        g.simulateDays(1)
        XCTAssertEqual(g.tutorialStep?.id, "reviews", "the morning moves Percy on by itself")
        g.tutorialEvent("next")
        XCTAssertEqual(g.tutorialStep?.id, "club")
        g.state.cash = 1_000_000
        _ = g.upgrade("club", courseID: plot)
        g.updateTutorial()
        XCTAssertEqual(g.tutorialStep?.id, "done")
        g.tutorialEvent("next")
        XCTAssertNil(g.tutorialStep)
        XCTAssertTrue(g.state.tutorial!.isFinished(g.data.tutorial))
    }

    func testAButtonMovesPercyOnEvenWhenTheStepWantsAnEvent() {
        var g = GameEngine.newCareer(seed: 3, startDate: "2027-04-05")
        g.startTutorial()
        g.state.tutorial?.stepIndex = g.data.tutorial.steps.firstIndex { $0.id == "watch" }!
        XCTAssertEqual(g.tutorialStep?.button, "Maybe later")
        g.tutorialEvent("next")
        XCTAssertNotEqual(g.tutorialStep?.id, "watch")
    }

    func testSkippingAndSaving() throws {
        var g = GameEngine.newCareer(seed: 3, startDate: "2027-04-05")
        g.startTutorial()
        g.tutorialEvent("next")
        let restored = try SaveFile.decode(SaveFile.encode(g.state))
        XCTAssertEqual(restored.tutorial, g.state.tutorial)
        XCTAssertEqual(GameEngine(state: restored).tutorialStep?.id, "map")
        g.skipTutorial()
        XCTAssertNil(g.tutorialStep)
    }
}
