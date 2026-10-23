import Foundation

public struct EventStatus: Equatable, Sendable {
    public struct Requirement: Equatable, Sendable {
        public let text: String
        public let met: Bool
    }
    public let event: String
    public let requirements: [Requirement]
    /// Days until it can be held here again (0 when free).
    public let waitDays: Int
    public let booked: Bool
    public var canBook: Bool { !booked && waitDays == 0 && requirements.allSatisfy(\.met) }
}

extension GameEngine {
    public func eventStatus(courseID: String, eventID: String) -> EventStatus? {
        guard let course = state.courses[courseID], let plot = data.plot(courseID),
              let spec = data.events.first(where: { $0.id == eventID }) else { return nil }
        let quality = CourseQuality.of(course.holes, balance: data.balance)
        var reqs: [EventStatus.Requirement] = []
        for r in spec.requirements {
            let v = r.value ?? 0
            switch r.kind {
            case .finished: reqs.append(.init(text: "Course open and finished", met: openingProblem(courseID) == nil && course.isOpen))
            case .reputation: reqs.append(.init(text: String(format: "Reputation %.1f or better", v * 2), met: course.reputation >= v))
            case .condition: reqs.append(.init(text: "Condition \(Int(v))% or better", met: course.condition >= v))
            case .holes: reqs.append(.init(text: "\(Int(v)) holes", met: course.holes.count == Int(v)))
            case .clubhouse:
                let names = data.facilities.first { $0.id == "club" }?.levels ?? []
                reqs.append(.init(text: names.indices.contains(Int(v)) ? "A \(names[Int(v)].lowercased())" : "A clubhouse", met: course.facilities.clubhouse >= Int(v)))
            case .shop: reqs.append(.init(text: v >= 2 ? "A flagship pro shop" : "A pro shop", met: course.facilities.shop >= Int(v)))
            case .range: reqs.append(.init(text: "A driving range", met: course.facilities.range >= Int(v)))
            case .design: reqs.append(.init(text: String(format: "Course design %.1f or better", v), met: quality.design.score >= v))
            case .yards: reqs.append(.init(text: "At least \(Self.thousands(Int(v))) yards", met: quality.yards >= Int(v)))
            case .links: reqs.append(.init(text: "Links land", met: plot.land == .links))
            case .prestige: reqs.append(.init(text: "Championship pedigree land", met: plot.prestige >= v))
            case .members:
                // Members arrive in a later update; until then this requirement is waived.
                continue
            case .hostedHere:
                let name = data.events.first { $0.id == r.event }?.name ?? "it"
                reqs.append(.init(text: "Hosted a \(name) here", met: r.event.flatMap { course.eventsHosted[$0] } != nil))
            }
        }
        var wait = 0
        if spec.onRota == true {
            wait = max(0, state.championshipOpensDay - state.day)
        } else if let last = course.eventsHosted[eventID] {
            wait = max(0, spec.cooldownDays - (state.day - last))
        }
        return EventStatus(event: eventID, requirements: reqs, waitDays: wait, booked: course.booking != nil)
    }

    /// Books an event for tomorrow. The course is closed to the public that day.
    @discardableResult
    public mutating func bookEvent(courseID: String, eventID: String) -> Bool {
        guard let status = eventStatus(courseID: courseID, eventID: eventID), status.canBook,
              let spec = data.events.first(where: { $0.id == eventID }) else { return false }
        state.courses[courseID]?.booking = EventBooking(eventID: eventID, day: state.day + 1)
        post("\(spec.name) booked at \(name(courseID)) for \(calendar.shortLabel(day: state.day + 1)).")
        return true
    }

    public mutating func cancelBooking(courseID: String) {
        state.courses[courseID]?.booking = nil
    }

    /// Runs at close of play on the event day: the field plays, the club is paid, reputation rises.
    mutating func runEvent(courseID: String) {
        guard let course = state.courses[courseID], let booking = course.booking, booking.day == state.day,
              let plot = data.plot(courseID), let spec = data.events.first(where: { $0.id == booking.eventID }) else { return }
        var pay = spec.pay
        if spec.payScalesWithCourse == true {
            pay = Int(Double(spec.pay) * (course.holes.count == 18 ? 1.6 : 1) * plot.wealth.squareRoot())
        }
        earn(.tournaments, pay)
        state.courses[courseID]?.reputation = min(5, course.reputation + spec.reputation)
        state.courses[courseID]?.eventsHosted[spec.id] = state.day
        state.courses[courseID]?.booking = nil

        if spec.id == "society" {
            post("Society day at \(plot.name): forty golfers, one argument about handicaps, and \(Self.money(pay)) in the till.")
            return
        }
        // Simulate the field and find the winner.
        let sim = simulator
        let prepared = course.holes.map(sim.prepare)
        let par = CourseQuality.of(course.holes, balance: data.balance).par
        let field = spec.id == "champ" ? 24 : 16
        var best: (name: String, score: Int)?
        for _ in 0..<field {
            let skill = spec.id == "champ" ? 0.9 + state.rng.unit() * 0.09 : spec.id == "regional" ? 0.8 + state.rng.unit() * 0.15 : 0.7 + state.rng.unit() * 0.2
            let golfer = Golfer(firstName: "", name: "\(state.rng.pick(data.golferNames.first)) \(state.rng.pick(data.golferNames.last))",
                                skill: skill, handicap: 0)
            let total = prepared.reduce(0) { $0 + sim.play($1, golfer: golfer, wind: sim.windFactor(course.weather), rng: &state.rng).strokes }
            if best == nil || total < best!.score { best = (golfer.name, total) }
        }
        let rel = Self.relativeText((best?.score ?? par) - par)
        post("\(spec.name) at \(plot.name): \(best?.name ?? "a local") wins on \(rel).")
        write(from: "Golf Gazette", title: "\(spec.name) at \(plot.name)",
              body: "\(best?.name ?? "A local") won the \(spec.name) with \(best?.score ?? par), \(rel). The club earned \(Self.money(pay))."
                + (spec.id == "champ" ? " What a week. What a course. Percy may weep." : " A fine champion on a fine course."))
        if spec.onRota == true {
            state.championshipOpensDay = state.day + data.balance.championship.rotaDays
            post("History made. \(plot.name) hosts The Championship. Next slot on the rota in \(data.balance.championship.rotaDays) days.")
        }
        announceMilestone(spec.id)
    }

    // MARK: Milestones

    mutating func checkMilestones() {
        let courses = state.orderedCourses
        if !courses.isEmpty { announceMilestone("bought") }
        if courses.contains(where: \.isOpen) { announceMilestone("opened") }
        if courses.contains(where: { $0.reputation >= 4 }) { announceMilestone("stars4") }
        if courses.count >= 3 { announceMilestone("three") }
        if let last = state.pastDays.last, last.net >= 2000, !courses.isEmpty { announceMilestone("profit") }
    }

    mutating func announceMilestone(_ id: String) {
        guard let m = data.milestones.first(where: { $0.id == id }), !state.milestones.contains(id) else { return }
        state.milestones.insert(id)
        post("Milestone reached: \(m.text.prefix(1).lowercased() + m.text.dropFirst()).")
        write(from: "Percy Hollis", title: "Milestone: \(m.text)", body: "Well done. \(m.text). Onwards.")
    }

    static func thousands(_ n: Int) -> String {
        n >= 1000 ? "\(n / 1000),\(String(format: "%03d", n % 1000))" : "\(n)"
    }
}
