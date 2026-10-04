import XCTest
@testable import GameCore

final class DataTests: XCTestCase {
    func testEverythingLoads() {
        XCTAssertEqual(data.plots.count, 91)
        XCTAssertEqual(data.plots.values.filter(\.isLegendary).count, 25)
        XCTAssertEqual(data.landTypes.count, 4)
        XCTAssertEqual(data.rivals.count, 3)
        XCTAssertEqual(data.events.map(\.id), ["society", "county", "regional", "champ"])
        XCTAssertEqual(data.challenges.count, 5)
        XCTAssertGreaterThan(data.towns.count, 90)
        XCTAssertEqual(data.siteNames.count, 4)
        XCTAssertFalse(data.percy.lines["bunker", default: []].isEmpty)
        XCTAssertFalse(data.percy.column.isEmpty)
    }

    /// Prices from the table in DESIGN.md section 4.
    func testLandPricesMatchTheDesignDoc() {
        let expected = ["embo": 70000, "lossie": 35000, "tatton": 265000, "chobham": 420000,
                        "norwood": 170000, "pegwell": 300000, "seascale": 30000, "camel": 115000]
        for (id, price) in expected {
            XCTAssertEqual(data.basePrice(of: data.plot(id)!), price, id)
        }
        XCTAssertEqual(data.basePrice(of: data.plot("oldgrey")!), 6_000_000)
    }

    func testRivalAppetites() {
        func values(_ id: String) -> [String: Double] {
            let p = data.plot(id)!
            return ["wealth": p.wealth, "prestige": p.prestige, "latitude": p.lat, "holes": Double(p.holes),
                    "guide": Double(data.basePrice(of: p)), "isLinks": p.land == .links ? 1 : 0]
        }
        let rival = Dictionary(uniqueKeysWithValues: data.rivals.map { ($0.id, $0) })
        XCTAssertTrue(rival["meridian"]!.wants.matches(values("chobham")))
        XCTAssertFalse(rival["meridian"]!.wants.matches(values("tummel")))
        XCTAssertTrue(rival["hollingworth"]!.wants.matches(values("embo")))
        XCTAssertTrue(rival["hollingworth"]!.wants.matches(values("pegwell")), "championship links in the south")
        XCTAssertTrue(rival["granite"]!.wants.matches(values("tummel")))
        XCTAssertFalse(rival["granite"]!.wants.matches(values("chobham")))
    }

    func testChallengesStartOnFixedDates() {
        for c in data.challenges {
            XCTAssertTrue((1...12).contains(c.startMonth), c.id)
            XCTAssertTrue((1...28).contains(c.startDay), c.id)
            for course in c.start.courses { XCTAssertNotNil(data.plot(course.plot), c.id) }
        }
    }

    func testNoRealVenueNamesInPlayerFacingData() {
        let banned = ["St Andrews Links", "Old Course", "Wentworth", "Sunningdale Golf", "Gleneagles", "Turnberry", "Muirfield",
                      "Birkdale", "Carnoustie Golf", "Royal St George", "St Enodoc", "Swinley", "Royal Lytham", "Ganton Golf",
                      "St George's Hill", "Royal Cinque", "Walton Heath", "Royal Liverpool", "Woodhall Spa Golf",
                      "Royal West Norfolk", "Formby Golf", "Notts Golf", "Royal Dornoch", "Royal Troon", "Kingsbarns",
                      "Royal Aberdeen", "The Open", "R&A"]
        let names = data.plots.values.map(\.name)
        for name in names {
            for real in banned { XCTAssertFalse(name.localizedCaseInsensitiveContains(real), "\(name) contains \(real)") }
        }
    }
}
