/// Why a hole can't be played yet.
public enum HoleIssue: Equatable, Sendable {
    case needsTee
    case needsPinOnGreen
    case tooShort

    public var text: String {
        switch self {
        case .needsTee: "needs a tee"
        case .needsPinOnGreen: "needs a pin on a green"
        case .tooShort: "is under 80 yards"
        }
    }
}

public struct HoleRules: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Straight line yards from the centre of the tee to the centre of the pin.
    public func yards(_ hole: Hole) -> Double {
        guard let tee = hole.tee, let pin = hole.pin else { return 0 }
        return Hole.centre(of: tee).distance(to: Hole.centre(of: pin)) * balance.grid.yardsPerTile
    }

    /// Up to 250 yards par 3, up to 440 par 4, longer par 5.
    public func par(_ hole: Hole) -> Int {
        par(forYards: yards(hole))
    }

    public func par(forYards yards: Double) -> Int {
        yards <= balance.par.par3MaxYards ? 3 : yards <= balance.par.par4MaxYards ? 4 : 5
    }

    public func issue(_ hole: Hole) -> HoleIssue? {
        guard hole.tee != nil else { return .needsTee }
        guard let pin = hole.pin, hole[pin.x, pin.y] == .green else { return .needsPinOnGreen }
        if yards(hole) < balance.par.minHoleYards { return .tooShort }
        return nil
    }

    public func isPlayable(_ hole: Hole) -> Bool { issue(hole) == nil }
}
