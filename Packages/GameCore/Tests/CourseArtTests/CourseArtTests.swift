import CourseArt
import GameCore
import XCTest

final class CourseArtTests: XCTestCase {
    private let tracer = ContourTracer()

    private func box(_ x: ClosedRange<Int>, _ y: ClosedRange<Int>, _ tile: Tile = .green) -> Hole {
        var hole = Hole(columns: 16, rows: 32)
        for yy in y { for xx in x { hole.set(xx, yy, tile) } }
        return hole
    }

    private func area(_ loop: [ArtPoint]) -> Double {
        var a = 0.0
        for k in loop.indices {
            let p = loop[k], q = loop[(k + 1) % loop.count]
            a += p.x * q.y - q.x * p.y
        }
        return abs(a) / 2
    }

    func testOutlineFollowsTheTiles() {
        let path = tracer.outline(box(4...9, 10...15)) { $0 == .green }
        XCTAssertEqual(path.loops.count, 1)
        // A 6 by 6 patch should come out close to 36 square tiles, a little less for the rounded corners.
        XCTAssertEqual(area(path.loops[0]), 36, accuracy: 6)
        for p in path.loops[0] {
            XCTAssertTrue((3...11).contains(p.x) && (9...17).contains(p.y), "\(p) strays from the patch")
        }
    }

    func testSeparatePatchesGiveSeparateLoops() {
        var hole = box(1...3, 2...4)
        for y in 20...22 { for x in 10...12 { hole.set(x, y, .green) } }
        XCTAssertEqual(tracer.outline(hole) { $0 == .green }.loops.count, 2)
        XCTAssertTrue(tracer.outline(hole) { $0 == .water }.isEmpty)
    }

    func testNarrowFairwayStillShows() {
        let path = tracer.outline(box(8...8, 5...25, .fairway)) { $0 == .fairway }
        XCTAssertEqual(path.loops.count, 1, "a one tile wide fairway must not vanish")
        XCTAssertGreaterThan(area(path.loops[0]), 10)
    }

    func testArtIsRepeatableAndBalanced() {
        let generator = HoleGenerator(balance: GameData.bundled.balance)
        var rng = SeededRandom(seed: 4)
        let base = generator.baseLand(.links, rng: &rng)
        let hole = generator.signatureLayout(par: 4, land: .links, on: base, rng: &rng)
        let artist = HoleArtist()
        let a = artist.paint(hole, land: .links, seed: 9)
        XCTAssertEqual(a, artist.paint(hole, land: .links, seed: 9))
        let clips = a.filter { if case .clip = $0 { return true } else { return false } }.count
        let ends = a.filter { $0 == .endClip }.count
        XCTAssertEqual(clips, ends, "every clip is closed")
    }

    func testStyleLoadsAndRigPosesDraw() {
        XCTAssertEqual(ArtStyle.shared.terrain("fairway").hex, "#86BA55")
        let outfit = GolferRig.outfit(seed: 2)
        for pose in [GolferRig.idle, GolferRig.top, GolferRig.finish, GolferRig.celebrate] {
            XCTAssertFalse(GolferRig.draw(pose, outfit: outfit, at: ArtPoint(20, 40)).isEmpty)
        }
        let half = GolferRig.Pose.blend(GolferRig.address, GolferRig.top, 0.5)
        XCTAssertEqual(half.arms, GolferRig.top.arms / 2, accuracy: 0.001)
    }
}
