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

    public init(plotID: String, holes: [Hole], reputation: Double, condition: Double) {
        self.plotID = plotID
        self.holes = holes
        self.reputation = reputation
        self.condition = condition
    }

    /// Reputation as the player sees it, out of 10.
    public var reputationOutOfTen: Double { reputation * 2 }
}
