import Foundation

/// All read only game data, loaded once from the JSON files in Resources/Data.
public struct GameData: Sendable {
    public let balance: Balance
    public let landTypes: [LandKind: LandType]
    public let plots: [String: Plot]
    /// Plot ids in file order, so lists are stable.
    public let plotOrder: [String]
    public let rivals: [Rival]
    public let facilities: [Facility]
    public let events: [GameEventSpec]
    public let challenges: [Challenge]
    public let towns: [Town]
    public let siteNames: [LandKind: SiteNameWords]
    public let golferNames: GolferNames
    public let percy: PercyText
    public let reviewText: ReviewText
    public let map: MapData
    public let milestones: [Milestone]

    public enum LoadError: Error, CustomStringConvertible {
        case missingFile(String)
        case badFile(String, Error)

        public var description: String {
            switch self {
            case .missingFile(let name): "Game data file \(name).json is missing from the bundle"
            case .badFile(let name, let error): "Game data file \(name).json could not be read: \(error)"
            }
        }
    }

    /// The data shipped inside the GameCore package.
    public static let bundled: GameData = {
        do {
            return try GameData.load()
        } catch {
            fatalError("\(error)")
        }
    }()

    public static func load(from bundle: Bundle? = nil) throws -> GameData {
        let bundle = bundle ?? .module
        func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Data") else {
                throw LoadError.missingFile(name)
            }
            do {
                return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
            } catch {
                throw LoadError.badFile(name, error)
            }
        }

        let plotList = try read("plots", as: [Plot].self)
        let siteNames = try read("site_names", as: [String: SiteNameWords].self)
        return GameData(
            balance: try read("balance", as: Balance.self),
            landTypes: Dictionary(uniqueKeysWithValues: try read("land_types", as: [LandType].self).map { ($0.id, $0) }),
            plots: Dictionary(uniqueKeysWithValues: plotList.map { ($0.id, $0) }),
            plotOrder: plotList.map(\.id),
            rivals: try read("rivals", as: [Rival].self),
            facilities: try read("facilities", as: [Facility].self),
            events: try read("events", as: [GameEventSpec].self),
            challenges: try read("challenges", as: [Challenge].self),
            towns: try read("towns", as: [Town].self),
            siteNames: Dictionary(uniqueKeysWithValues: siteNames.compactMap { key, value in
                LandKind(rawValue: key).map { ($0, value) }
            }),
            golferNames: try read("golfer_names", as: GolferNames.self),
            percy: try read("percy", as: PercyText.self),
            reviewText: try read("reviews", as: ReviewText.self),
            map: try read("map", as: MapData.self),
            milestones: try read("milestones", as: [Milestone].self)
        )
    }

    public func plot(_ id: String) -> Plot? { plots[id] }

    /// Base land price: holes base × wealth^1.8 × (0.6 + prestige × 0.4), rounded to £5k.
    /// Legendary venues use their guide instead.
    public func basePrice(of plot: Plot) -> Int {
        if let guide = plot.legendaryGuide { return guide }
        let p = balance.plotPrice
        let base = plot.holes == 18 ? p.base18 : p.base9
        let raw = base * pow(plot.wealth, p.wealthExponent) * (p.prestigeBase + plot.prestige * p.prestigeFactor)
        return Int((raw / p.roundTo).rounded() * p.roundTo)
    }

    public func standardPars(holes: Int) -> [Int] {
        holes == 18 ? balance.par.standardPars18 : Array(balance.par.standardPars9.prefix(holes))
    }
}
