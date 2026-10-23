import Foundation

extension GameEngine {
    /// Rival courses move towards their owner's standards, earn money, and now and then go bust or get sold.
    /// Budget chains snap up cheap quiet sales, and good rival links courses can take The Championship.
    mutating func rivalsDay() {
        let r = data.balance.rivals
        for id in state.rivalCourses.keys.sorted() {
            guard var course = state.rivalCourses[id], let rival = data.rivals.first(where: { $0.id == course.owner }),
                  let plot = data.plot(id) else { continue }
            let target = state.rivals[rival.id]?.targetReputation ?? rival.targetReputation
            course.reputation = min(5, max(1, course.reputation + (target - course.reputation) * r.reputationDrift + state.rng.gauss() * r.reputationNoise))
            state.rivalCourses[id] = course
            let income = (plot.holes == 18 ? r.dailyIncome18 : r.dailyIncome9) * plot.wealth * course.reputation / 4
            state.rivals[rival.id]?.cash += Int(income)

            let budget = rival.targetReputation <= 3.0
            if (budget && course.reputation < r.budgetBustReputation && state.rng.chance(r.budgetBustChance)) || state.rng.chance(r.anyBustChance) {
                state.rivalCourses[id] = nil
                if let l = list(id, builtCourse: true, closesIn: data.balance.market.administrationCloseDays) {
                    post("\(rival.name) puts \(plot.name) into administration. " + headline(l))
                }
            } else if state.rng.chance(r.sellChance) {
                state.rivalCourses[id] = nil
                let half = price(id) / 2
                state.rivals[rival.id]?.cash += half
                if let l = list(id, builtCourse: true, closesIn: state.rng.int(5...8)) {
                    post("\(rival.name) is selling \(plot.name). " + headline(l))
                }
            }
        }

        // Budget chains snap up cheap land.
        for rival in data.rivals where rival.targetReputation <= 3.0 {
            for id in state.market.listings.keys.sorted() {
                guard let l = state.market.listings[id], l.kind == .quiet, l.askingPrice <= r.snapUpMaxPrice,
                      rivalCount(rival.id) < rival.maxCourses, (state.rivals[rival.id]?.cash ?? 0) >= l.askingPrice,
                      state.rng.chance(r.snapUpChance) else { continue }
                state.market.listings[id] = nil
                state.rivals[rival.id]?.cash -= l.askingPrice
                state.rivalCourses[id] = RivalCourse(plotID: id, owner: rival.id, reputation: 2.5, sinceDay: state.day)
                post("\(rival.name) snaps up \(name(id)) for \(Self.money(l.askingPrice)). Expect a burger van by the weekend.")
            }
        }

        // The Championship rota: a strong rival links course may take the next slot.
        let c = data.balance.championship
        if state.day >= state.championshipOpensDay {
            let candidates = state.rivalCourses.values.filter { rc in
                guard let p = data.plot(rc.plotID) else { return false }
                return p.land == .links && p.prestige >= c.minPrestige && p.holes == 18 && rc.reputation >= c.rivalMinReputation
            }.sorted { $0.plotID < $1.plotID }
            if !candidates.isEmpty && state.rng.chance(c.rivalTakeChance) {
                let winner = state.rng.pick(candidates)
                state.championshipOpensDay = state.day + c.rotaDays
                state.rivalCourses[winner.plotID]?.reputation = min(5, winner.reputation + 0.2)
                post("The Championship goes to \(name(winner.plotID)), owned by \(displayName(winner.owner)). Next slot on the rota in \(c.rotaDays) days.")
            }
        }
    }

    /// Rival courses nearby take some of a course's golfers: up to 20% each, more for better courses, less further away.
    public func competition(for courseID: String) -> Double {
        guard let plot = data.plot(courseID) else { return 1 }
        let r = data.balance.rivals
        var factor = 1.0
        for rc in state.rivalCourses.values {
            guard let other = data.plot(rc.plotID) else { continue }
            let d = plot.location.km(to: other.location)
            if d < r.competitionKm {
                factor *= 1 - r.competitionMax * (rc.reputation / 5) * (1 - d / r.competitionKm)
            }
        }
        return factor
    }

    /// Rival clubs within reach of a course, nearest first, for the Run tab.
    public func nearbyRivals(of courseID: String) -> [(course: RivalCourse, km: Double)] {
        guard let plot = data.plot(courseID) else { return [] }
        return state.rivalCourses.values
            .map { ($0, plot.location.km(to: data.plot($0.plotID)?.location ?? plot.location)) }
            .filter { $0.1 < data.balance.rivals.competitionKm }
            .sorted { $0.1 < $1.1 }
    }
}
