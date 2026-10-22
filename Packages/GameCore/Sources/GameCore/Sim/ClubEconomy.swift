import Foundation

/// The money and reputation formulas for one club: fees, demand, spend, reviews, ceilings.
/// Pure functions of the course, its plot and the day, so they can be tested and shown in the UI.
public struct ClubEconomy: Sendable {
    public let data: GameData
    private var balance: Balance { data.balance }

    public init(data: GameData) {
        self.data = data
    }

    // MARK: Fees

    /// What the fee "should" be: (20 + rep × 7) × wealth × (1.6 for 18 holes) × (0.8 + design × 0.045).
    public func fairFee(_ course: Course, plot: Plot, quality: CourseQuality) -> Double {
        let f = balance.fees
        return (f.base + course.reputation * f.perReputation) * plot.wealth
            * (course.holes.count == 18 ? f.eighteenHoleFactor : 1)
            * (f.designBase + quality.design.score * f.designPer)
    }

    /// What locals think is fair: the fair fee plus up to 30% for interesting holes.
    public func localFairFee(_ course: Course, plot: Plot, quality: CourseQuality) -> Double {
        fairFee(course, plot: plot, quality: quality) * (1 + quality.interest * balance.fees.interestUplift)
    }

    public func roundedFee(_ pounds: Double) -> Int {
        let f = balance.fees
        return min(f.maximum, max(f.minimum, Int((pounds / Double(f.step)).rounded()) * f.step))
    }

    // MARK: Demand

    /// Price factor: clamp(1.5 − 0.6 × fee / fair fee, 0.15, 1.5).
    public func priceFactor(_ course: Course, plot: Plot, quality: CourseQuality) -> Double {
        let d = balance.demand
        let fair = max(1, fairFee(course, plot: plot, quality: quality))
        return min(d.priceMax, max(d.priceMin, d.priceBase - Double(course.fee) / fair * d.pricePerFairRatio))
    }

    /// Visitor groups per hour right now.
    public func groupsPerHour(_ course: Course, plot: Plot, quality: CourseQuality, calendar: GameCalendar, day: Int) -> Double {
        let d = balance.demand
        return plot.demand * d.groupsPerHourPerDemand
            * (d.reputationBase + course.reputation / d.reputationDivisor)
            * priceFactor(course, plot: plot, quality: quality)
            * (balance.weather.demand[course.weather.rawValue] ?? 1)
            * (course.facilities.range > 0 ? d.rangeBonus : 1)
            * (d.designBase + quality.design.score * d.designPer)
            * calendar.seasonDemand(day: day)
            * calendar.weekdayDemand(day: day)
    }

    // MARK: Spend

    /// Bar and shop spend after a round: ((10 + stars × 3) × clubhouse + shop) × √wealth.
    public func barSpend(stars: Int, course: Course, plot: Plot) -> Int {
        let club = data.facilities.first { $0.id == "club" }?.barMultiplier ?? [0.6, 1, 1.5, 2.2]
        let shop = data.facilities.first { $0.id == "shop" }?.spendBonus ?? [0, 6, 14]
        let spend = ((balance.spend.barBase + Double(stars) * balance.spend.barPerStar) * club[min(course.facilities.clubhouse, club.count - 1)]
            + shop[min(course.facilities.shop, shop.count - 1)]) * plot.wealth.squareRoot()
        return Int(spend.rounded())
    }

    // MARK: Reviews

    /// One golfer's review. Score and penalties are for the whole round.
    public func review(course: Course, plot: Plot, quality: CourseQuality, golfer: Golfer, score: Int, penalties: Int,
                       day: Int, rng: inout SeededRandom) -> Review {
        let r = balance.reviews
        let n = Double(max(1, course.holes.count))
        // Judged against the golfer's own standard: a 20 handicapper expects to drop about a shot a hole.
        let overPerHole = Double(score - quality.par) / n - Double(golfer.handicap) / 18
        var factors: [(String, Double)] = [
            ("design", (quality.design.score - r.designFrom) * r.designPer),
            ("pretty", quality.beauty * r.beautyWeight),
            ("variety", quality.variety),
            ("setting", (plot.prestige - 1) * r.prestigeWeight),
            ("score", overPerHole <= r.scoreGreatBelow ? r.scoreUnderPar
                : overPerHole < r.scoreSmallOverLimit ? r.scoreSmallOver
                : overPerHole < r.scoreFairLimit ? 0
                : overPerHole < r.scoreBadLimit ? r.scoreBad : r.scoreAwful),
            ("pens", -min(r.penaltyMax, Double(penalties) * r.penaltyEach)),
        ]
        if quality.weakHoles > 0 { factors.append(("weak", -r.weakPer * Double(quality.weakHoles) / n * 4)) }
        factors.append(("cond", (course.condition - r.conditionFrom) / r.conditionRange * r.conditionWeight))
        factors.append(("club", Double(course.facilities.clubhouse) * r.clubhousePerLevel
            + Double(course.facilities.range) * r.range + Double(course.facilities.shop) * r.shopPerLevel))
        if course.weather == .rain || course.weather == .storm { factors.append(("rain", r.rain)) }
        let fair = localFairFee(course, plot: plot, quality: quality)
        if Double(course.fee) > fair { factors.append(("price", -(Double(course.fee) - fair) / (fair * r.overpricedRange) * r.overpricedWeight)) }
        if Double(course.fee) < fair * r.bargainBelow { factors.append(("cheap", r.bargain)) }

        var rating = r.base + (rng.unit() - 0.5) * r.randomSpread
        for (_, v) in factors { rating += v }
        rating = min(5, max(1, rating))
        let stars = Int((rating + 0.5).rounded(.down))

        let worst = factors.filter { $0.1 < 0 }.min { $0.1 < $1.1 }
        let best = factors.filter { $0.1 > 0 }.max { $0.1 < $1.1 }
        var key = rating < 3 && worst != nil ? worst!.0 : best?.0 ?? "meh"
        if key == "cond" && rating < 3 { key = "condN" }
        if key == "design" && rating < 3 { key = "designN" }

        let quote: String
        if key == "design", let signature = quality.design.signatureHole, rng.chance(r.signatureQuoteChance) {
            quote = signatureQuote(hole: signature, quality: quality, rng: &rng)
        } else {
            let options = data.reviewText.quotes[key] ?? data.reviewText.quotes["meh"] ?? ["Fine."]
            quote = rng.pick(options)
        }
        return Review(day: day, golfer: golfer.name, stars: stars, score: score, par: quality.par, quote: quote)
    }

    private func signatureQuote(hole: Int, quality: CourseQuality, rng: inout SeededRandom) -> String {
        let t = data.reviewText.signature
        let feature = quality.design.holes[hole].features.first { $0.points > 0 }
        var options = t.plain
        if feature != nil { options += t.withFeature }
        return rng.pick(options)
            .replacingOccurrences(of: "{hole}", with: Self.ordinal(hole + 1))
            .replacingOccurrences(of: "{feature}", with: feature?.name.lowercased() ?? "")
    }

    public static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    // MARK: Reputation

    public struct CeilingStep: Equatable, Sendable {
        public let cap: Double
        public let need: String
        public let met: Bool
    }

    /// The reputation ceilings in order, and whether each is met. A level only counts if every level below it is met.
    public func ceilingSteps(_ course: Course, quality: CourseQuality) -> [CeilingStep] {
        balance.reputation.ceilings.map { c in
            var met = true
            if let need = c.clubhouse, course.facilities.clubhouse < need { met = false }
            if let need = c.condition, course.condition < need { met = false }
            if let need = c.design, quality.design.score < need { met = false }
            if let event = c.hosted, course.eventsHosted[event] == nil { met = false }
            return CeilingStep(cap: c.cap, need: c.need, met: met)
        }
    }

    /// Highest reputation this course can reach right now (0 to 5). Nine holers stop at 4.0 (8 of 10).
    public func reputationCeiling(_ course: Course, quality: CourseQuality) -> Double {
        var cap = balance.reputation.ceilings.first?.cap ?? 3
        for step in ceilingSteps(course, quality: quality) {
            guard step.met else { break }
            cap = step.cap
        }
        if course.holes.count < 18 { cap = min(cap, balance.reputation.nineHoleCap) }
        return cap
    }

    /// The next ceiling and what it needs, for the Club tab.
    public func nextCeiling(_ course: Course, quality: CourseQuality) -> CeilingStep? {
        if course.holes.count < 18 && reputationCeiling(course, quality: quality) >= balance.reputation.nineHoleCap { return nil }
        return ceilingSteps(course, quality: quality).first { !$0.met }
    }
}
