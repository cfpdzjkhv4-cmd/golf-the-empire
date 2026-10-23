import Foundation
import GameCore
import Observation

/// The bridge between SwiftUI and GameCore. Views read from it and call its methods;
/// it forwards commands to the engine and saves after every change.
@MainActor
@Observable
final class GameStore {
    enum Screen {
        case start, pickPlot, map, course, gallery
    }

    enum CourseTab: String, CaseIterable, Identifiable {
        case build = "Build", run = "Run", club = "Club", events = "Events", reviews = "Reviews"
        var id: String { rawValue }
    }

    /// What one finger does on the course.
    enum BuildMode: Equatable {
        case look
        case brush(Tile)
        case tee
        case pin
        case stamp(String)
    }

    /// A round being played back shot by shot.
    struct Watching {
        let round: WatchedRound
        var line: String
        var previousLine: String?
        var holeIndex: Int
        var strokesThisHole: Int
        var finished = false
    }

    private(set) var engine: GameEngine?
    var screen: Screen = .start
    /// The course on screen; nil falls back to the first one owned.
    var currentCourseID: String?
    /// A sheet open over the map (listing, market, my clubs, letters, goals). The clock pauses while one is open.
    var mapSheetOpen = false
    var tab: CourseTab = .build
    var selectedHole = 0
    var mode: BuildMode = .look
    /// 0 small (one tile), 1 medium (3 wide), 2 large (5 wide).
    var brushSize = 1
    /// Index into the speeds in balance.json: 0 paused, 1 = 1x, 2 = 4x, 3 = 10x.
    var speedIndex = 1
    /// A short message for the player, e.g. "Not enough cash".
    var message: String?
    /// Shown after close of play until the player starts the next day.
    var showingCloseOfPlay = false
    private(set) var watching: Watching?
    private(set) var loadError: String?

    let data = GameData.bundled
    /// The SpriteKit scene for the course view, kept for the life of the app.
    @ObservationIgnored let courseScene = CourseScene(size: CGSize(width: 390, height: 560))
    @ObservationIgnored private var lastPaintedCell: GridPoint?
    @ObservationIgnored private var strokeHadWork = false
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var minuteRemainder = 0.0
    @ObservationIgnored private var playtestCache: (hole: Hole, result: Playtest?)?

    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("GolfTheEmpire", isDirectory: true).appendingPathComponent("save.json")
    }()

    init() {
        load()
        startClock()
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
            showingCloseOfPlay = engine?.state.isDayOver ?? false
        } catch {
            loadError = "\(error)"
        }
    }

    // MARK: Starting

    func newCareer() {
        stopWatching()
        engine = GameEngine.newCareer(seed: UInt64.random(in: 1...UInt64.max), startDate: GameCalendar.isoDate(Date()), data: data)
        currentCourseID = nil
        selectedHole = 0
        mode = .look
        showingCloseOfPlay = false
        save()
        screen = .map
    }

    func newSandbox(plotID: String) {
        stopWatching()
        engine = GameEngine.newSandbox(
            plotID: plotID,
            seed: UInt64.random(in: 1...UInt64.max),
            startDate: GameCalendar.isoDate(Date()),
            data: data
        )
        selectedHole = 0
        mode = .look
        tab = .build
        showingCloseOfPlay = false
        save()
        screen = .course
    }

    // MARK: Reading

    var course: Course? {
        guard let engine else { return nil }
        if let id = currentCourseID, let c = engine.state.courses[id] { return c }
        return engine.state.orderedCourses.first
    }

    var isCareer: Bool { engine.map { $0.state.mode != .sandbox } ?? false }

    /// Opens one of your courses.
    func openCourse(_ id: String) {
        stopWatching()
        currentCourseID = id
        selectedHole = 0
        mode = .look
        tab = (engine?.openingProblem(id) != nil) ? .build : .run
        screen = .course
    }

    func backToMap() {
        stopWatching()
        endStroke()
        save()
        screen = isCareer ? .map : .start
    }

    // MARK: The market

    func buyNow(_ plotID: String) -> Bool {
        guard var engine else { return false }
        let result = engine.buyNow(plotID)
        self.engine = engine
        switch result {
        case .done:
            SoundBoard.shared.play("sfx_till")
            save()
            return true
        case .notEnoughCash(let needed): message = "Not enough cash. You need \(Money.text(needed))."
        default: message = "That's no longer for sale."
        }
        return false
    }

    func placeOffer(_ plotID: String, amount: Int) {
        guard var engine else { return }
        switch engine.placeOffer(plotID, amount: amount) {
        case .done:
            message = "Offer of \(Money.text(amount)) submitted."
            SoundBoard.shared.play("sfx_ui_confirm")
        case .offerTooLow(let minimum): message = "The agents won't accept less than \(Money.text(minimum))."
        default: message = "That's no longer for sale."
        }
        self.engine = engine
        save()
    }

    func withdrawOffer(_ plotID: String) {
        guard var engine else { return }
        engine.withdrawOffer(plotID)
        self.engine = engine
        save()
    }

    func toggleFavourite(_ plotID: String) {
        guard var engine else { return }
        engine.toggleFavourite(plotID)
        self.engine = engine
        save()
    }

    func markLettersRead() {
        guard var engine else { return }
        engine.markLettersRead()
        self.engine = engine
        save()
    }

    var unreadLetters: Int { engine?.state.letters.filter { !$0.read }.count ?? 0 }

    // MARK: Events

    func bookEvent(_ eventID: String) {
        guard var engine, let course else { return }
        if engine.bookEvent(courseID: course.plotID, eventID: eventID) {
            message = "Booked for tomorrow. The course will be closed to the public."
            SoundBoard.shared.play("sfx_ui_confirm")
        }
        self.engine = engine
        save()
    }

    func cancelBooking() {
        guard var engine, let course else { return }
        engine.cancelBooking(courseID: course.plotID)
        self.engine = engine
        save()
    }
    var plot: Plot? { course.flatMap { data.plot($0.plotID) } }

    var currentHole: Hole? {
        guard let course, course.holes.indices.contains(selectedHole) else { return nil }
        return course.holes[selectedHole]
    }

    var dateLabel: String {
        guard let engine else { return "" }
        return engine.calendar.shortLabel(day: engine.state.day)
    }

    var clockLabel: String {
        GameCalendar.clockLabel(minute: engine?.state.minute ?? data.balance.clock.dayStartMinute)
    }

    var quality: CourseQuality? {
        course.flatMap { engine?.quality(of: $0.plotID) }
    }

    /// Ordinary golfers sent round the selected hole. Worked out once per layout.
    var playtest: Playtest? {
        guard let hole = currentHole else { return nil }
        if let cache = playtestCache, cache.hole == hole { return cache.result }
        let result = ShotSimulator(balance: data.balance).playtest(hole)
        playtestCache = (hole, result)
        return result
    }

    // MARK: Building

    func setMode(_ newMode: BuildMode) {
        endStroke()
        mode = newMode
    }

    /// Called for each new square a finger passes over.
    func paint(at point: GridPoint) {
        guard var engine, let course, watching == nil else { return }
        let id = course.plotID
        let result: BuildResult
        switch mode {
        case .look: return
        case .brush(let tile):
            result = engine.buildStroke(.paint(tile), courseID: id, hole: selectedHole, from: lastPaintedCell, to: point, brushRadius: brushSize)
        case .tee:
            result = engine.build(.tee, courseID: id, hole: selectedHole, at: point)
        case .pin:
            result = engine.build(.pin, courseID: id, hole: selectedHole, at: point)
        case .stamp(let shape):
            guard lastPaintedCell == nil else { return }
            result = engine.stamp(shape, courseID: id, hole: selectedHole, at: point)
        }
        lastPaintedCell = point
        self.engine = engine
        report(result)
    }

    func endStroke() {
        lastPaintedCell = nil
        if strokeHadWork {
            strokeHadWork = false
            SoundBoard.shared.play("sfx_build_paint", volume: 0.6)
        }
        guard var engine else { return }
        engine.endStroke()
        self.engine = engine
        save()
    }

    func ringGreen(with tile: Tile, style: RingStyle, bridge: Bool = false) {
        guard var engine, let course else { return }
        let result = engine.ringGreen(courseID: course.plotID, hole: selectedHole, with: tile, style: style,
                                      width: tile == .water ? 2 : 1, bridge: bridge)
        self.engine = engine
        report(result)
        if case .built(let cost) = result {
            message = "Done, for \(Money.text(cost))."
            SoundBoard.shared.play("sfx_build_paint", volume: 0.6)
        }
        save()
    }

    private func report(_ result: BuildResult) {
        if case .built(let cost) = result, cost > 0, mode != .look { strokeHadWork = true }
        switch result {
        case .notEnoughCash(let needed): message = "Not enough cash. That costs \(Money.text(needed))."
        case .isSea: message = "That's the sea now."
        case .pinMustBeOnGreen: message = "Put the pin on a green."
        case .bridgeNeedsWater: message = "Bridges go over water."
        default: break
        }
    }

    var canUndo: Bool { engine?.canUndo ?? false }

    func undo() {
        guard var engine else { return }
        engine.undo()
        self.engine = engine
        save()
    }

    /// Re-lays the current hole. `signature` uses the legendary venue generator (debug builds only).
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
        guard let course, course.holes.indices.contains(index) else { return }
        endStroke()
        selectedHole = index
    }

    // MARK: Running the club

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

    func changeFee(by steps: Int) {
        guard var engine, let course else { return }
        engine.setFee(courseID: course.plotID, course.fee + steps * data.balance.fees.step)
        self.engine = engine
        save()
    }

    func upgrade(_ facilityID: String) {
        guard var engine, let course else { return }
        switch engine.upgrade(facilityID, courseID: course.plotID) {
        case .notEnoughCash(let needed): message = "Not enough cash. That costs \(Money.text(needed))."
        case .done:
            message = "Done. The builders are in."
            SoundBoard.shared.play("sfx_till")
        default: break
        }
        self.engine = engine
        save()
    }

    func setStaff(_ level: Int) {
        guard var engine, let course else { return }
        engine.setStaff(courseID: course.plotID, level: level)
        self.engine = engine
        save()
    }

    // MARK: The clock

    var speeds: [Int] { data.balance.clock.speeds }

    /// The clock runs on the map with nothing open, and on a course's Run tab.
    var clockIsRunning: Bool {
        let place = (screen == .course && tab == .run) || (screen == .map && !mapSheetOpen)
        return place && speeds[speedIndex] > 0 && watching == nil && !(engine?.state.isDayOver ?? true) && !showingCloseOfPlay
    }

    private func startClock() {
        clockTask = Task { [weak self] in
            let tick = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tick))
                self?.tickClock(seconds: tick)
            }
        }
    }

    private func tickClock(seconds: Double) {
        guard clockIsRunning, var engine else {
            minuteRemainder = 0
            return
        }
        minuteRemainder += seconds * data.balance.clock.gameMinutesPerRealSecond * Double(speeds[speedIndex])
        let minutes = Int(minuteRemainder)
        guard minutes > 0 else { return }
        minuteRemainder -= Double(minutes)
        let shown = screen == .course ? course : nil
        let groupsBefore = shown?.lastTeeMinute
        let roundsBefore = shown?.totalRounds ?? 0
        let dayEnded = engine.advance(minutes: minutes)
        self.engine = engine
        // Show golfers playing through on the hole on screen.
        if screen == .course, let course, course.totalRounds > roundsBefore, course.lastTeeMinute != groupsBefore {
            courseScene.sendGroup(size: min(4, course.totalRounds - roundsBefore))
        }
        if dayEnded {
            showingCloseOfPlay = true
            save()
        }
    }

    /// Runs the rest of today straight to close of play.
    func finishDay() {
        guard var engine else { return }
        stopWatching()
        engine.endStroke()
        engine.advance(minutes: 24 * 60)
        self.engine = engine
        showingCloseOfPlay = true
        save()
    }

    /// The "Start [date]" button.
    func startNextDay() {
        guard var engine else { return }
        engine.startNextDay()
        self.engine = engine
        showingCloseOfPlay = false
        save()
    }

    // MARK: Watch a round

    func watchRound() {
        guard var engine, let course, watching == nil else { return }
        if let problem = engine.openingProblem(course.plotID) {
            message = problem
            return
        }
        guard let round = engine.watchRound(courseID: course.plotID) else { return }
        self.engine = engine
        save()
        endStroke()
        mode = .look
        watching = Watching(round: round, line: round.opening.first ?? "", previousLine: nil, holeIndex: 0, strokesThisHole: 0)
        selectedHole = 0
        watchTask = Task { [weak self] in await self?.playBack(round) }
    }

    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        watching = nil
        courseScene.clearRound()
    }

    private func say(_ line: String?) {
        guard let line, !line.isEmpty, var w = watching else { return }
        w.previousLine = w.line
        w.line = line
        watching = w
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    private func playBack(_ round: WatchedRound) async {
        for line in round.opening.dropFirst() {
            guard await pause(1.6) else { return }
            say(line)
        }
        for hole in round.holes {
            guard await pause(1.2) else { return }
            selectedHole = hole.index
            watching?.holeIndex = hole.index
            watching?.strokesThisHole = 0
            if let intro = hole.intro { say(intro) }
            if hole.index == 0 { courseScene.dressGolfer(seed: UInt64(truncatingIfNeeded: round.golfer.name.hashValue)) }
            courseScene.startRound(at: hole.shots.first?.shot.from)
            guard await pause(1.0) else { return }
            for shot in hole.shots {
                await courseScene.play(shot.shot)
                guard !Task.isCancelled else { return }
                watching?.strokesThisHole += 1 + shot.shot.penalty
                say(shot.line)
                guard await pause(1.5) else { return }
            }
            say(hole.verdict)
            if !hole.shots.isEmpty, hole.strokes < hole.par, hole.verdict != nil {
                SoundBoard.shared.play("sfx_applause_polite", volume: 0.6)
            }
        }
        guard await pause(1.6) else { return }
        say(round.closing)
        guard await pause(1.6) else { return }
        say("\"\(round.review.quote)\" \(String(repeating: "★", count: round.review.stars))")
        watching?.finished = true
        courseScene.clearRound()
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
