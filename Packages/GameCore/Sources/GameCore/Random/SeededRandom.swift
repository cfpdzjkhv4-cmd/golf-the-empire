import Foundation

/// The only source of randomness in GameCore. Its state is saved with the game,
/// so the same seed and the same commands always give the same game.
/// Algorithm: SplitMix64, which is small, fast and good enough for a game.
public struct SeededRandom: RandomNumberGenerator, Codable, Equatable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A Double in 0..<1.
    public mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// An Int in a closed range, like the prototype's `ri(a, b)`.
    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    public mutating func double(_ range: Range<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    /// True with the given probability.
    public mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        precondition(!items.isEmpty, "pick from an empty list")
        return items[int(0...(items.count - 1))]
    }

    /// Plus or minus one, evenly.
    public mutating func sign() -> Int {
        chance(0.5) ? -1 : 1
    }
}

extension SeededRandom {
    /// A normally distributed number, mean 0 and standard deviation 1.
    public mutating func gauss() -> Double {
        var u = 0.0, v = 0.0
        while u == 0 { u = unit() }
        while v == 0 { v = unit() }
        return (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
    }

    /// An Int between two bounds given as a two element list from balance.json.
    public mutating func int(_ bounds: [Int]) -> Int {
        guard bounds.count == 2 else { return bounds.first ?? 0 }
        return int(min(bounds[0], bounds[1])...max(bounds[0], bounds[1]))
    }

    public mutating func double(_ bounds: [Double]) -> Double {
        guard bounds.count == 2 else { return bounds.first ?? 0 }
        return bounds[0] + unit() * (bounds[1] - bounds[0])
    }

    public mutating func shuffled<T>(_ items: [T]) -> [T] {
        var a = items
        if a.count < 2 { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, int(0...i))
        }
        return a
    }
}
