// Renders hero holes in the house style to SVG, for reviewing the look without a phone.
// Usage: swift run art-preview <output folder>
import CourseArt
import Foundation
import GameCore

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "art-preview-output", isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let data = GameData.bundled
let generator = HoleGenerator(balance: data.balance)
let artist = HoleArtist()
let scale = 24.0

var cards: [String] = []
let examples: [(String, LandKind, Int, UInt64)] = [
    ("Parkland par 4", .parkland, 4, 3), ("Links par 5", .links, 5, 8), ("Heathland par 3", .heathland, 3, 21),
    ("Moorland par 4", .moorland, 4, 14),
]
for (name, land, par, seed) in examples {
    var rng = SeededRandom(seed: seed)
    let base = generator.baseLand(land, rng: &rng)
    var hole = generator.bestSignatureLayout(par: par, land: land, on: base, tries: 6, rng: &rng)
    if land == .links { for x in 0..<hole.columns { hole.set(x, 0, .sea) } }
    let score = HoleAnalyzer(balance: data.balance).analyze(hole).score
    let svg = SVGRenderer.svg(artist.paint(hole, land: land, seed: seed), width: Double(hole.columns), height: Double(hole.rows), scale: scale)
    let file = name.lowercased().replacingOccurrences(of: " ", with: "_") + ".svg"
    try svg.write(to: out.appendingPathComponent(file), atomically: true, encoding: .utf8)
    cards.append("<figure><img src=\"\(file)\"><figcaption>\(name) · rated \(String(format: "%.1f", score))</figcaption></figure>")
}
// The first hole with its club area, at each clubhouse level, and a tired course.
let clubArtist = ClubhouseArtist()
for (level, north) in [(0, true), (1, true), (2, false), (3, false)] {
    var rng = SeededRandom(seed: 40)
    let base = generator.baseLand(.parkland, rng: &rng)
    let hole = generator.autoLayout(par: 4, land: .parkland, on: base, rng: &rng)
    let club = ClubhouseArtist.Club(clubhouse: level, shop: level >= 1 ? min(2, level) : 0, range: level >= 2 ? 1 : 0, north: north, carsParked: 3 + level * 3)
    var ops = artist.paint(hole, land: .parkland, seed: 40, condition: level == 0 ? 35 : 85)
    ops += clubArtist.paint(club, columns: hole.columns, land: .parkland, seed: 40).map { $0.translated(0, Double(hole.rows)) }
    let height = Double(hole.rows + ClubhouseArtist.rows)
    let file = "club_\(level).svg"
    try SVGRenderer.svg(ops, width: Double(hole.columns), height: height, scale: scale).write(to: out.appendingPathComponent(file), atomically: true, encoding: .utf8)
    cards.append("<figure><img src=\"\(file)\"><figcaption>Clubhouse level \(level), \(north ? "stone" : "brick")\(level == 0 ? ", condition 35%" : "")</figcaption></figure>")
}

// The golfer rig in every pose, three outfits.
let poses: [(String, GolferRig.Pose, Bool)] = [
    ("idle", GolferRig.idle, false), ("walk", GolferRig.walkA, false), ("address", GolferRig.address, false),
    ("top", GolferRig.top, false), ("impact", GolferRig.impact, false), ("finish", GolferRig.finish, false),
    ("putt", GolferRig.puttBack, true), ("celebrate", GolferRig.celebrate, false), ("despair", GolferRig.despair, false),
]
var rigOps: [DrawOp] = []
for row in 0..<3 {
    let outfit = GolferRig.outfit(seed: UInt64(row * 7 + 3))
    for (col, pose) in poses.enumerated() {
        rigOps += GolferRig.draw(pose.1, outfit: outfit, at: ArtPoint(Double(col) * 34 + 20, Double(row) * 44 + 38), putter: pose.2)
    }
}
let rigWidth = Double(poses.count) * 34 + 6, rigHeight = 3 * 44 + 6.0
try SVGRenderer.svg([.fill(.rect(0, 0, rigWidth, rigHeight), RGBA(hex: "#86BA55"))] + rigOps, width: rigWidth, height: rigHeight, scale: 3)
    .write(to: out.appendingPathComponent("golfers.svg"), atomically: true, encoding: .utf8)
cards.append("<figure><img src=\"golfers.svg\"><figcaption>Golfer rig: \(poses.map(\.0).joined(separator: ", "))</figcaption></figure>")

let page = """
<!doctype html><meta charset="utf-8"><title>Hole art preview</title>
<style>body{margin:0;padding:16px;background:#F4F0E6;font:14px Georgia,serif;color:#1F2A1C;display:flex;gap:16px;flex-wrap:wrap}
figure{margin:0}img{display:block;border-radius:10px;box-shadow:0 2px 8px #0003}figcaption{margin-top:6px;text-align:center}</style>
\(cards.joined(separator: "\n"))
"""
try page.write(to: out.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
print("Wrote \(cards.count) holes to \(out.path)")
