import Foundation

public enum MarketResult: Equatable, Sendable {
    case done
    case notEnoughCash(needed: Int)
    case notForSale
    case offerTooLow(minimum: Int)
}

extension GameEngine {
    // MARK: A new career

    /// £200,000, no land, a market of 14 plots and three rivals.
    public static func newCareer(seed: UInt64, startDate: String, data: GameData = .bundled) -> GameEngine {
        let state = GameState(mode: .career, seed: seed, startDate: startDate,
                              cash: data.balance.career.startingCash, dayStartMinute: data.balance.clock.dayStartMinute)
        var engine = GameEngine(data: data, state: state)
        engine.setUpWorld()
        return engine
    }

    mutating func setUpWorld() {
        for rival in data.rivals {
            state.rivals[rival.id] = RivalState(cash: rival.startingCash)
            for plot in rival.startingPlots where state.courses[plot] == nil {
                state.rivalCourses[plot] = RivalCourse(plotID: plot, owner: rival.id,
                                                       reputation: rival.targetReputation - 0.4 + state.rng.unit() * 0.3, sinceDay: 0)
            }
        }
        let pool = data.plotOrder.compactMap { data.plot($0) }.filter { isFree($0) && !$0.isReserve }
        for plot in state.rng.shuffled(pool).prefix(data.balance.market.initialListings) {
            list(plot.id, builtCourse: false, closesIn: state.rng.int(4...18))
        }
        ensureStarterSales()
        state.market.nextListingDay = state.day + state.rng.int(data.balance.market.newListingEveryDays)
        state.market.nextAdministrationDay = state.day + state.rng.int(data.balance.market.administrationEveryDays)
        post("Land for sale across Britain. Cheap up north, eye watering down south.")
    }

    /// Two cheap plots you can simply buy, so a new career never starts stuck.
    mutating func ensureStarterSales() {
        let m = data.balance.market
        let quiet = state.market.listings.values.filter { $0.kind == .quiet }.count
        guard quiet < m.starterQuietSales else { return }
        let cheap = data.plotOrder.compactMap { data.plot($0) }
            .filter { isFree($0) && $0.prestige < m.quietMaxPrestige && price($0.id) < m.quietMaxGuide }
            .sorted { price($0.id) < price($1.id) }
        for plot in cheap.prefix(m.starterQuietSales - quiet) { list(plot.id, builtCourse: false) }
    }

    // MARK: Prices

    /// Today's price for a plot: its base price drifting a little day to day.
    public func price(_ plotID: String) -> Int {
        guard let plot = data.plot(plotID) else { return 0 }
        let mult = state.market.priceMultiplier[plotID] ?? 1
        return Int((Double(data.basePrice(of: plot)) * mult / data.balance.market.roundTo).rounded() * data.balance.market.roundTo)
    }

    func administrationPrice(_ plotID: String) -> Int {
        guard let plot = data.plot(plotID) else { return 0 }
        let m = data.balance.market
        return Int(((Double(price(plotID)) * m.administrationPriceFactor + Double(plot.holes) * m.administrationPerHole) / m.roundTo).rounded() * m.roundTo)
    }

    /// Not owned by anyone and not already on the market.
    func isFree(_ plot: Plot) -> Bool {
        !plot.isLegendary && state.courses[plot.id] == nil && state.rivalCourses[plot.id] == nil && state.market.listings[plot.id] == nil
    }

    func plotFacts(_ plot: Plot, guide: Int) -> [String: Double] {
        ["wealth": plot.wealth, "prestige": plot.prestige, "latitude": plot.lat, "holes": Double(plot.holes),
         "guide": Double(guide), "isLinks": plot.land == .links ? 1 : 0]
    }

    public func rivalCount(_ rivalID: String) -> Int {
        state.rivalCourses.values.filter { $0.owner == rivalID }.count
    }

    // MARK: Listing

    @discardableResult
    mutating func list(_ plotID: String, builtCourse: Bool, closesIn: Int? = nil) -> Listing? {
        guard let plot = data.plot(plotID) else { return nil }
        let m = data.balance.market
        let guide = builtCourse ? administrationPrice(plotID) : price(plotID)
        let kind: SaleKind = !builtCourse && guide < m.quietMaxGuide && plot.prestige < m.quietMaxPrestige ? .quiet : .sealed
        var listing = Listing(plotID: plotID, kind: kind, guide: guide, builtCourse: builtCourse, listedDay: state.day)
        listing.backOnMarket = state.market.everListed.contains(plotID)
        if kind == .sealed {
            listing.closesDay = state.day + (closesIn ?? state.rng.int(m.sealedCloseDays))
            for rival in data.rivals {
                let wants = rivalCount(rival.id) < rival.maxCourses && rival.wants.matches(plotFacts(plot, guide: guide))
                    && state.rng.chance(data.balance.rivals.interestChance)
                if wants { listing.interested.append(rival.id) }
                if wants != state.rng.chance(data.balance.rivals.rumourNoise) { listing.rumoured.append(rival.id) }
            }
        } else {
            listing.expiresDay = state.day + state.rng.int(m.quietExpiresDays)
        }
        state.market.listings[plotID] = listing
        state.market.everListed.insert(plotID)
        return listing
    }

    /// One line for the news ticker about a listing.
    func headline(_ l: Listing) -> String {
        guard let plot = data.plot(l.plotID) else { return "" }
        let who = l.rumoured.compactMap { id in data.rivals.first { $0.id == id }?.shortName }
        let rumour = who.isEmpty ? "" : " \(who.joined(separator: " and ")) said to be interested."
        switch l.kind {
        case .quiet: return "For sale: \(plot.name), \(plot.area). Asking \(Self.money(l.askingPrice)).\(rumour)"
        case .sealed: return "Sealed bids invited: \(plot.name), \(plot.area). Guide \(Self.money(l.guide)).\(rumour)"
        }
    }

    // MARK: The market each morning

    mutating func marketDay() {
        let m = data.balance.market
        // Prices drift.
        for id in data.plotOrder where state.courses[id] == nil && state.rivalCourses[id] == nil {
            let current = state.market.priceMultiplier[id] ?? 1
            state.market.priceMultiplier[id] = min(m.priceMultiplierMax, max(m.priceMultiplierMin, current * (1 + state.rng.gauss() * m.priceDrift)))
        }
        // Sealed bids that closed yesterday are opened.
        for id in state.market.listings.keys.sorted() {
            if let l = state.market.listings[id], l.kind == .sealed, let closes = l.closesDay, closes < state.day { resolveSale(id) }
        }
        // Quiet sales nobody bought are withdrawn.
        for id in state.market.listings.keys.sorted() {
            guard let l = state.market.listings[id], l.kind == .quiet, let expires = l.expiresDay, state.day >= expires else { continue }
            state.market.listings[id] = nil
            state.market.coolOff[id] = state.day + state.rng.int(m.coolOffDays)
            post(state.rng.pick(["Withdrawn: \(name(id)). The owners have had second thoughts.",
                                 "No longer for sale: \(name(id)). The family are keeping it, for now.",
                                 "Off the market: \(name(id)). Planning trouble, apparently."]))
        }
        // New land comes up.
        if state.day >= state.market.nextListingDay {
            for _ in 0..<(state.rng.chance(m.secondListingChance) ? 2 : 1) {
                let pool = data.plotOrder.compactMap { data.plot($0) }
                    .filter { isFree($0) && (state.market.coolOff[$0.id] ?? 0) <= state.day }
                guard !pool.isEmpty else { break }
                let plot = state.rng.pick(pool)
                state.market.priceMultiplier[plot.id] = state.rng.double(m.newListingMultiplier)
                if let l = list(plot.id, builtCourse: false) {
                    post((l.backOnMarket ? "Back on the market. " : "New to market. ") + headline(l))
                }
            }
            state.market.nextListingDay = state.day + state.rng.int(m.newListingEveryDays)
        }
        // A club goes into administration now and then.
        if state.day >= state.market.nextAdministrationDay {
            let pool = data.plotOrder.compactMap { data.plot($0) }.filter { isFree($0) && (state.market.coolOff[$0.id] ?? 0) <= state.day }
            if !pool.isEmpty, let l = list(state.rng.pick(pool).id, builtCourse: true, closesIn: m.administrationCloseDays) {
                post("\(name(l.plotID)) golf club goes into administration. " + headline(l))
            }
            state.market.nextAdministrationDay = state.day + state.rng.int(m.administrationEveryDays)
        }
        // Sealed lots occasionally vanish in a private deal.
        for id in state.market.listings.keys.sorted() {
            guard let l = state.market.listings[id], l.kind == .sealed, l.myOffer == nil, !l.builtCourse,
                  let closes = l.closesDay, closes - state.day > 1, state.rng.chance(m.privateDealChance) else { continue }
            state.market.listings[id] = nil
            state.market.coolOff[id] = state.day + state.rng.int([10, 25])
            post("Withdrawn before bids closed: \(name(id)). A private deal, they say.")
        }
        ensureStarterSales()
    }

    /// Opens the sealed bids on a lot.
    mutating func resolveSale(_ id: String) {
        guard let l = state.market.listings[id] else { return }
        let r = data.balance.rivals, m = data.balance.market
        var bids: [(who: String, amount: Int)] = []
        for rivalID in l.interested {
            guard let rival = data.rivals.first(where: { $0.id == rivalID }), rivalCount(rivalID) < rival.maxCourses else { continue }
            let range = rival.bidMultiplier
            var bid = Int((Double(l.guide) * state.rng.double(range) / 1000).rounded()) * 1000
            bid = min(bid, (state.rivals[rivalID]?.cash ?? 0) / 1000 * 1000)
            if Double(bid) >= Double(l.guide) * r.minimumBidShareOfGuide { bids.append((rivalID, bid)) }
        }
        var note = ""
        if let offer = l.myOffer {
            if state.cash >= offer { bids.append(("you", offer)) } else { note = "Your offer of \(Self.money(offer)) was ruled out: you didn't have the cash on closing day. " }
        }
        bids.sort { $0.amount != $1.amount ? $0.amount > $1.amount : $0.who == "you" }
        let reserve = Int((Double(l.guide) * m.reserveShare / 1000).rounded()) * 1000
        state.market.listings[id] = nil
        let table = bids.isEmpty ? "No bids came in." : "Bids: " + bids.map { "\(displayName($0.who)) \(Self.money($0.amount))" }.joined(separator: ", ") + ". Reserve \(Self.money(reserve))."

        guard let top = bids.first, top.amount >= reserve else {
            // Failed: back as a quiet sale at a discount.
            var relisted = Listing(plotID: id, kind: .quiet, guide: l.guide, builtCourse: l.builtCourse, listedDay: state.day)
            relisted.discount = m.failedSaleDiscount
            relisted.expiresDay = state.day + state.rng.int(m.quietExpiresDays)
            relisted.backOnMarket = true
            state.market.listings[id] = relisted
            post("\(name(id)) fails to sell. Now available at \(Self.money(relisted.askingPrice)) to anyone who wants it.")
            if l.myOffer != nil {
                write(from: "Auction house", title: "Result: \(name(id))",
                      body: "\(name(id)) did not sell; the reserve was not met. \(note)\(table) It's now for sale outright at \(Self.money(relisted.askingPrice)).")
            }
            return
        }
        if top.who == "you" {
            spend(.landBought, top.amount)
            acquire(id, builtCourse: l.builtCourse)
            post("\(name(id)) sold to a new owner for \(Self.money(top.amount)). Rumours of big plans.")
            let margin = top.amount - (bids.count > 1 ? bids[1].amount : reserve)
            write(from: "Auction house", title: "You won \(name(id))",
                  body: "Congratulations. \(name(id)) is yours for \(Self.money(top.amount)). "
                    + (Double(margin) > Double(l.guide) * 0.15 ? "You left \(Self.money(margin)) on the table over the next best offer. Ouch. " : "Nicely judged. ")
                    + table)
        } else {
            state.rivals[top.who]?.cash -= top.amount
            let rep = l.builtCourse ? r.administrationCourseReputation : r.newCourseReputation
            state.rivalCourses[id] = RivalCourse(plotID: id, owner: top.who, reputation: rep, sinceDay: state.day)
            post("\(name(id)) goes to \(displayName(top.who)) for \(Self.money(top.amount)).")
            if l.myOffer != nil {
                write(from: "Auction house", title: "Outbid on \(name(id))", body: "\(displayName(top.who)) won \(name(id)) with \(Self.money(top.amount)). \(note)\(table)")
            }
        }
    }

    // MARK: Player commands

    /// Buys a quiet sale outright.
    @discardableResult
    public mutating func buyNow(_ plotID: String) -> MarketResult {
        guard let l = state.market.listings[plotID], l.kind == .quiet else { return .notForSale }
        let cost = l.askingPrice
        guard state.cash >= cost else { return .notEnoughCash(needed: cost) }
        spend(.landBought, cost)
        state.market.listings[plotID] = nil
        acquire(plotID, builtCourse: l.builtCourse)
        post(l.builtCourse ? "\(name(plotID)) rescued by a new owner." : "\(name(plotID)) sold. Rumours of a new golf course.")
        return .done
    }

    /// Puts in (or changes) a sealed offer. You need the cash on closing day, not now.
    @discardableResult
    public mutating func placeOffer(_ plotID: String, amount: Int) -> MarketResult {
        guard var l = state.market.listings[plotID], l.kind == .sealed else { return .notForSale }
        let minimum = minimumOffer(l)
        guard amount >= minimum else { return .offerTooLow(minimum: minimum) }
        l.myOffer = amount
        state.market.listings[plotID] = l
        return .done
    }

    public mutating func withdrawOffer(_ plotID: String) {
        state.market.listings[plotID]?.myOffer = nil
    }

    public func minimumOffer(_ l: Listing) -> Int {
        Int((Double(l.guide) * data.balance.market.minimumOfferShare / 1000).rounded()) * 1000
    }

    public mutating func toggleFavourite(_ plotID: String) {
        if state.favourites.contains(plotID) { state.favourites.remove(plotID) } else { state.favourites.insert(plotID) }
    }

    /// Takes ownership. Bare land must be designed; a course bought from administrators comes laid out and a bit tired.
    mutating func acquire(_ plotID: String, builtCourse: Bool) {
        guard let plot = data.plot(plotID), state.courses[plotID] == nil else { return }
        let generator = self.generator
        var holes: [Hole] = []
        for par in data.standardPars(holes: plot.holes) {
            let land = generator.baseLand(plot.land, rng: &state.rng)
            holes.append(builtCourse ? generator.autoLayout(par: par, land: plot.land, on: land, rng: &state.rng) : land)
        }
        let a = data.balance.administration
        var course = Course(plotID: plotID, holes: holes,
                            reputation: builtCourse ? a.reputation : data.balance.course.startReputation,
                            condition: builtCourse ? a.condition : data.balance.course.startCondition)
        if builtCourse { course.facilities.clubhouse = a.clubhouse }
        course.boughtDay = state.day
        course.weather = rollWeather(for: plot, day: state.day)
        state.courses[plotID] = course
        state.courseOrder.append(plotID)
        state.market.listings[plotID] = nil
        state.favourites.remove(plotID)
        let fee = suggestedFee(plotID)
        state.courses[plotID]?.fee = fee
        checkMilestones()
    }

    // MARK: News and letters

    mutating func post(_ text: String) {
        state.news.insert(NewsItem(day: state.day, text: text), at: 0)
        if state.news.count > 60 { state.news.removeLast(state.news.count - 60) }
    }

    mutating func write(from: String, title: String, body: String) {
        state.letters.insert(Letter(day: state.day, from: from, title: title, body: body), at: 0)
        if state.letters.count > 40 { state.letters.removeLast(state.letters.count - 40) }
    }

    public mutating func markLettersRead() {
        for i in state.letters.indices { state.letters[i].read = true }
    }

    func name(_ plotID: String) -> String { data.plot(plotID)?.name ?? plotID }

    func displayName(_ who: String) -> String {
        who == "you" ? "You" : data.rivals.first { $0.id == who }?.name ?? who
    }

    static func money(_ pounds: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return "£" + (f.string(from: NSNumber(value: pounds)) ?? "\(pounds)")
    }
}
