import Foundation

/// What a build tool lays down.
public enum BuildTool: Equatable, Sendable {
    case paint(Tile)
    case tee
    case pin
}

public enum BuildResult: Equatable, Sendable {
    case built(cost: Int)
    case nothingChanged
    case notEnoughCash(needed: Int)
    case isSea
    case pinMustBeOnGreen
    case bridgeNeedsWater
    case noSuchHole
}

/// The game: rules applied to a GameState. Rendering and UI send it commands and read its state.
public struct GameEngine: Sendable {
    public let data: GameData
    public internal(set) var state: GameState

    struct UndoStep: Sendable {
        let courseID: String
        let holeIndex: Int
        let before: Hole
        var cost: Int
    }
    /// Not saved: undo only lasts for the session.
    var undoSteps: [UndoStep] = []
    var openStroke: UndoStep?
    static let maxUndoSteps = 50
    /// Percy's last line in each category, so he never repeats himself back to back. Not saved.
    var percyLast: [String: String] = [:]
    /// Each open course's layout worked out for play, reused until its holes change. Not saved.
    var preparedCourses: [String: PreparedCourse] = [:]

    public init(data: GameData = .bundled, state: GameState) {
        self.data = data
        self.state = state
    }

    private var balance: Balance { data.balance }
    public var calendar: GameCalendar { GameCalendar(startDate: state.startDate, balance: balance) }
    public var designer: CourseDesigner { CourseDesigner(balance: balance) }
    public var analyzer: HoleAnalyzer { HoleAnalyzer(balance: balance) }
    public var holeRules: HoleRules { HoleRules(balance: balance) }
    var generator: HoleGenerator { HoleGenerator(balance: balance) }
    public var economy: ClubEconomy { ClubEconomy(data: data) }
    var simulator: ShotSimulator { ShotSimulator(balance: balance) }

    // MARK: Starting a game

    /// Milestone 1: one course on a chosen plot. The land is free; the auto layout is charged.
    public static func newSandbox(plotID: String, seed: UInt64, startDate: String, data: GameData = .bundled) -> GameEngine {
        let state = GameState(
            mode: .sandbox, seed: seed, startDate: startDate,
            cash: data.balance.career.startingCash, dayStartMinute: data.balance.clock.dayStartMinute
        )
        var engine = GameEngine(data: data, state: state)
        engine.addCourse(plotID: plotID, autoLayout: true)
        return engine
    }

    /// Puts a new course on a plot: untouched land, optionally auto laid out (and charged for).
    @discardableResult
    mutating func addCourse(plotID: String, autoLayout: Bool) -> Bool {
        guard let plot = data.plot(plotID), state.courses[plotID] == nil else { return false }
        let generator = self.generator
        var holes: [Hole] = []
        var buildCost = 0
        for par in data.standardPars(holes: plot.holes) {
            let land = generator.baseLand(plot.land, rng: &state.rng)
            if autoLayout {
                let laid = generator.autoLayout(par: par, land: plot.land, on: land, rng: &state.rng)
                buildCost += generator.cost(from: land, to: laid)
                holes.append(laid)
            } else {
                holes.append(land)
            }
        }
        var course = Course(
            plotID: plotID, holes: holes,
            reputation: balance.course.startReputation, condition: balance.course.startCondition
        )
        course.weather = rollWeather(for: plot, day: state.day)
        state.courses[plotID] = course
        state.courseOrder.append(plotID)
        if buildCost > 0 { spend(.buildingWork, buildCost) }
        let fee = suggestedFee(plotID)
        state.courses[plotID]?.fee = fee
        return true
    }

    // MARK: Money

    /// Every pound earned goes through here.
    public mutating func earn(_ category: LedgerCategory, _ amount: Int) {
        precondition(category.isIncome, "\(category) is not income")
        record(category, amount)
        state.cash += amount
    }

    /// Every pound spent goes through here.
    public mutating func spend(_ category: LedgerCategory, _ amount: Int) {
        precondition(!category.isIncome, "\(category) is not spending")
        record(category, amount)
        state.cash -= amount
    }

    /// Gives back money spent today, for undo. Recorded as negative spending so the books still balance.
    private mutating func refund(_ category: LedgerCategory, _ amount: Int) {
        record(category, -amount)
        state.cash += amount
    }

    private mutating func record(_ category: LedgerCategory, _ amount: Int) {
        state.today.record(category, amount)
        state.lifetime[category, default: 0] += amount
    }

    // MARK: Time

    /// Moves the clock on. Runs close of play at 19:00. Returns true if the day ended.
    @discardableResult
    public mutating func advance(minutes: Int) -> Bool {
        guard !state.isDayOver, minutes > 0 else { return false }
        let end = min(state.minute + minutes, balance.clock.dayEndMinute)
        // Layouts can't change while the clock runs, so work out each open course's quality once.
        var prepared: [String: PreparedCourse] = [:]
        for id in state.courseOrder {
            guard let course = state.courses[id], course.isOpen else { continue }
            if let cached = preparedCourses[id], cached.layout == course.holes {
                prepared[id] = cached
            } else {
                prepared[id] = prepare(course)
                preparedCourses[id] = prepared[id]
            }
        }
        while state.minute < end {
            for id in state.courseOrder {
                if let course = prepared[id] { teeTimes(courseID: id, prepared: course) }
            }
            state.minute += 1
        }
        if state.minute >= balance.clock.dayEndMinute {
            closeOfPlay()
            return true
        }
        return false
    }

    /// 19:00: wages, upkeep, condition and tomorrow's weather.
    public mutating func closeOfPlay() {
        guard !state.isDayOver else { return }
        let winter = calendar.isWinter(day: state.day)
        for id in state.courseOrder {
            guard var course = state.courses[id], let plot = data.plot(id) else { continue }
            if course.isOpen {
                let u = upkeep(of: course), w = wages(of: course)
                spend(.upkeep, u)
                spend(.staffWages, w)
                course.today.upkeep = u
                course.today.wages = w
            }
            // Reputation moves 7% of the way towards today's average review, up to the ceiling.
            let quality = CourseQuality.of(course.holes, balance: balance)
            let cap = economy.reputationCeiling(course, quality: quality)
            if let average = course.today.averageStars {
                course.reputation += (min(average, cap) - course.reputation) * balance.reputation.dailyMove
            }
            course.reputation = min(cap, max(0, course.reputation))
            let c = balance.course
            let recovery = balance.greenkeepers.conditionRecovery[max(0, min(course.facilities.staff - 1, 2))]
            let weatherLoss = course.weather == .rain ? c.rainConditionLoss : course.weather == .storm ? c.stormConditionLoss : 0
            let winterLoss = winter ? balance.calendar.winterConditionLoss : 0
            course.condition = min(c.conditionMax, max(c.conditionMin, course.condition + recovery - weatherLoss - winterLoss))
            course.weather = rollWeather(for: plot, day: state.day + 1)
            state.courses[id] = course
        }
        state.minute = balance.clock.dayEndMinute
        state.isDayOver = true
    }

    /// The "Start [date]" button.
    public mutating func startNextDay() {
        if !state.isDayOver { closeOfPlay() }
        state.pastDays.append(state.today)
        if state.pastDays.count > 60 { state.pastDays.removeFirst(state.pastDays.count - 60) }
        for id in state.courseOrder {
            guard var course = state.courses[id] else { continue }
            course.yesterday = course.today
            course.today = CourseDay()
            course.lastTeeMinute = nil
            state.courses[id] = course
        }
        state.day += 1
        state.minute = balance.clock.dayStartMinute
        state.isDayOver = false
        state.today = DayBooks(day: state.day, openingCash: state.cash)
    }

    /// Plays whole days with nobody touching anything. For tests and balance reports.
    public mutating func simulateDays(_ days: Int) {
        for _ in 0..<days {
            while !advance(minutes: 10) {}
            startNextDay()
        }
    }

    // MARK: Weather

    mutating func rollWeather(for plot: Plot, day: Int) -> Weather {
        let w = balance.weather
        let links = plot.land == .links
        if links {
            let winter = calendar.isWinter(day: day) ? balance.calendar.winterStormMultiplier : 1
            if state.rng.chance(w.stormChanceLinks * winter) { return .storm }
        }
        let r = state.rng.unit()
        let north = plot.lat > w.northLatitude ? w.northRainBonus : 0
        let windy = links ? w.windChanceLinks : w.windChanceInland
        if r < w.rainChance + north { return .rain }
        if r < w.rainChance + north + windy { return .wind }
        if r < w.rainChance + north + windy + w.cloudChance { return .cloud }
        return .sun
    }

    // MARK: Running costs

    /// Daily upkeep, not counting wages: £60 plus per hole £12 and a little per tile.
    public func upkeep(of course: Course) -> Int {
        let u = balance.upkeep
        var total = u.base
        for hole in course.holes {
            total += u.perHole
                + Double(hole.count(of: .fairway)) * u.perFairwayTile
                + Double(hole.count(of: .green)) * u.perGreenTile
                + Double(hole.count(of: .bunker)) * u.perBunkerTile
                + Double(hole.count(of: .water)) * u.perWaterTile
        }
        return Int(total.rounded())
    }

    public func wages(of course: Course) -> Int {
        let g = balance.greenkeepers
        let perLevel = course.holes.count == 18 ? g.dailyWage18PerLevel : g.dailyWage9PerLevel
        return (course.facilities.staff - 1) * perLevel
    }

    /// The fair fee before the design "interest" uplift, rounded to £5. Used as the opening green fee.
    public func suggestedFee(_ courseID: String) -> Int {
        guard let course = state.courses[courseID], let plot = data.plot(courseID) else { return 10 }
        return economy.roundedFee(economy.fairFee(course, plot: plot, quality: CourseQuality.of(course.holes, balance: balance)))
    }

    // MARK: Courses

    public func course(_ id: String) -> Course? { state.courses[id] }

    public func design(of courseID: String) -> CourseDesign? {
        state.courses[courseID].map { designer.design(of: $0.holes) }
    }

    /// The first hole that stops the course opening, e.g. "Hole 3 needs a tee".
    public func openingProblem(_ courseID: String) -> String? {
        guard let course = state.courses[courseID] else { return "No such course" }
        for (i, hole) in course.holes.enumerated() {
            if let issue = holeRules.issue(hole) { return "Hole \(i + 1) \(issue.text)" }
        }
        return nil
    }

    @discardableResult
    public mutating func setOpen(_ courseID: String, _ open: Bool) -> Bool {
        guard state.courses[courseID] != nil else { return false }
        if open && openingProblem(courseID) != nil { return false }
        state.courses[courseID]?.isOpen = open
        return true
    }

    // MARK: Building

    /// Paints one tile, or a round patch: `brushRadius` 1 is 3 × 3, 2 is 21 tiles. Call `endStroke()` when the finger lifts,
    /// so one drag is one undo step.
    @discardableResult
    public mutating func build(_ tool: BuildTool, courseID: String, hole holeIndex: Int, at point: GridPoint, brushRadius: Int = 0) -> BuildResult {
        guard var course = state.courses[courseID], course.holes.indices.contains(holeIndex) else { return .noSuchHole }
        var hole = course.holes[holeIndex]
        guard let current = hole[point.x, point.y] else { return .nothingChanged }
        if current == .sea { return .isSea }
        let costs = balance.tileCost
        let before = hole
        var cost = 0

        switch tool {
        case .pin:
            guard current == .green else { return .pinMustBeOnGreen }
            if hole.pin == point { return .nothingChanged }
            hole.pin = point
        case .tee:
            if hole.tee == point { return .nothingChanged }
            cost = costs.tee
            guard state.cash >= cost else { return .notEnoughCash(needed: cost) }
            if let old = hole.tee { hole.set(old.x, old.y, .rough) }
            if hole.pin == point { hole.pin = nil }
            hole.set(point.x, point.y, .tee)
            hole.tee = point
        case .paint(let tile):
            guard tile != .sea, tile != .tee else { return .nothingChanged }
            if tile == .bridge && current != .water && current != .bridge { return .bridgeNeedsWater }
            for dy in -brushRadius...brushRadius {
                for dx in -brushRadius...brushRadius where dx * dx + dy * dy <= brushRadius * brushRadius + brushRadius {
                    let x = point.x + dx, y = point.y + dy
                    guard let t = hole[x, y], t != tile, t != .sea else { continue }
                    // Bridges only go over water.
                    if tile == .bridge && t != .water { continue }
                    let price = costs.cost(of: tile)
                    guard state.cash >= cost + price else {
                        if cost == 0 { return .notEnoughCash(needed: price) }
                        continue
                    }
                    if hole.tee == GridPoint(x: x, y: y) { hole.tee = nil }
                    if hole.pin == GridPoint(x: x, y: y) && tile != .green { hole.pin = nil }
                    hole.set(x, y, tile)
                    cost += price
                }
            }
        }
        if hole == before { return .nothingChanged }

        if openStroke == nil || openStroke?.courseID != courseID || openStroke?.holeIndex != holeIndex {
            endStroke()
            openStroke = UndoStep(courseID: courseID, holeIndex: holeIndex, before: before, cost: 0)
        }
        openStroke?.cost += cost
        course.holes[holeIndex] = hole
        state.courses[courseID] = course
        if cost > 0 { spend(.buildingWork, cost) }
        return .built(cost: cost)
    }

    /// Closes the current drag as one undo step.
    public mutating func endStroke() {
        guard let stroke = openStroke else { return }
        openStroke = nil
        undoSteps.append(stroke)
        if undoSteps.count > Self.maxUndoSteps { undoSteps.removeFirst() }
    }

    public var canUndo: Bool { openStroke != nil || !undoSteps.isEmpty }

    /// Puts the last change back and refunds what it cost.
    @discardableResult
    public mutating func undo() -> Bool {
        endStroke()
        guard let step = undoSteps.popLast(), state.courses[step.courseID] != nil else { return false }
        state.courses[step.courseID]?.holes[step.holeIndex] = step.before
        if step.cost > 0 { refund(.buildingWork, step.cost) }
        if state.courses[step.courseID]?.isOpen == true, openingProblem(step.courseID) != nil {
            state.courses[step.courseID]?.isOpen = false
        }
        return true
    }

    /// Replaces a hole with a fresh auto layout (or, with `signature`, the legendary venue generator),
    /// charging for every changed tile.
    @discardableResult
    public mutating func relayHole(courseID: String, hole holeIndex: Int, signature: Bool = false) -> BuildResult {
        guard let course = state.courses[courseID], let plot = data.plot(courseID),
              course.holes.indices.contains(holeIndex) else { return .noSuchHole }
        let par = data.standardPars(holes: course.holes.count)[holeIndex]
        let old = course.holes[holeIndex]
        var rng = state.rng
        let new = signature
            ? generator.bestSignatureLayout(par: par, land: plot.land, on: old, rng: &rng)
            : generator.autoLayout(par: par, land: plot.land, on: old, rng: &rng)
        let cost = generator.cost(from: old, to: new)
        guard state.cash >= cost else { return .notEnoughCash(needed: cost) }
        state.rng = rng
        endStroke()
        undoSteps.append(UndoStep(courseID: courseID, holeIndex: holeIndex, before: old, cost: cost))
        state.courses[courseID]?.holes[holeIndex] = new
        if cost > 0 { spend(.buildingWork, cost) }
        return .built(cost: cost)
    }
}
