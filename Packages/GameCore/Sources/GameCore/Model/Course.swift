public enum Weather: String, Codable, CaseIterable, Sendable {
    case sun, cloud, wind, rain, storm
}

public struct Facilities: Codable, Equatable, Sendable {
    /// 0 portacabin, 1 clubhouse, 2 with restaurant, 3 grand.
    public var clubhouse = 0
    /// 0 none, 1 pro shop, 2 flagship.
    public var shop = 0
    /// 0 none, 1 driving range.
    public var range = 0
    /// Greenkeepers: 1 skeleton crew, 2 full team, 3 championship team.
    public var staff = 1
    /// 0 none, 1 rock armour, 2 sea wall.
    public var seaDefence = 0

    public init() {}
}

/// One golfer's verdict after a round.
public struct Review: Codable, Equatable, Sendable {
    public let day: Int
    public let golfer: String
    public let stars: Int
    public let score: Int
    public let par: Int
    public let quote: String
}

/// Running totals for one course for one day.
public struct CourseDay: Codable, Equatable, Sendable {
    public var rounds = 0
    public var visitors = 0
    /// Groups who turned up while the tee was busy and went home.
    public var walkedAway = 0
    public var greenFees = 0
    public var barAndShop = 0
    public var upkeep = 0
    public var wages = 0
    public var starsTotal = 0
    public var reviews = 0

    public init() {}

    public var takings: Int { greenFees + barAndShop }
    public var costs: Int { upkeep + wages }
    public var net: Int { takings - costs }
    public var averageStars: Double? { reviews > 0 ? Double(starsTotal) / Double(reviews) : nil }
}

/// A course the player owns, on one plot.
public struct Course: Codable, Equatable, Sendable, Identifiable {
    public var id: String { plotID }
    public let plotID: String
    public var holes: [Hole]
    public var isOpen = false
    /// Green fee in pounds, set in £5 steps.
    public var fee = 10
    /// Stored 0 to 5; shown doubled, out of 10.
    public var reputation: Double
    /// 20 to 100 percent.
    public var condition: Double
    public var facilities = Facilities()
    public var weather: Weather = .cloud
    /// Newest first.
    public var reviews: [Review] = []
    public var today = CourseDay()
    public var yesterday: CourseDay?
    public var totalRounds = 0
    public var bestScore: Int?
    /// Minute the last group teed off today.
    public var lastTeeMinute: Int?
    /// Event ids hosted here, with the day they were held.
    public var eventsHosted: [String: Int] = [:]
    public var booking: EventBooking?
    public var boughtDay = 1

    public init(plotID: String, holes: [Hole], reputation: Double, condition: Double) {
        self.plotID = plotID
        self.holes = holes
        self.reputation = reputation
        self.condition = condition
    }

    /// Reputation as the player sees it, out of 10.
    public var reputationOutOfTen: Double { reputation * 2 }
}
