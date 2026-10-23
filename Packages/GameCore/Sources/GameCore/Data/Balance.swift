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
        public let bridge: Int
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
        public struct Playtest: Decodable, Sendable {
            public let golfers: Int
            public let skillMin: Double
            public let skillMax: Double
            public let testingOverPar: Double
            public let brutalOverPar: Double
            public let testingPenalties: Double
            public let brutalPenalties: Double
        }
        public let playtest: Playtest
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
        public let wearPerRound18: Double
        public let wearPerRound9: Double
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

    public struct Golfers: Decodable, Sendable {
        public let skillBase: Double
        public let skillRandom: Double
        public let skillPerReputation: Double
        public let skillMin: Double
        public let skillMax: Double
        public let groupSizeMax: Int
        public let teeIntervalMinutes: Int
        public let pickUpAfterShots: Int
        public let pickUpOverPar: Int
    }

    public struct Shots: Decodable, Sendable {
        public let baseCarry: Double
        public let carryPerSkill: Double
        public let minTargetYards: Double
        public let mustGainYards: Double
        public let pinReachFactor: Double
        public let lieDistance: [String: Double]
        public let bunkerShortYards: Double
        public let targetPenalty: [String: Double]
        public let pinTargetScore: Double
        public let nearWaterPenalty: Double
        public let nearWaterSkillOffset: Double
        public let lieError: [String: Double]
        public let aimErrorBase: Double
        public let aimErrorPerMissingSkill: Double
        public let shankChancePerMissingSkill: Double
        public let shankAngleMin: Double
        public let shankAngleRandom: Double
        public let lengthErrorBase: Double
        public let lengthErrorPerMissingSkill: Double
        public let minCarry: Double
        public let roll: [String: Double]
        public let chipInYards: Double
        public let chipInChance: Double
        public let puttHoleBase: Double
        public let puttHolePerSkill: Double
        public let puttLongYards: Double
        public let puttLeaveMin: Double
        public let puttLeaveBase: Double
        public let puttLeaveRandom: Double
        public let puttLeaveSkillOffset: Double
        public let windFactor: [String: Double]
    }

    public struct Demand: Decodable, Sendable {
        public let groupsPerHourPerDemand: Double
        public let reputationBase: Double
        public let reputationDivisor: Double
        public let priceBase: Double
        public let pricePerFairRatio: Double
        public let priceMin: Double
        public let priceMax: Double
        public let rangeBonus: Double
        public let designBase: Double
        public let designPer: Double
    }

    public struct Fees: Decodable, Sendable {
        public let base: Double
        public let perReputation: Double
        public let eighteenHoleFactor: Double
        public let designBase: Double
        public let designPer: Double
        public let interestUplift: Double
        public let step: Int
        public let minimum: Int
        public let maximum: Int
    }

    public struct Spend: Decodable, Sendable {
        public let barBase: Double
        public let barPerStar: Double
    }

    public struct Quality: Decodable, Sendable {
        public let interestBunkerTiles: Double
        public let interestBunker: Double
        public let interestWaterTiles: Double
        public let interestWater: Double
        public let interestTreeTiles: Double
        public let interestTrees: Double
        public let beautyTreeTiles: Double
        public let beautyTrees: Double
        public let beautyWaterTiles: Double
        public let beautyWater: Double
        public let varietyAllPars: Double
        public let varietyTwoPars: Double
        public let varietyOnePar: Double
        public let weakUnderYards: Double
        public let weakMinFairwayTiles: Int
    }

    public struct Reviews: Decodable, Sendable {
        public let base: Double
        public let randomSpread: Double
        public let designPer: Double
        public let designFrom: Double
        public let beautyWeight: Double
        public let prestigeWeight: Double
        public let scoreUnderPar: Double
        public let scoreGreatBelow: Double
        public let scoreSmallOver: Double
        public let scoreSmallOverLimit: Double
        public let scoreFairLimit: Double
        public let scoreBadLimit: Double
        public let scoreBad: Double
        public let scoreAwful: Double
        public let penaltyEach: Double
        public let penaltyMax: Double
        public let weakPer: Double
        public let conditionFrom: Double
        public let conditionRange: Double
        public let conditionWeight: Double
        public let clubhousePerLevel: Double
        public let range: Double
        public let shopPerLevel: Double
        public let rain: Double
        public let overpricedRange: Double
        public let overpricedWeight: Double
        public let bargainBelow: Double
        public let bargain: Double
        public let signatureQuoteChance: Double
        public let kept: Int
    }

    public struct Reputation: Decodable, Sendable {
        public struct Ceiling: Decodable, Sendable {
            public let cap: Double
            public let need: String
            public let clubhouse: Int?
            public let condition: Double?
            public let design: Double?
            public let hosted: String?
        }
        public let dailyMove: Double
        public let nineHoleCap: Double
        public let ceilings: [Ceiling]
    }

    public struct Market: Decodable, Sendable {
        public let initialListings: Int
        public let starterQuietSales: Int
        public let quietMaxGuide: Int
        public let quietMaxPrestige: Double
        public let sealedCloseDays: [Int]
        public let newListingEveryDays: [Int]
        public let secondListingChance: Double
        public let quietExpiresDays: [Int]
        public let coolOffDays: [Int]
        public let privateDealChance: Double
        public let administrationEveryDays: [Int]
        public let administrationCloseDays: Int
        public let administrationPriceFactor: Double
        public let administrationPerHole: Double
        public let priceDrift: Double
        public let priceMultiplierMin: Double
        public let priceMultiplierMax: Double
        public let newListingMultiplier: [Double]
        public let reserveShare: Double
        public let failedSaleDiscount: Double
        public let minimumOfferShare: Double
        public let offerStep: Int
        public let roundTo: Double
    }

    public struct Rivals: Decodable, Sendable {
        public let interestChance: Double
        public let rumourNoise: Double
        public let minimumBidShareOfGuide: Double
        public let dailyIncome18: Double
        public let dailyIncome9: Double
        public let reputationDrift: Double
        public let reputationNoise: Double
        public let competitionKm: Double
        public let competitionMax: Double
        public let budgetBustReputation: Double
        public let budgetBustChance: Double
        public let anyBustChance: Double
        public let snapUpChance: Double
        public let snapUpMaxPrice: Int
        public let sellChance: Double
        public let newCourseReputation: Double
        public let administrationCourseReputation: Double
    }

    public struct Championship: Decodable, Sendable {
        public let rotaDays: Int
        public let rivalTakeChance: Double
        public let rivalMinReputation: Double
        public let minPrestige: Double
    }

    public struct Administration: Decodable, Sendable {
        public let clubhouse: Int
        public let reputation: Double
        public let condition: Double
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
    public let golfers: Golfers
    public let shots: Shots
    public let demand: Demand
    public let fees: Fees
    public let spend: Spend
    public let quality: Quality
    public let reviews: Reviews
    public let reputation: Reputation
    public struct Stamps: Decodable, Sendable {
        /// Stamp ids in the order the tool bar shows them.
        public let order: [String]
        /// Rows of text, top to bottom; '#' is sand.
        public let shapes: [String: [String]]
    }
    public let stamps: Stamps
    public let market: Market
    public let rivals: Rivals
    public let championship: Championship
    public let administration: Administration
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
        case .bridge: bridge
        case .sea: 0
        }
    }
}
