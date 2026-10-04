public enum GameMode: Codable, Equatable, Sendable {
    case career
    case challenge(id: String)
    /// Milestone 1 only: one course on a chosen plot, land free, building charged.
    case sandbox
}

/// Everything that is saved. Plain values only, so it encodes to JSON and compares exactly.
public struct GameState: Codable, Equatable, Sendable {
    public var mode: GameMode
    public let seed: UInt64
    public var rng: SeededRandom
    /// Day 1's date, "yyyy-MM-dd".
    public let startDate: String
    /// 1 on the first day.
    public var day = 1
    /// Minutes since midnight. A day runs 07:00 (420) to 19:00 (1140).
    public var minute: Int
    /// True between close of play and the start of the next day.
    public var isDayOver = false
    public var cash: Int
    public var today: DayBooks
    /// Recent days' books, oldest first.
    public var pastDays: [DayBooks] = []
    /// Totals since the game began, for checking the books balance.
    public var lifetime: [LedgerCategory: Int] = [:]
    public let openingCash: Int
    public var courses: [String: Course] = [:]
    /// Course ids in the order they were acquired.
    public var courseOrder: [String] = []

    public init(mode: GameMode, seed: UInt64, startDate: String, cash: Int, dayStartMinute: Int) {
        self.mode = mode
        self.seed = seed
        rng = SeededRandom(seed: seed)
        self.startDate = startDate
        minute = dayStartMinute
        self.cash = cash
        openingCash = cash
        today = DayBooks(day: 1, openingCash: cash)
    }

    public var orderedCourses: [Course] { courseOrder.compactMap { courses[$0] } }
}
