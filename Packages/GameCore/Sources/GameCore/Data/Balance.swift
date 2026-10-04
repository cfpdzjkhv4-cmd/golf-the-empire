/// Every tunable number in the game, loaded from `balance.json`.
/// Tuning means editing that file, never hunting through code.
public struct Balance: Decodable, Sendable {
    public struct Grid: Decodable, Sendable {
        public let columns: Int
        public let rows: Int
        public let yardsPerTile: Double
        public let teeRow: Int
    }

    public struct Par: Decodable, Sendable {
        public let par3MaxYards: Double
        public let par4MaxYards: Double
        public let minHoleYards: Double
        public let standardPars9: [Int]
        public let standardPars18: [Int]
    }

    public struct TileCost: Decodable, Sendable {
        public let rough: Int
        public let fairway: Int
        public let green: Int
        public let bunker: Int
        public let water: Int
        public let trees: Int
        public let tee: Int
    }

    public struct Clock: Decodable, Sendable {
        public let dayStartMinute: Int
        public let dayEndMinute: Int
        public let gameMinutesPerRealSecond: Double
        public let speeds: [Int]
    }

    public struct Calendar: Decodable, Sendable {
        public let seasonDemandByMonth: [Double]
        public let weekendDemand: Double
        public let fridayDemand: Double
        public let winterMonths: [Int]
        public let winterStormMultiplier: Double
        public let winterConditionLoss: Double
    }

    public struct Career: Decodable, Sendable {
        public let startingCash: Int
    }

    public struct PlotPrice: Decodable, Sendable {
        public let base18: Double
        public let base9: Double
        public let wealthExponent: Double
        public let prestigeBase: Double
        public let prestigeFactor: Double
        public let roundTo: Double
    }

    public struct Analysis: Decodable, Sendable {
        public let baseScore: Double
        public let bunkerTileBonus: Double
        public let bunkerTileBonusCap: Int
        public let treeTileBonus: Double
        public let treeTileBonusCap: Int
        public let diminishingReturns: [Double]
        public let islandGreenWaterShare: Double
        public let guardedGreenWaterShare: Double
        public let doubleDoglegDeviation: Double
        public let doglegDeviation: Double
        public let minFairwayRowsForShape: Int
        public let narrowFairwayWidth: Double
        public let wasteBunkerTiles: Int
        public let showcaseBunkerTiles: Int
        public let guardBunkerRadius: Double
        public let guardBunkerGroups: Int
        public let potBunkerMaxTiles: Int
        public let potBunkerCount: Int
        public let driveableMaxYards: Double
        public let treeLinedShare: Double
        public let points: [String: Double]
    }

    public struct Fairness: Decodable, Sendable {
        public let severity: [String: Double]
        public let testingFrom: Double
        public let brutalFrom: Double
        public let penaltyPerPointOverBrutal: Double
        public let maxPenalty: Double
    }

    public struct Design: Decodable, Sendable {
        public struct Repetition: Decodable, Sendable {
            public let holesPerFreeRepeat: Int
            public let decay: Double
        }
        public struct Word: Decodable, Sendable {
            public let from: Double
            public let word: String
        }
        public let averageWeight: Double
        public let pointsPerFeatureKind: Double
        public let maxFeatureKindBonus: Double
        public let allParsBonus: Double
        public let singleParPenalty: Double
        public let bestHoleBonusFrom: Double
        public let bestHoleBonus: Double
        public let signatureFrom: Double
        public let repetition: Repetition
        public let brutalShareLimit: Double
        public let brutalCoursePenalty: Double
        public let words: [Word]
    }

    public struct Course: Decodable, Sendable {
        public let startCondition: Double
        public let startReputation: Double
        public let conditionMin: Double
        public let conditionMax: Double
        public let rainConditionLoss: Double
        public let stormConditionLoss: Double
    }

    public struct Upkeep: Decodable, Sendable {
        public let base: Double
        public let perHole: Double
        public let perFairwayTile: Double
        public let perGreenTile: Double
        public let perBunkerTile: Double
        public let perWaterTile: Double
    }

    public struct Greenkeepers: Decodable, Sendable {
        public let levels: [String]
        public let dailyWage9PerLevel: Int
        public let dailyWage18PerLevel: Int
        public let conditionRecovery: [Double]
    }

    public struct Weather: Decodable, Sendable {
        public let rainChance: Double
        public let northRainBonus: Double
        public let northLatitude: Double
        public let windChanceLinks: Double
        public let windChanceInland: Double
        public let cloudChance: Double
        public let stormChanceLinks: Double
        public let demand: [String: Double]
    }

    public let grid: Grid
    public let par: Par
    public let tileCost: TileCost
    public let clock: Clock
    public let calendar: Calendar
    public let career: Career
    public let plotPrice: PlotPrice
    public let analysis: Analysis
    public let fairness: Fairness
    public let design: Design
    public let course: Course
    public let upkeep: Upkeep
    public let greenkeepers: Greenkeepers
    public let weather: Weather
}

extension Balance.Analysis {
    /// Points for a feature kind. A missing entry is a data error, so fail loudly in debug.
    func points(_ kind: FeatureKind) -> Double {
        guard let value = points[kind.rawValue] else {
            assertionFailure("balance.json analysis.points has no \(kind.rawValue)")
            return 0
        }
        return value
    }
}

extension Balance.TileCost {
    public func cost(of tile: Tile) -> Int {
        switch tile {
        case .rough: rough
        case .fairway: fairway
        case .green: green
        case .bunker: bunker
        case .water: water
        case .trees: trees
        case .tee: tee
        case .sea: 0
        }
    }
}
