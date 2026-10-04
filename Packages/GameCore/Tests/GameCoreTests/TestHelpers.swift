@testable import GameCore

let data = GameData.bundled
let balance = data.balance

/// Builds test holes by painting shapes onto plain rough.
struct HoleSketch {
    var hole = Hole(columns: 16, rows: 32)

    mutating func rect(_ tile: Tile, x: ClosedRange<Int>, y: ClosedRange<Int>) {
        for yy in y { for xx in x { hole.set(xx, yy, tile) } }
    }

    mutating func ellipse(_ tile: Tile, cx: Int, cy: Int, rx: Double, ry: Double) {
        for y in 0..<hole.rows {
            for x in 0..<hole.columns {
                let dx = Double(x - cx) / rx, dy = Double(y - cy) / ry
                if dx * dx + dy * dy <= 1 { hole.set(x, y, tile) }
            }
        }
    }

    mutating func tee(_ x: Int, _ y: Int) {
        hole.set(x, y, .tee)
        hole.tee = GridPoint(x: x, y: y)
    }

    /// A green around (x, y) with the pin in the middle.
    mutating func green(_ x: Int, _ y: Int) {
        ellipse(.green, cx: x, cy: y, rx: 2.3, ry: 1.9)
        hole.pin = GridPoint(x: x, y: y)
    }
}

func analyze(_ hole: Hole) -> HoleAnalysis {
    HoleAnalyzer(balance: balance).analyze(hole)
}

func kinds(_ a: HoleAnalysis) -> Set<FeatureKind> {
    Set(a.features.map(\.kind))
}

/// A plain straight par 4: three wide fairway, green, nothing else.
func plainPar4() -> HoleSketch {
    var s = HoleSketch()
    s.rect(.fairway, x: 7...9, y: 9...26)
    s.green(8, 6)
    s.tee(8, 30)
    return s
}

/// A par 3 with the green ringed by water.
func islandPar3() -> HoleSketch {
    var s = HoleSketch()
    s.ellipse(.water, cx: 8, cy: 18, rx: 4.5, ry: 3.8)
    s.green(8, 18)
    s.tee(8, 30)
    return s
}
