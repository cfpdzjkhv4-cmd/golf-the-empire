import Foundation
import GameCore
import Observation

/// The bridge between SwiftUI and GameCore. Views read from it and call its methods;
/// it forwards commands to the engine and saves after every change.
@MainActor
@Observable
final class GameStore {
    enum Screen {
        case start, pickPlot, course, gallery
    }

    private(set) var engine: GameEngine?
    var screen: Screen = .start
    var selectedHole = 0
    /// nil means "look" mode: one finger pans. Otherwise one finger paints with this tool.
    var tool: BuildTool?
    var largeBrush = false
    /// A short message for the player, e.g. "Not enough cash".
    var message: String?
    /// The books for the day that just ended, shown as a summary.
    var dayJustEnded: DayBooks?
    private(set) var loadError: String?

    let data = GameData.bundled
    /// The SpriteKit scene for the course view, kept for the life of the app.
    @ObservationIgnored let courseScene = CourseScene(size: CGSize(width: 390, height: 560))

    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("GolfTheEmpire", isDirectory: true).appendingPathComponent("save.json")
    }()

    init() {
        load()
    }

    // MARK: Saving

    var hasGame: Bool { engine != nil }

    func save() {
        guard let engine else { return }
        do {
            try SaveFile.write(engine.state, to: saveURL)
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            engine = GameEngine(data: data, state: try SaveFile.read(from: saveURL))
        } catch {
            loadError = "\(error)"
        }
    }

    // MARK: Starting

    func newSandbox(plotID: String) {
        engine = GameEngine.newSandbox(
            plotID: plotID,
            seed: UInt64.random(in: 1...UInt64.max),
            startDate: GameCalendar.isoDate(Date()),
            data: data
        )
        selectedHole = 0
        tool = nil
        save()
        screen = .course
    }

    // MARK: Reading

    var course: Course? { engine?.state.orderedCourses.first }
    var plot: Plot? { course.flatMap { data.plot($0.plotID) } }

    var currentHole: Hole? {
        guard let course, course.holes.indices.contains(selectedHole) else { return nil }
        return course.holes[selectedHole]
    }

    var dateLabel: String {
        guard let engine else { return "" }
        return engine.calendar.shortLabel(day: engine.state.day)
    }

    // MARK: Building

    func paint(at point: GridPoint) {
        guard var engine, let course, let tool else { return }
        let result = engine.build(tool, courseID: course.plotID, hole: selectedHole, at: point, brushRadius: largeBrush ? 1 : 0)
        self.engine = engine
        switch result {
        case .notEnoughCash(let needed): message = "Not enough cash. That costs \(Money.text(needed))."
        case .isSea: message = "That's the sea now."
        case .pinMustBeOnGreen: message = "Put the pin on a green."
        default: break
        }
    }

    func endStroke() {
        guard var engine else { return }
        engine.endStroke()
        self.engine = engine
        save()
    }

    var canUndo: Bool { engine?.canUndo ?? false }

    func undo() {
        guard var engine else { return }
        engine.undo()
        self.engine = engine
        save()
    }

    /// Re-lays the current hole. `signature` uses the legendary venue generator (debug only).
    func relayHole(signature: Bool) {
        guard var engine, let course else { return }
        let result = engine.relayHole(courseID: course.plotID, hole: selectedHole, signature: signature)
        self.engine = engine
        if case .notEnoughCash(let needed) = result {
            message = "That layout costs \(Money.text(needed)). Not enough cash."
        } else if case .built(let cost) = result {
            message = "Hole \(selectedHole + 1) laid out for \(Money.text(cost))."
        }
        save()
    }

    func selectHole(_ index: Int) {
        guard let course else { return }
        guard course.holes.indices.contains(index) else { return }
        endStroke()
        selectedHole = index
    }

    // MARK: Time

    func toggleOpen() {
        guard var engine, let course else { return }
        if course.isOpen {
            engine.setOpen(course.plotID, false)
        } else if let problem = engine.openingProblem(course.plotID) {
            message = problem
        } else {
            engine.setOpen(course.plotID, true)
        }
        self.engine = engine
        save()
    }

    /// Plays the rest of today and shows the books.
    func finishDay() {
        guard var engine else { return }
        engine.endStroke()
        engine.simulateDays(1)
        dayJustEnded = engine.state.pastDays.last
        self.engine = engine
        save()
    }
}

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_GB")
        f.maximumFractionDigits = 0
        return f
    }()

    static func text(_ pounds: Int) -> String {
        formatter.string(from: NSNumber(value: pounds)) ?? "£\(pounds)"
    }
}
