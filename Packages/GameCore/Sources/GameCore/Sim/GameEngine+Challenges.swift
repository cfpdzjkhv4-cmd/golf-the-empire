import Foundation

/// How a challenge is going. Saved with the game.
public struct ChallengeProgress: Codable, Equatable, Sendable {
    public enum Outcome: Codable, Equatable, Sendable {
        case won(day: Int)
        case outOfTime
        case bankrupt
    }

    public let id: String
    /// Days in a row the goal has held, for goals that must hold for a while (Stockbroker belt).
    public var streak = 0
    public var bestStreak = 0
    /// Set once, when the challenge is won or lost. Play can carry on afterwards.
    public var outcome: Outcome?

    public init(id: String) {
        self.id = id
    }
}

/// One line of the goal, for the challenge panel: "Reputation 6.2 of 8.0".
public struct ChallengeGoalLine: Equatable, Sendable {
    public let text: String
    /// 0 to 1, for a progress bar.
    public let progress: Double
    public let met: Bool
}

public struct ChallengeStatus: Equatable, Sendable {
    public let challenge: String
    public let name: String
    public let goalText: String
    public let lines: [ChallengeGoalLine]
    /// Days left including today; 0 once time is up.
    public let daysLeft: Int
    public let outcome: ChallengeProgress.Outcome?
}

extension GameData {
    /// The challenges on the start screen, in order. Ones needing a later update are left out.
    public var playableChallenges: [Challenge] { challenges.filter { $0.comingLater != true } }

    public func challenge(_ id: String) -> Challenge? { challenges.first { $0.id == id } }
}

extension GameEngine {
    // MARK: Starting a challenge

    /// Starts a challenge on its fixed date, with its courses, cash and rivals. Nil for an unknown or unplayable id.
    public static func newChallenge(_ id: String, seed: UInt64, data: GameData = .bundled) -> GameEngine? {
        guard let challenge = data.challenge(id), challenge.comingLater != true else { return nil }
        let date = String(format: "%04d-%02d-%02d", data.balance.challenge.year, challenge.startMonth, challenge.startDay)
        let state = GameState(mode: .challenge(id: id), seed: seed, startDate: date,
                              cash: challenge.start.cash, dayStartMinute: data.balance.clock.dayStartMinute)
        var engine = GameEngine(data: data, state: state)
        engine.setUpChallenge(challenge)
        return engine
    }

    mutating func setUpChallenge(_ challenge: Challenge) {
        state.challenge = ChallengeProgress(id: challenge.id)
        // The player's courses come laid out and running, at the challenge's standard.
        for start in challenge.start.courses {
            acquire(start.plot, builtCourse: true)
            guard var course = state.courses[start.plot] else { continue }
            course.reputation = start.reputation
            course.condition = start.condition
            if let v = start.clubhouse { course.facilities.clubhouse = v }
            if let v = start.shop { course.facilities.shop = v }
            if let v = start.range { course.facilities.range = v }
            if let v = start.staff { course.facilities.staff = v }
            for (event, ago) in start.hostedDaysAgo ?? [:] { course.eventsHosted[event] = state.day - ago }
            course.boughtDay = 0
            state.courses[start.plot] = course
            let fee = suggestedFee(start.plot)
            state.courses[start.plot]?.fee = fee
            _ = setOpen(start.plot, true)
        }
        // Rival courses named by the challenge, before the usual rivals take their plots.
        for rc in challenge.start.rivalCourses ?? [] where state.courses[rc.plot] == nil {
            state.rivalCourses[rc.plot] = RivalCourse(plotID: rc.plot, owner: rc.rival, reputation: rc.reputation, sinceDay: 0)
        }
        setUpWorld()
        for rc in challenge.start.rivalCourses ?? [] {
            state.rivalCourses[rc.plot] = RivalCourse(plotID: rc.plot, owner: rc.rival, reputation: rc.reputation, sinceDay: 0)
            state.market.listings[rc.plot] = nil
        }
        for (rival, cash) in challenge.start.rivalCash ?? [:] { state.rivals[rival]?.cash = cash }
        for (rival, target) in challenge.start.rivalTargetReputation ?? [:] { state.rivals[rival]?.targetReputation = target }
        if challenge.start.courses.isEmpty { ensureAffordableSale() }
        // Starting courses shouldn't count towards the usual milestones' letters.
        state.letters.removeAll()
        state.news.removeAll()
        post("\(challenge.name). \(challenge.goalText). You have \(challenge.days) days.")
    }

    /// A shoestring start must always be able to buy something.
    mutating func ensureAffordableSale() {
        let limit = Int(Double(state.cash) * data.balance.challenge.affordableShare)
        let affordable = state.market.listings.values.contains { $0.kind == .quiet && $0.askingPrice <= limit }
        guard !affordable else { return }
        let cheapest = data.plotOrder.compactMap { data.plot($0) }
            .filter { isFree($0) && !$0.isReserve }
            .min { price($0.id) < price($1.id) }
        guard let plot = cheapest else { return }
        // Priced to sell: the vendor wants rid of it.
        let current = price(plot.id)
        if current > limit { state.market.priceMultiplier[plot.id] = (state.market.priceMultiplier[plot.id] ?? 1) * Double(limit) / Double(current) }
        guard var listing = list(plot.id, builtCourse: false) else { return }
        listing.kind = .quiet
        listing.closesDay = nil
        listing.interested = []
        listing.expiresDay = state.day + 30
        listing.guide = min(listing.guide, limit)
        state.market.listings[plot.id] = listing
    }

    // MARK: Checking the goal

    /// Where the challenge stands, for the challenge panel. Nil outside a challenge.
    public var challengeStatus: ChallengeStatus? {
        guard let progress = state.challenge, let challenge = data.challenge(progress.id) else { return nil }
        return ChallengeStatus(challenge: challenge.id, name: challenge.name, goalText: challenge.goalText,
                               lines: goalLines(challenge, progress: progress),
                               daysLeft: max(0, challenge.days - state.day + 1), outcome: progress.outcome)
    }

    func goalLines(_ challenge: Challenge, progress: ChallengeProgress) -> [ChallengeGoalLine] {
        let goal = challenge.goal
        func fraction(_ a: Double, _ b: Double) -> Double { b > 0 ? min(1, max(0, a / b)) : 1 }
        switch goal.kind {
        case "reputationAndCash":
            let rep = goal.plot.flatMap { state.courses[$0]?.reputation } ?? 0
            let target = goal.reputation ?? 5
            let cash = goal.cash ?? 0
            return [
                ChallengeGoalLine(text: String(format: "Reputation %.1f of %.1f", rep * 2, target * 2),
                                  progress: fraction(rep, target), met: rep >= target),
                ChallengeGoalLine(text: "\(Self.money(max(0, state.cash))) of \(Self.money(cash)) in the bank",
                                  progress: fraction(Double(state.cash), Double(cash)), met: state.cash >= cash),
            ]
        case "topOfRegion":
            let days = goal.daysRunning ?? 1
            let top = topOfRegion(southOf: goal.southOfLatitude ?? 52.3)
            let lead = top.mine.map { String(format: "%.1f", $0 * 2) } ?? "none"
            let best = top.rival.map { String(format: "%.1f", $0 * 2) } ?? "none"
            return [
                ChallengeGoalLine(text: "Your best course \(lead), best rival \(best)",
                                  progress: top.isTop ? 1 : fraction(top.mine ?? 0, top.rival ?? 1), met: top.isTop),
                ChallengeGoalLine(text: "\(progress.streak) of \(days) days running at the top",
                                  progress: fraction(Double(progress.streak), Double(days)), met: progress.streak >= days),
            ]
        case "hostEvent":
            let event = goal.event ?? "champ"
            let name = data.events.first { $0.id == event }?.name ?? "the event"
            let hosted = hostedEvent(event, at: goal.plot)
            let place = goal.plot.map { " at \(self.name($0))" } ?? ""
            return [ChallengeGoalLine(text: hosted ? "Hosted \(name)\(place)" : "Host \(name)\(place)", progress: hosted ? 1 : 0, met: hosted)]
        default:
            return [ChallengeGoalLine(text: challenge.goalText, progress: 0, met: false)]
        }
    }

    /// The player's and the rivals' best reputations among open courses south of a latitude.
    func topOfRegion(southOf latitude: Double) -> (mine: Double?, rival: Double?, isTop: Bool) {
        let mine = state.courses.values.filter { $0.isOpen && (data.plot($0.plotID)?.lat ?? 90) < latitude }.map(\.reputation).max()
        let rival = state.rivalCourses.values.filter { (data.plot($0.plotID)?.lat ?? 90) < latitude }.map(\.reputation).max()
        guard let m = mine else { return (nil, rival, false) }
        return (m, rival, m > (rival ?? 0))
    }

    func hostedEvent(_ event: String, at plot: String?) -> Bool {
        if let plot { return state.courses[plot]?.eventsHosted[event] != nil }
        return state.courses.values.contains { $0.eventsHosted[event] != nil }
    }

    /// Runs each morning, after the rivals: updates streaks, then decides win or loss once.
    mutating func checkChallenge() {
        guard var progress = state.challenge, progress.outcome == nil, let challenge = data.challenge(progress.id) else { return }
        let goal = challenge.goal
        var met: Bool
        switch goal.kind {
        case "topOfRegion":
            if topOfRegion(southOf: goal.southOfLatitude ?? 52.3).isTop { progress.streak += 1 } else { progress.streak = 0 }
            progress.bestStreak = max(progress.bestStreak, progress.streak)
            met = progress.streak >= (goal.daysRunning ?? 1)
        default:
            met = goalLines(challenge, progress: progress).allSatisfy(\.met)
        }
        if met {
            progress.outcome = .won(day: state.day)
            write(from: "Percy Hollis", title: "\(challenge.name): done",
                  body: "Well, I'll be. \(challenge.goalText), and with \(max(0, challenge.days - state.day + 1)) days to spare. "
                      + "I shall say nothing to the committee about how close it looked in the spring.")
            post("Challenge complete: \(challenge.name).")
        } else if state.cash < data.balance.challenge.bankruptcyCash {
            progress.outcome = .bankrupt
            write(from: "The bank", title: "We are calling in the loan",
                  body: "Your account stands at \(Self.money(state.cash)). We regret that we can no longer support the business. \(challenge.name) is over.")
            post("Challenge failed: the bank has called in the loan.")
        } else if state.day > challenge.days {
            progress.outcome = .outOfTime
            write(from: "Percy Hollis", title: "\(challenge.name): time's up",
                  body: "That's the time, I'm afraid. Not quite there. The bar is open, if that helps. It usually does.")
            post("Challenge failed: out of time.")
        }
        state.challenge = progress
    }
}
