import Foundation

/// Turns game day numbers into real calendar dates. Day 1 is the start date.
/// Works in UTC at midday so clocks changing never shift a day.
public struct GameCalendar: Sendable {
    public let startDate: String
    public let balance: Balance
    private let start: Date
    private let calendar: Calendar

    private static let shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let longDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let longMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    /// `startDate` is "yyyy-MM-dd".
    public init(startDate: String, balance: Balance) {
        self.startDate = startDate
        self.balance = balance
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        calendar = cal
        let parts = startDate.split(separator: "-").compactMap { Int($0) }
        let components = DateComponents(
            year: parts.count == 3 ? parts[0] : 2026,
            month: parts.count == 3 ? parts[1] : 1,
            day: parts.count == 3 ? parts[2] : 1,
            hour: 12
        )
        start = cal.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// Today's date on the device, as "yyyy-MM-dd", for a new career.
    public static func isoDate(_ date: Date, in timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    public func date(ofDay day: Int) -> Date {
        calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
    }

    private func parts(_ day: Int) -> (weekday: Int, day: Int, month: Int, year: Int) {
        let c = calendar.dateComponents([.weekday, .day, .month, .year], from: date(ofDay: day))
        return ((c.weekday ?? 1) - 1, c.day ?? 1, c.month ?? 1, c.year ?? 2026)
    }

    /// "Sun 4 Oct"
    public func shortLabel(day: Int) -> String {
        let p = parts(day)
        return "\(Self.shortDays[p.weekday]) \(p.day) \(Self.shortMonths[p.month - 1])"
    }

    /// "Sunday 4 October 2026"
    public func longLabel(day: Int) -> String {
        let p = parts(day)
        return "\(Self.longDays[p.weekday]) \(p.day) \(Self.longMonths[p.month - 1]) \(p.year)"
    }

    /// 1 to 12.
    public func month(ofDay day: Int) -> Int { parts(day).month }

    /// 0 is Sunday, 6 is Saturday.
    public func weekday(ofDay day: Int) -> Int { parts(day).weekday }

    public func seasonDemand(day: Int) -> Double {
        balance.calendar.seasonDemandByMonth[month(ofDay: day) - 1]
    }

    public func weekdayDemand(day: Int) -> Double {
        switch weekday(ofDay: day) {
        case 0, 6: balance.calendar.weekendDemand
        case 5: balance.calendar.fridayDemand
        default: 1
        }
    }

    public func isWinter(day: Int) -> Bool {
        balance.calendar.winterMonths.contains(month(ofDay: day))
    }

    public func seasonName(day: Int) -> String {
        switch month(ofDay: day) {
        case 12, 1, 2: "Winter"
        case 3...5: "Spring"
        case 6...8: "Summer"
        default: "Autumn"
        }
    }

    /// "07:00"
    public static func clockLabel(minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
