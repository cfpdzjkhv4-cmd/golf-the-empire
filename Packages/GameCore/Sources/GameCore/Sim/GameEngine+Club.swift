import Foundation

/// A round followed shot by shot, with Percy's commentary, for "Watch a round".
public struct WatchedRound: Equatable, Sendable {
    public struct HoleLog: Equatable, Sendable {
        public let index: Int
        /// "On to the 2nd. 389 yards, par 4." (nil on the 1st, which has the arrival line).
        public let intro: String?
        public let shots: [ShotLog]
        public let strokes: Int
        public let par: Int
        /// "Birdie. They'll be dining out on that for weeks."
        public let verdict: String?
    }
    public struct ShotLog: Equatable, Sendable {
        public let shot: Shot
        public let line: String
    }

    public let golfer: Golfer
    public let opening: [String]
    public let holes: [HoleLog]
    public let total: Int
    public let par: Int
    public let closing: String
    public let review: Review
}

public enum ClubResult: Equatable, Sendable {
    case done
    case notEnoughCash(needed: Int)
    case alreadyTopLevel
    case notAvailable
}

/// A course's layout worked out once while the clock runs: quality and aim points.
struct PreparedCourse: Sendable {
    let layout: [Hole]
    let quality: CourseQuality
    let holes: [ShotSimulator.PreparedHole]
}

extension GameEngine {
    func prepare(_ course: Course) -> PreparedCourse {
        let sim = simulator
        return PreparedCourse(layout: course.holes, quality: CourseQuality.of(course.holes, balance: data.balance),
                              holes: course.holes.map(sim.prepare))
    }

    // MARK: Reading

    public func quality(of courseID: String) -> CourseQuality? {
        state.courses[courseID].map { CourseQuality.of($0.holes, balance: data.balance) }
    }

    // MARK: Golfers arriving

    /// One game minute at one open course: maybe a group turns up and tees off.
    mutating func teeTimes(courseID: String, prepared: PreparedCourse) {
        let quality = prepared.quality
        guard let course = state.courses[courseID], let plot = data.plot(courseID) else { return }
        let rate = economy.groupsPerHour(course, plot: plot, quality: quality, calendar: calendar, day: state.day)
        guard state.rng.chance(rate / 60) else { return }
        if let last = course.lastTeeMinute, state.minute - last < data.balance.golfers.teeIntervalMinutes {
            state.courses[courseID]?.today.walkedAway += 1
            return
        }
        state.courses[courseID]?.lastTeeMinute = state.minute
        let size = 1 + Int(state.rng.unit() * Double(data.balance.golfers.groupSizeMax))
        for _ in 0..<size { playRound(courseID: courseID, prepared: prepared) }
    }

    /// A visitor plays all the holes, pays, reviews and spends in the bar.
    @discardableResult
    mutating func playRound(courseID: String, prepared: PreparedCourse) -> (golfer: Golfer, holes: [HoleResult], review: Review)? {
        guard let course = state.courses[courseID] else { return nil }
        let sim = simulator
        let golfer = sim.makeGolfer(reputation: course.reputation, names: data.golferNames, rng: &state.rng)
        let wind = sim.windFactor(course.weather)
        var results: [HoleResult] = []
        for hole in prepared.holes {
            results.append(sim.play(hole, golfer: golfer, wind: wind, rng: &state.rng))
        }
        let review = finishRound(courseID: courseID, golfer: golfer, results: results, quality: prepared.quality)
        return (golfer, results, review)
    }

    private mutating func finishRound(courseID: String, golfer: Golfer, results: [HoleResult], quality: CourseQuality) -> Review {
        var course = state.courses[courseID]!
        let plot = data.plot(courseID)!
        let score = results.reduce(0) { $0 + $1.strokes }
        let penalties = results.reduce(0) { $0 + $1.penalties }
        let review = economy.review(course: course, plot: plot, quality: quality, golfer: golfer, score: score,
                                    penalties: penalties, day: state.day, rng: &state.rng)
        let bar = economy.barSpend(stars: review.stars, course: course, plot: plot)
        earn(.greenFees, course.fee)
        earn(.barAndShop, bar)

        course.reviews.insert(review, at: 0)
        if course.reviews.count > data.balance.reviews.kept { course.reviews.removeLast(course.reviews.count - data.balance.reviews.kept) }
        let c = data.balance.course
        course.condition = min(c.conditionMax, max(c.conditionMin, course.condition - (course.holes.count == 18 ? c.wearPerRound18 : c.wearPerRound9)))
        course.today.rounds += 1
        course.today.visitors += 1
        course.today.greenFees += course.fee
        course.today.barAndShop += bar
        course.today.starsTotal += review.stars
        course.today.reviews += 1
        course.totalRounds += 1
        if course.bestScore == nil || score < course.bestScore! { course.bestScore = score }
        state.courses[courseID] = course
        return review
    }

    // MARK: Watch a round

    /// Sends one golfer out now and records every shot with Percy's commentary.
    /// The round counts like any other (fee, review, bar); the app then plays the log back.
    public mutating func watchRound(courseID: String) -> WatchedRound? {
        guard let course = state.courses[courseID], openingProblem(courseID) == nil else { return nil }
        let prepared = prepare(course)
        let quality = prepared.quality
        let rules = holeRules
        guard let round = playRound(courseID: courseID, prepared: prepared) else { return nil }
        let golfer = round.golfer

        var opening = [percy("wx_" + course.weather.rawValue), percy("arrive", ["full": golfer.name, "hcp": "\(golfer.handicap)"])]
        opening.removeAll { $0.isEmpty }
        var holes: [WatchedRound.HoleLog] = []
        for (i, result) in round.holes.enumerated() {
            let hole = course.holes[i]
            let par = rules.par(hole)
            let intro = i == 0 ? nil : percy("nexthole", [
                "n": ClubEconomy.ordinal(i + 1), "yd": "\(Int(rules.yards(hole).rounded()))", "p": "\(par)",
            ])
            var shots: [WatchedRound.ShotLog] = []
            for (n, shot) in result.shots.enumerated() {
                let key = shot.holed && n == 0 ? "ace" : shot.outcome.rawValue
                shots.append(WatchedRound.ShotLog(shot: shot, line: percy(key)))
            }
            var verdict: String?
            if result.pickedUp {
                verdict = percy("pickup")
            } else if result.shots.count > 1 {
                let rel = result.strokes - par
                verdict = percy(rel <= -2 ? "eagle" : rel == -1 ? "birdie" : rel == 0 ? "par" : rel == 1 ? "bogey" : "double")
            }
            holes.append(WatchedRound.HoleLog(index: i, intro: intro, shots: shots, strokes: result.strokes, par: par, verdict: verdict))
        }
        let total = round.holes.reduce(0) { $0 + $1.strokes }
        let closing = percy("roundend", ["total": "\(total)", "rel": Self.relativeText(total - quality.par)])
        return WatchedRound(golfer: golfer, opening: opening, holes: holes, total: total, par: quality.par,
                            closing: closing, review: round.review)
    }

    public static func relativeText(_ r: Int) -> String {
        r == 0 ? "level par" : r > 0 ? "\(r) over" : "\(-r) under"
    }

    /// A Percy line from a category, never the same as his last one in that category.
    mutating func percy(_ category: String, _ values: [String: String] = [:]) -> String {
        guard let lines = data.percy.lines[category], !lines.isEmpty else { return "" }
        var line = state.rng.pick(lines)
        while lines.count > 1 && line == percyLast[category] { line = state.rng.pick(lines) }
        percyLast[category] = line
        for (k, v) in values { line = line.replacingOccurrences(of: "{\(k)}", with: v) }
        return line
    }

    // MARK: Running the club

    /// Sets the green fee, rounded to £5 steps.
    public mutating func setFee(courseID: String, _ fee: Int) {
        guard state.courses[courseID] != nil else { return }
        let rounded = economy.roundedFee(Double(fee))
        state.courses[courseID]?.fee = rounded
    }

    /// Facility ids: club, shop, range, sea. Buys the next level up.
    @discardableResult
    public mutating func upgrade(_ facilityID: String, courseID: String) -> ClubResult {
        guard var course = state.courses[courseID], let plot = data.plot(courseID),
              let facility = data.facilities.first(where: { $0.id == facilityID }) else { return .notAvailable }
        if facility.linksOnly == true && plot.land != .links { return .notAvailable }
        let level: Int
        switch facilityID {
        case "club": level = course.facilities.clubhouse
        case "shop": level = course.facilities.shop
        case "range": level = course.facilities.range
        case "sea": level = course.facilities.seaDefence
        default: return .notAvailable
        }
        guard level + 1 < facility.costs.count else { return .alreadyTopLevel }
        let cost = facility.costs[level + 1]
        guard state.cash >= cost else { return .notEnoughCash(needed: cost) }
        switch facilityID {
        case "club": course.facilities.clubhouse += 1
        case "shop": course.facilities.shop += 1
        case "range": course.facilities.range += 1
        default: course.facilities.seaDefence += 1
        }
        state.courses[courseID] = course
        spend(.facilities, cost)
        return .done
    }

    /// Greenkeeping team, 1 to 3. Costs wages each day rather than up front.
    public mutating func setStaff(courseID: String, level: Int) {
        guard state.courses[courseID] != nil else { return }
        state.courses[courseID]?.facilities.staff = min(3, max(1, level))
    }
}
