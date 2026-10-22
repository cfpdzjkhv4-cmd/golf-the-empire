import CourseArt
import GameCore
import SpriteKit

/// A golfer on the course: the CourseArt rig drawn into frames at run time and animated
/// by blending between its poses. No hand drawn frames anywhere.
@MainActor
final class GolferSprite: SKSpriteNode {
    private var outfit = GolferRig.outfit(seed: 1)
    private var cache: [String: SKTexture] = [:]
    /// Rig units are points with the golfer about 30 tall.
    private static let canvas = CGSize(width: 44, height: 48)
    private static let feet = ArtPoint(22, 42)

    init(heightInWorld: CGFloat) {
        super.init(texture: nil, color: .clear, size: CGSize(width: heightInWorld * Self.canvas.width / Self.canvas.height, height: heightInWorld))
        anchorPoint = CGPoint(x: Self.feet.x / Self.canvas.width, y: 1 - Self.feet.y / Self.canvas.height)
        texture = frame(GolferRig.idle, putter: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("GolferSprite is built in code")
    }

    func dress(seed: UInt64) {
        outfit = GolferRig.outfit(seed: seed)
        cache.removeAll()
        texture = frame(GolferRig.idle, putter: false)
    }

    private func frame(_ pose: GolferRig.Pose, putter: Bool) -> SKTexture {
        let key = String(format: "%.2f %.2f %.2f %.2f %.2f %.2f %d", pose.legLeft, pose.legRight, pose.torso, pose.arms, pose.head, pose.lift, putter ? 1 : 0)
        if let t = cache[key] { return t }
        let image = HoleImageRenderer.render(GolferRig.draw(pose, outfit: outfit, at: Self.feet, putter: putter), size: Self.canvas, unit: 1)
        let t = SKTexture(image: image)
        cache[key] = t
        return t
    }

    /// Frames blending through a list of poses.
    private func frames(_ poses: [GolferRig.Pose], steps: Int, putter: Bool) -> [SKTexture] {
        var out: [SKTexture] = []
        for (a, b) in zip(poses, poses.dropFirst()) {
            for k in 0..<steps { out.append(frame(.blend(a, b, Double(k) / Double(steps)), putter: putter)) }
        }
        if let last = poses.last { out.append(frame(last, putter: putter)) }
        return out
    }

    /// Address, backswing, through, finish. About 1.1 seconds; a putt is a short stroke.
    func swingAction(putt: Bool) -> SKAction {
        let poses = putt
            ? [GolferRig.address, GolferRig.puttBack, GolferRig.puttThrough]
            : [GolferRig.address, GolferRig.top, GolferRig.impact, GolferRig.finish]
        let steps = putt ? 4 : 5
        let textures = frames(poses, steps: steps, putter: putt)
        return .sequence([
            .setTexture(frame(GolferRig.address, putter: putt)), .wait(forDuration: 0.25),
            .animate(with: Array(textures.prefix(steps + 1)), timePerFrame: putt ? 0.06 : 0.07),
            .animate(with: Array(textures.dropFirst(steps + 1)), timePerFrame: putt ? 0.05 : 0.025),
        ])
    }

    func walk(to point: CGPoint, duration: TimeInterval) {
        removeAction(forKey: "walk")
        let step = frames([GolferRig.walkA, GolferRig.walkMid, GolferRig.walkB, GolferRig.walkMid, GolferRig.walkA], steps: 2, putter: false)
        let cycle = SKAction.repeatForever(.animate(with: step, timePerFrame: 0.06))
        let move = SKAction.move(to: point, duration: duration)
        move.timingMode = .easeInEaseOut
        xScale = point.x < position.x ? -abs(xScale) : abs(xScale)
        run(.sequence([.group([move, .sequence([.wait(forDuration: duration), .run { [weak self] in self?.removeAction(forKey: "legs") }])]),
                       .setTexture(frame(GolferRig.idle, putter: false))]), withKey: "walk")
        run(cycle, withKey: "legs")
    }

    func react(_ pose: GolferRig.Pose) {
        run(.sequence([.setTexture(frame(pose, putter: false)), .wait(forDuration: 1.2), .setTexture(frame(GolferRig.idle, putter: false))]))
    }
}
