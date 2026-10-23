import XCTest
@testable import GameCore

final class CareerTests: XCTestCase {
    private func career(_ seed: UInt64 = 3) -> GameEngine {
        GameEngine.newCareer(seed: seed, startDate: "2027-04-05")
    }

    /// A simple player: buy the cheapest land going, lay it out, open it, keep the fee fair.
    private func playBot(_ g: inout GameEngine, days: Int) {
        for _ in 0..<days {
            if g.state.courses.isEmpty,
               let cheapest = g.state.market.listings.values.filter({ $0.kind == .quiet }).min(by: { $0.askingPrice < $1.askingPrice }),
               g.buyNow(cheapest.plotID) == .done {
                for i in 0..<g.course(cheapest.plotID)!.holes.count { g.relayHole(courseID: cheapest.plotID, hole: i) }
                g.setFee(courseID: cheapest.plotID, g.suggestedFee(cheapest.plotID))
                g.setOpen(cheapest.plotID, true)
            }
            g.simulateDays(1)
        }
    }

    func testNewCareerSetsUpTheWorld() {
        let g = career()
        XCTAssertEqual(g.state.cash, 200_000)
        XCTAssertTrue(g.state.courses.isEmpty)
        XCTAssertGreaterThanOrEqual(g.state.market.listings.count, 14)
        XCTAssertGreaterThanOrEqual(g.state.market.listings.values.filter { $0.kind == .quiet }.count, 2, "two starter sales")
        XCTAssertEqual(g.state.rivals.count, 3)
        XCTAssertEqual(Set(g.state.rivalCourses.keys), ["harpenden", "irvine", "peak", "sutton"])
        for l in g.state.market.listings.values where l.kind == .sealed { XCTAssertNotNil(l.closesDay) }
        XCTAssertTrue(g.state.market.listings.values.allSatisfy { !(g.data.plot($0.plotID)!.isLegendary) })
    }

    func testAHundredAndTwentyDaysOfCareer() {
        var g = career()
        playBot(&g, days: 120)
        let s = g.state
        XCTAssertEqual(s.courses.count, 1, "the bot bought and ran a course")
        XCTAssertTrue(s.milestones.contains("bought") && s.milestones.contains("opened"))
        XCTAssertGreaterThan(s.rivalCourses.count, 4, "rivals bought land")
        XCTAssertGreaterThan(s.news.count, 20)
        XCTAssertFalse(s.market.listings.isEmpty, "the market keeps moving")
        // Books balance across land, building and golf.
        let income = s.lifetime.filter { $0.key.isIncome }.values.reduce(0, +)
        let spending = s.lifetime.filter { !$0.key.isIncome }.values.reduce(0, +)
        XCTAssertEqual(s.openingCash + income - spending, s.cash)
        for rival in s.rivals.values { XCTAssertGreaterThanOrEqual(rival.cash, 0) }
        print("\nCAREER BOT after 120 days: cash \(s.cash), rivals own \(s.rivalCourses.count), listings \(s.market.listings.count), milestones \(s.milestones.sorted())")
    }

    func testCareerReplaysExactly() {
        var a = career(9), b = career(9)
        playBot(&a, days: 40)
        playBot(&b, days: 40)
        XCTAssertEqual(a.state, b.state)
    }

    func testWinningASealedBid() {
        var g = career()
        guard let lot = g.state.market.listings.values.filter({ $0.kind == .sealed && $0.guide < 150_000 }).min(by: { $0.closesDay! < $1.closesDay! }) else {
            return XCTFail("no affordable sealed lot")
        }
        XCTAssertEqual(g.placeOffer(lot.plotID, amount: 1000), .offerTooLow(minimum: g.minimumOffer(lot)))
        XCTAssertEqual(g.placeOffer(lot.plotID, amount: min(g.state.cash, lot.guide * 2)), .done)
        while g.state.day <= lot.closesDay! { g.simulateDays(1) }
        XCTAssertNotNil(g.course(lot.plotID), "a big offer wins")
        XCTAssertTrue(g.state.letters.contains { $0.title.hasPrefix("You won") })
        XCTAssertGreaterThan(g.state.lifetime[.landBought, default: 0], 0)
    }

    func testOfferWithoutTheCashIsRuledOut() {
        var g = career()
        guard let lot = g.state.market.listings.values.filter({ $0.kind == .sealed }).min(by: { $0.closesDay! < $1.closesDay! }) else { return XCTFail() }
        g.placeOffer(lot.plotID, amount: lot.guide * 3)
        g.spend(.landBought, g.state.cash)
        while g.state.day <= lot.closesDay! { g.simulateDays(1) }
        XCTAssertNil(g.course(lot.plotID))
    }

    func testBuyingAQuietSaleGivesBareLand() {
        var g = career()
        let lot = g.state.market.listings.values.first { $0.kind == .quiet }!
        let cash = g.state.cash
        XCTAssertEqual(g.buyNow(lot.plotID), .done)
        XCTAssertEqual(g.state.cash, cash - lot.askingPrice)
        XCTAssertNotNil(g.openingProblem(lot.plotID), "bare land has to be designed before it opens")
        XCTAssertNil(g.state.market.listings[lot.plotID])
    }

    func testEventsBookCloseAndPay() {
        var g = career()
        let lot = g.state.market.listings.values.first { $0.kind == .quiet }!
        g.buyNow(lot.plotID)
        let id = lot.plotID
        g.state.cash = 5_000_000
        for i in 0..<g.course(id)!.holes.count { g.relayHole(courseID: id, hole: i, signature: true) }
        g.setOpen(id, true)
        g.state.courses[id]!.reputation = 3.0
        let status = g.eventStatus(courseID: id, eventID: "society")!
        XCTAssertTrue(status.canBook, "\(status.requirements)")
        XCTAssertTrue(g.bookEvent(courseID: id, eventID: "society"))
        XCTAssertFalse(g.eventStatus(courseID: id, eventID: "society")!.canBook, "already booked")
        g.simulateDays(1)
        XCTAssertGreaterThan(g.course(id)!.yesterday?.rounds ?? 0, 0, "open as normal the day it was booked")
        g.simulateDays(1)
        XCTAssertEqual(g.course(id)!.yesterday?.rounds, 0, "closed to the public on event day")
        XCTAssertNotNil(g.course(id)!.eventsHosted["society"])
        XCTAssertGreaterThan(g.state.lifetime[.tournaments, default: 0], 0)
        XCTAssertEqual(g.eventStatus(courseID: id, eventID: "society")!.waitDays, 4, "five day cooldown")

        let champ = g.eventStatus(courseID: id, eventID: "champ")!
        XCTAssertFalse(champ.canBook)
        XCTAssertFalse(champ.requirements.contains { $0.text.contains("member") }, "members come in a later update")
    }

    func testRivalsNearbyTakeGolfers() {
        var g = career()
        g.state.rivalCourses = [:]
        XCTAssertEqual(g.competition(for: "tatton"), 1)
        g.state.rivalCourses["sutton"] = RivalCourse(plotID: "sutton", owner: "granite", reputation: 4, sinceDay: 0)
        g.state.rivalCourses["chester"] = RivalCourse(plotID: "chester", owner: "hollingworth", reputation: 4, sinceDay: 0)
        let f = g.competition(for: "tatton")
        XCTAssertLessThan(f, 1)
        XCTAssertGreaterThan(f, 0.6)
        XCTAssertEqual(g.competition(for: "embo"), 1, "nothing near Dornoch")
    }

    func testVersionOneSavesStillLoad() throws {
        var g = GameEngine.newSandbox(plotID: "derwent", seed: 1, startDate: "2026-10-04")
        g.simulateDays(2)
        let v2 = try SaveFile.encode(g.state)
        var json = try JSONSerialization.jsonObject(with: v2) as! [String: Any]
        var state = json["state"] as! [String: Any]
        for key in ["market", "rivals", "rivalCourses", "news", "letters", "milestones", "favourites", "championshipOpensDay"] { state[key] = nil }
        var courses = state["courses"] as! [String: Any]
        var course = courses["derwent"] as! [String: Any]
        course["boughtDay"] = nil
        courses["derwent"] = course
        state["courses"] = courses
        json["state"] = state
        json["version"] = 1
        let v1 = try JSONSerialization.data(withJSONObject: json)
        let loaded = try SaveFile.decode(v1)
        XCTAssertEqual(loaded.courses["derwent"]?.holes, g.state.courses["derwent"]?.holes)
        XCTAssertTrue(loaded.market.listings.isEmpty)
    }
}
