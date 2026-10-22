import Foundation

public enum LandKind: String, Codable, CaseIterable, Sendable {
    case links, heathland, parkland, moorland
}

public struct LandType: Decodable, Sendable, Identifiable {
    public let id: LandKind
    public let name: String
    public let description: String
    public let treeKind: String
    public let waterChancePerHole: Double
    public let canHostChampionship: Bool
    public let coastal: Bool
}

/// A fixed site: hand made plots and the legendary venues.
public struct Plot: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let area: String
    public let lat: Double
    public let lon: Double
    public let land: LandKind
    public let holes: Int
    public let wealth: Double
    public let demand: Double
    public let prestige: Double
    /// Set for the 25 legendary venues: their auction guide price.
    public let legendaryGuide: Int?
    /// Reserve plots come to market later in a career.
    public let reserve: Bool?

    public var isLegendary: Bool { legendaryGuide != nil }
    public var isReserve: Bool { reserve ?? false }
}

/// A rule about a plot, written as data in rivals.json.
public indirect enum PlotRule: Decodable, Sendable {
    case any([PlotRule])
    case all([PlotRule])
    case field(name: String, atLeast: Double?, atMost: Double?)

    private enum Keys: String, CodingKey { case any, all, field, atLeast, atMost }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if let rules = try c.decodeIfPresent([PlotRule].self, forKey: .any) {
            self = .any(rules)
        } else if let rules = try c.decodeIfPresent([PlotRule].self, forKey: .all) {
            self = .all(rules)
        } else {
            self = .field(
                name: try c.decode(String.self, forKey: .field),
                atLeast: try c.decodeIfPresent(Double.self, forKey: .atLeast),
                atMost: try c.decodeIfPresent(Double.self, forKey: .atMost)
            )
        }
    }

    /// `values` maps field names (wealth, prestige, latitude, holes, guide, isLinks) to numbers.
    public func matches(_ values: [String: Double]) -> Bool {
        switch self {
        case .any(let rules): return rules.contains { $0.matches(values) }
        case .all(let rules): return rules.allSatisfy { $0.matches(values) }
        case .field(let name, let atLeast, let atMost):
            guard let v = values[name] else { return false }
            if let atLeast, v < atLeast { return false }
            if let atMost, v > atMost { return false }
            return true
        }
    }
}

public struct Rival: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let shortName: String
    public let colour: String
    public let blurb: String
    public let startingCash: Int
    public let bidMultiplier: [Double]
    public let targetReputation: Double
    public let maxCourses: Int
    public let startingPlots: [String]
    public let wants: PlotRule
}

public struct Facility: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let levels: [String]
    public let costs: [Int]
    public let effect: String
    public let barMultiplier: [Double]?
    public let spendBonus: [Double]?
    public let linksOnly: Bool?
}

public struct EventRequirement: Decodable, Sendable {
    public enum Kind: String, Decodable, Sendable {
        case finished, reputation, condition, holes, clubhouse, shop, range
        case design, yards, links, prestige, members, hostedHere
    }
    public let kind: Kind
    public let value: Double?
    public let event: String?
}

public struct GameEventSpec: Decodable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let blurb: String
    public let pay: Int
    public let payScalesWithCourse: Bool?
    public let reputation: Double
    public let cooldownDays: Int
    public let onRota: Bool?
    public let requirements: [EventRequirement]
}

public struct Challenge: Decodable, Sendable, Identifiable {
    public struct StartCourse: Decodable, Sendable {
        public let plot: String
        public let longLayout: Bool?
        public let reputation: Double
        public let condition: Double
        public let clubhouse: Int?
        public let shop: Int?
        public let range: Int?
        public let staff: Int?
        public let hostedDaysAgo: [String: Int]?
    }
    public struct RivalCourse: Decodable, Sendable {
        public let plot: String
        public let rival: String
        public let reputation: Double
    }
    public struct Start: Decodable, Sendable {
        public let cash: Int
        public let stormMultiplier: Double?
        public let courses: [StartCourse]
        public let rivalCourses: [RivalCourse]?
        public let rivalCash: [String: Int]?
        public let rivalTargetReputation: [String: Double]?
    }
    public struct Goal: Decodable, Sendable {
        public let kind: String
        public let plot: String?
        public let reputation: Double?
        public let cash: Int?
        public let waitingList: Int?
        public let southOfLatitude: Double?
        public let daysRunning: Int?
        public let event: String?
    }

    public let id: String
    public let name: String
    public let difficulty: String
    public let days: Int
    /// Challenges start on a fixed date so the season is the same for everyone.
    public let startMonth: Int
    public let startDay: Int
    public let blurb: String
    public let goalText: String
    public let start: Start
    public let goal: Goal
}

public struct Town: Decodable, Sendable {
    public let town: String
    public let county: String
    public let lat: Double
    public let lon: Double
    public let lands: [LandKind]
    public let wealth: Double
    public let demand: Double
}

public struct SiteNameWords: Decodable, Sendable {
    public let first: [String]
    public let second: [String]
}

public struct GolferNames: Decodable, Sendable {
    public let first: [String]
    public let last: [String]
}

public struct PercyText: Decodable, Sendable {
    /// Shot by shot and weather lines, keyed by category (arrive, fairway, bunker...).
    public let lines: [String: [String]]
    /// Quips for the weekly Gazette.
    public let column: [String]
}

public struct ReviewText: Decodable, Sendable {
    public struct Signature: Decodable, Sendable {
        public let withFeature: [String]
        public let plain: [String]
    }
    /// Quotes keyed by the factor that mattered most (design, price, condN...).
    public let quotes: [String: [String]]
    public let signature: Signature
}
