/// How a plot is being sold.
public enum SaleKind: String, Codable, Sendable {
    /// Buy it outright at the asking price.
    case quiet
    /// One offer each, opened on the closing day. Highest over the reserve wins.
    case sealed
}

/// A plot on the market.
public struct Listing: Codable, Equatable, Sendable, Identifiable {
    public var id: String { plotID }
    public let plotID: String
    public var kind: SaleKind
    /// The guide price (sealed) or asking price before any discount (quiet).
    public var guide: Int
    /// Sold by administrators or a rival: a built course, a bit tired.
    public let builtCourse: Bool
    public let listedDay: Int
    /// Sealed bids: offers are opened at the start of the day after this one.
    public var closesDay: Int?
    /// Quiet sales are withdrawn if nobody buys by this day.
    public var expiresDay: Int?
    /// 0.88 after failing at sealed bids.
    public var discount: Double = 1
    /// The player's sealed offer, changeable until close.
    public var myOffer: Int?
    /// Rivals who will actually bid (hidden from the player).
    public var interested: [String] = []
    /// Rivals the gossip says are interested (sometimes wrong).
    public var rumoured: [String] = []
    /// It has been on the market before.
    public var backOnMarket = false
    public var reduced: Bool { discount < 1 }

    /// What you pay for a quiet sale.
    public var askingPrice: Int { Int((Double(guide) * discount / 1000).rounded()) * 1000 }
}

public struct MarketState: Codable, Equatable, Sendable {
    public var listings: [String: Listing] = [:]
    /// Each plot's price drifts a little day to day.
    public var priceMultiplier: [String: Double] = [:]
    /// Withdrawn plots can't come back before this day.
    public var coolOff: [String: Int] = [:]
    public var nextListingDay = 3
    public var nextAdministrationDay = 12
    /// Plots that have been listed at some point, for "Back on the market".
    public var everListed: Set<String> = []

    public init() {}
}

public struct RivalState: Codable, Equatable, Sendable {
    public var cash: Int
    /// Overrides the rival's usual target reputation (challenges).
    public var targetReputation: Double?
}

/// A course owned by a rival company.
public struct RivalCourse: Codable, Equatable, Sendable {
    public let plotID: String
    public let owner: String
    public var reputation: Double
    public let sinceDay: Int
}

public struct NewsItem: Codable, Equatable, Sendable {
    public let day: Int
    public let text: String
}

/// A letter to the player: auction results, milestones, event reports.
public struct Letter: Codable, Equatable, Sendable, Identifiable {
    public var id: String { "\(day)-\(title)" }
    public let day: Int
    public let from: String
    public let title: String
    public let body: String
    public var read = false
}

/// An event booked at a course: the course closes to the public that day.
public struct EventBooking: Codable, Equatable, Sendable {
    public let eventID: String
    public let day: Int
}
