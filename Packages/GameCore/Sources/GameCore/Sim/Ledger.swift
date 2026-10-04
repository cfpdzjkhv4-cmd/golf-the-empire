/// Every pound in or out goes through one of these, so the books always reconcile.
public enum LedgerCategory: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    // Money in
    case greenFees, barAndShop, memberSubscriptions, tournaments, courseSales
    // Money out
    case upkeep, staffWages, buildingWork, facilities, landBought

    public var isIncome: Bool {
        switch self {
        case .greenFees, .barAndShop, .memberSubscriptions, .tournaments, .courseSales: true
        default: false
        }
    }

    public var label: String {
        switch self {
        case .greenFees: "Green fees"
        case .barAndShop: "Bar and shop"
        case .memberSubscriptions: "Member subscriptions"
        case .tournaments: "Tournaments"
        case .courseSales: "Course sales"
        case .upkeep: "Upkeep"
        case .staffWages: "Staff wages"
        case .buildingWork: "Building work"
        case .facilities: "Facilities"
        case .landBought: "Land and clubs bought"
        }
    }
}

/// One day's books: what came in and went out, by category.
public struct DayBooks: Codable, Equatable, Sendable {
    public let day: Int
    public let openingCash: Int
    public private(set) var amounts: [LedgerCategory: Int] = [:]

    public init(day: Int, openingCash: Int) {
        self.day = day
        self.openingCash = openingCash
    }

    public var moneyIn: Int { amounts.filter { $0.key.isIncome }.values.reduce(0, +) }
    public var moneyOut: Int { amounts.filter { !$0.key.isIncome }.values.reduce(0, +) }
    public var net: Int { moneyIn - moneyOut }
    public var closingCash: Int { openingCash + net }

    public subscript(category: LedgerCategory) -> Int { amounts[category] ?? 0 }

    mutating func record(_ category: LedgerCategory, _ amount: Int) {
        amounts[category, default: 0] += amount
    }
}
