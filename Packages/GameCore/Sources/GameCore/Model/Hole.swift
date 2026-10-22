/// One square of a hole. Raw values match the prototype so saved grids read the same.
public enum Tile: UInt8, Codable, CaseIterable, Sendable {
    case rough = 0, fairway, green, bunker, water, trees, tee, sea

    /// Water or sea: a penalty stroke.
    public var isWet: Bool { self == .water || self == .sea }
}

public struct GridPoint: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// A point in tile units, where (0.5, 0.5) is the centre of the top left tile.
public struct GridVector: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to other: GridVector) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}

/// A hole: a grid of tiles (row 0 at the far end, the tee near the bottom), plus a tee and a pin.
public struct Hole: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public private(set) var tiles: [Tile]
    public var tee: GridPoint?
    public var pin: GridPoint?

    public init(columns: Int, rows: Int, fill: Tile = .rough) {
        self.columns = columns
        self.rows = rows
        tiles = Array(repeating: fill, count: columns * rows)
    }

    public init(columns: Int, rows: Int, tiles: [Tile], tee: GridPoint?, pin: GridPoint?) {
        precondition(tiles.count == columns * rows, "tile count does not match the grid")
        self.columns = columns
        self.rows = rows
        self.tiles = tiles
        self.tee = tee
        self.pin = pin
    }

    public func contains(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < columns && y < rows
    }

    public func index(_ x: Int, _ y: Int) -> Int { y * columns + x }

    /// The tile at (x, y), or nil off the grid.
    public subscript(x: Int, y: Int) -> Tile? {
        contains(x, y) ? tiles[index(x, y)] : nil
    }

    public mutating func set(_ x: Int, _ y: Int, _ tile: Tile) {
        guard contains(x, y) else { return }
        tiles[index(x, y)] = tile
    }

    /// Counts of each tile type, for upkeep and scoring.
    public func count(of tile: Tile) -> Int {
        tiles.reduce(0) { $0 + ($1 == tile ? 1 : 0) }
    }

    public static func centre(of p: GridPoint) -> GridVector {
        GridVector(x: Double(p.x) + 0.5, y: Double(p.y) + 0.5)
    }
}

// Saved compactly as a string of digits, one per tile, as the prototype did.
extension Hole: Codable {
    private enum Keys: String, CodingKey { case columns, rows, grid, tee, pin }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        columns = try c.decode(Int.self, forKey: .columns)
        rows = try c.decode(Int.self, forKey: .rows)
        let grid = try c.decode(String.self, forKey: .grid)
        let parsed = grid.compactMap { $0.wholeNumberValue.flatMap { Tile(rawValue: UInt8($0)) } }
        guard parsed.count == columns * rows, grid.count == parsed.count else {
            throw DecodingError.dataCorruptedError(forKey: .grid, in: c, debugDescription: "Hole grid is the wrong size or has unknown tiles")
        }
        tiles = parsed
        tee = try c.decodeIfPresent(GridPoint.self, forKey: .tee)
        pin = try c.decodeIfPresent(GridPoint.self, forKey: .pin)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(columns, forKey: .columns)
        try c.encode(rows, forKey: .rows)
        try c.encode(String(tiles.map { Character(String($0.rawValue)) }), forKey: .grid)
        try c.encodeIfPresent(tee, forKey: .tee)
        try c.encodeIfPresent(pin, forKey: .pin)
    }
}
