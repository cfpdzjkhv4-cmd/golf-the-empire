import Foundation

/// One step of the tutorial, from tutorial.json.
public struct TutorialStep: Decodable, Sendable, Identifiable {
    public let id: String
    /// Where the player should be: "map", "course.build", "course.run", "course.club", "course.reviews".
    public let screen: String
    /// The control to point at, if any (the app maps these ids to views).
    public let anchor: String?
    public let title: String
    /// Percy's lines, shown one after another.
    public let lines: [String]
    /// A button that finishes the step; it sends "next". Needed when doneWhen is "event:next", optional otherwise.
    public let button: String?
    /// When the step is done: a condition name or "event:<name>".
    public let doneWhen: String
}

public struct TutorialScript: Decodable, Sendable {
    public let steps: [TutorialStep]
}

/// How far the player has got through the tutorial. Saved with the game.
public struct TutorialState: Codable, Equatable, Sendable {
    /// Index of the current step; equal to the step count once finished.
    public var stepIndex = 0
    public var skipped = false
    /// Events the app has reported for the current step.
    var events: Set<String> = []

    public init() {}

    public func isFinished(_ script: TutorialScript) -> Bool { skipped || stepIndex >= script.steps.count }

    public func current(_ script: TutorialScript) -> TutorialStep? {
        isFinished(script) ? nil : script.steps[stepIndex]
    }

    /// The app reports something only the screen knows: "next" for a step's button, "watchedRound", and so on.
    public mutating func record(_ event: String) {
        events.insert(event)
    }

    public mutating func skip() {
        skipped = true
    }

    /// Moves past every step that's done. Call after each command and each morning.
    /// Returns true if the step changed, so the app can show Percy's new lines.
    @discardableResult
    public mutating func update(_ script: TutorialScript, isMet: (String) -> Bool) -> Bool {
        let start = stepIndex
        while let step = current(script) {
            let done: Bool
            if step.button != nil && events.contains("next") {
                // The step's button always moves Percy on ("Maybe later").
                done = true
            } else if step.doneWhen.hasPrefix("event:") {
                done = events.contains(String(step.doneWhen.dropFirst("event:".count)))
            } else {
                done = isMet(step.doneWhen)
            }
            guard done else { break }
            stepIndex += 1
            events.removeAll()
        }
        return stepIndex != start
    }
}
