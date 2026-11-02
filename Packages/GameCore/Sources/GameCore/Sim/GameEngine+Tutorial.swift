import Foundation

extension GameEngine {
    /// Starts Percy's tutorial (the app offers it on a first career).
    public mutating func startTutorial() {
        state.tutorial = TutorialState()
        updateTutorial()
    }

    /// The step Percy is on, or nil when there's no tutorial running.
    public var tutorialStep: TutorialStep? {
        state.tutorial?.current(data.tutorial)
    }

    /// The app reports a screen event ("next", "watchedRound"); returns true if Percy moved on.
    @discardableResult
    public mutating func tutorialEvent(_ event: String) -> Bool {
        guard state.tutorial != nil else { return false }
        state.tutorial?.record(event)
        return updateTutorial()
    }

    public mutating func skipTutorial() {
        state.tutorial?.skip()
    }

    /// Moves the tutorial on past anything already done. Cheap; call after commands.
    @discardableResult
    public mutating func updateTutorial() -> Bool {
        guard var t = state.tutorial else { return false }
        let changed = t.update(data.tutorial) { tutorialCondition($0) }
        state.tutorial = t
        return changed
    }

    /// The conditions tutorial.json can use, checked against the player's first course.
    public func tutorialCondition(_ name: String) -> Bool {
        let first = state.courseOrder.first.flatMap { state.courses[$0] }
        switch name {
        case "ownsCourse": return first != nil
        case "firstHoleHasTee": return first?.holes.first?.tee != nil
        case "firstHoleHasGreen": return first?.holes.first.map { $0.tiles.contains(.green) } ?? false
        case "firstHolePlayable": return first?.holes.first.map { holeRules.isPlayable($0) } ?? false
        case "courseReady": return first.map { openingProblem($0.plotID) == nil } ?? false
        case "courseOpen": return first?.isOpen ?? false
        case "dayPassed": return first.map { state.day > $0.boughtDay } ?? false
        case "facilityBought":
            return first.map { $0.facilities.clubhouse > 0 || $0.facilities.shop > 0 || $0.facilities.range > 0 } ?? false
        default: return false
        }
    }
}
