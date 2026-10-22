import Foundation
import GameCore

/// The golfer: one vector rig, posed and animated in code, recoloured per golfer.
/// Units are points with y up and the feet at (0, 0). Drawn face on, like a TV camera behind the ball.
public struct GolferRig: Sendable {
    public enum Part: String, CaseIterable, Sendable {
        case legLeft, legRight, torso, arms, head
    }

    public enum Shape: Equatable, Sendable {
        /// Rounded rectangle hanging down from the pivot.
        case limb(width: Double, length: Double)
        case box(width: Double, height: Double, corner: Double)
        case circle(radius: Double)
    }

    public enum Hat: String, CaseIterable, Sendable {
        case none, cap, flatCap, bucket, bobble
    }

    public struct Outfit: Equatable, Sendable {
        public let shirt: RGBA
        public let trousers: RGBA
        public let skin: RGBA
        public let hair: RGBA
        public let hat: Hat
        public let hatColour: RGBA
    }

    /// Joint angles in radians, anticlockwise. Arms carry the club; 0 is hanging straight down.
    public struct Pose: Equatable, Sendable {
        public var legLeft = 0.0
        public var legRight = 0.0
        public var torso = 0.0
        public var arms = 0.0
        public var head = 0.0
        /// Body lift, for a walking bob.
        public var lift = 0.0

        public init(legLeft: Double = 0, legRight: Double = 0, torso: Double = 0, arms: Double = 0, head: Double = 0, lift: Double = 0) {
            self.legLeft = legLeft
            self.legRight = legRight
            self.torso = torso
            self.arms = arms
            self.head = head
            self.lift = lift
        }

        /// In between two poses, for smooth animation frames.
        public static func blend(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
            func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
            return Pose(legLeft: mix(a.legLeft, b.legLeft), legRight: mix(a.legRight, b.legRight), torso: mix(a.torso, b.torso),
                        arms: mix(a.arms, b.arms), head: mix(a.head, b.head), lift: mix(a.lift, b.lift))
        }

        public func angle(_ part: Part) -> Double {
            switch part {
            case .legLeft: legLeft
            case .legRight: legRight
            case .torso: torso
            case .arms: arms
            case .head: head
            }
        }
    }

    // MARK: Geometry

    public static let hip = 10.0
    public static let shoulder = 19.0
    public static let clubLength = 13.0

    /// Where each part pivots, relative to the feet (before lift).
    public static func pivot(_ part: Part) -> ArtPoint {
        switch part {
        case .legLeft: ArtPoint(-2, hip)
        case .legRight: ArtPoint(2, hip)
        case .torso: ArtPoint(0, hip)
        case .arms: ArtPoint(0, shoulder)
        case .head: ArtPoint(0, 21.5)
        }
    }

    public static func shape(_ part: Part) -> Shape {
        switch part {
        case .legLeft, .legRight: .limb(width: 3.2, length: hip)
        case .torso: .box(width: 9, height: 10.5, corner: 3)
        case .arms: .limb(width: 6.5, length: 8.5)
        case .head: .circle(radius: 3.4)
        }
    }

    // MARK: Poses (from the asset manifest: idle, walk, address, swing, putt, celebrate, despair)

    public static let idle = Pose(arms: 0.05)
    public static let address = Pose(legLeft: 0.12, legRight: -0.12, torso: 0, arms: 0, head: -0.05)
    public static let top = Pose(legLeft: 0.12, legRight: -0.08, torso: 0.18, arms: 2.4, head: 0.05)
    public static let impact = Pose(legLeft: 0.1, legRight: -0.14, torso: -0.05, arms: -0.05, head: -0.05)
    public static let finish = Pose(legLeft: 0.05, legRight: -0.3, torso: -0.25, arms: -2.5, head: -0.2)
    public static let puttBack = Pose(legLeft: 0.1, legRight: -0.1, arms: 0.35, head: -0.1)
    public static let puttThrough = Pose(legLeft: 0.1, legRight: -0.1, arms: -0.35, head: -0.1)
    public static let walkA = Pose(legLeft: 0.4, legRight: -0.4, arms: -0.15, lift: 0)
    public static let walkB = Pose(legLeft: -0.4, legRight: 0.4, arms: 0.15, lift: 0)
    public static let walkMid = Pose(arms: 0, lift: 1)
    public static let celebrate = Pose(legLeft: 0.15, legRight: -0.15, arms: 3.1, head: 0.15, lift: 2)
    public static let despair = Pose(legLeft: 0.05, legRight: -0.05, torso: 0.3, arms: 0.4, head: 0.5)

    // MARK: Outfits

    static let shirts = ["#D94F3D", "#2F6DB5", "#F2C230", "#7B4FA8", "#E58A2E", "#2A9D8F", "#EDEDED", "#C2417A", "#3D405B"]
    static let trousers = ["#2B3550", "#5A5F66", "#C9B48A", "#2F3B2A", "#1F1F24"]
    static let skins = ["#F1C9A5", "#E0AC84", "#C68B5E", "#8D5A3B", "#5C3A26"]
    static let hairs = ["#2A1E16", "#5A3A22", "#A87A48", "#C9C3B8", "#E5D7A8"]

    /// A random but repeatable outfit for a golfer.
    public static func outfit(seed: UInt64) -> Outfit {
        var rng = SeededRandom(seed: seed)
        return Outfit(
            shirt: RGBA(hex: rng.pick(shirts)), trousers: RGBA(hex: rng.pick(trousers)),
            skin: RGBA(hex: rng.pick(skins)), hair: RGBA(hex: rng.pick(hairs)),
            hat: rng.pick(Hat.allCases), hatColour: RGBA(hex: rng.pick(shirts + trousers))
        )
    }

    // MARK: Drawing a pose (for previews; the game builds SpriteKit nodes from the same numbers)

    /// Draw instructions for one pose, y down, with the feet at `origin`.
    public static func draw(_ pose: Pose, outfit: Outfit, at origin: ArtPoint, putter: Bool = false) -> [DrawOp] {
        var ops: [DrawOp] = []
        func transform(_ p: ArtPoint, part: Part, extraAngle: Double = 0) -> ArtPoint {
            // Rotate about the part's pivot (anticlockwise, y up), lift, then flip to y down at origin.
            var pv = GolferRig.pivot(part)
            var a = pose.angle(part) + extraAngle
            if part == .arms || part == .head {
                // Arms and head ride on the torso.
                let t = pose.torso
                let tp = GolferRig.pivot(.torso)
                let rx = pv.x - tp.x, ry = pv.y - tp.y
                let nx = tp.x + rx * cos(t) - ry * sin(t)
                let ny = tp.y + rx * sin(t) + ry * cos(t)
                pv = ArtPoint(nx, ny)
                a += t
            }
            let dx = p.x, dy = p.y
            let x = pv.x + dx * cos(a) - dy * sin(a)
            let y = pv.y + dx * sin(a) + dy * cos(a) + pose.lift
            return ArtPoint(origin.x + x, origin.y - y)
        }
        func polygon(_ pts: [ArtPoint], part: Part) -> ArtPath {
            ArtPath(loops: [pts.map { transform($0, part: part) }])
        }
        func roundedLimb(width w: Double, length l: Double) -> [ArtPoint] {
            // A capsule hanging straight down from the pivot.
            var pts: [ArtPoint] = []
            let r = w / 2
            for k in 0...6 { let a = Double.pi + Double(k) / 6 * Double.pi; pts.append(ArtPoint(cos(a) * r, -l + r + sin(a) * r)) }
            for k in 0...6 { let a = Double(k) / 6 * Double.pi; pts.append(ArtPoint(cos(a) * r, -r * 0.2 + sin(a) * r * 0.2)) }
            return pts
        }

        // Shadow on the ground.
        ops.append(.ellipse(centre: ArtPoint(origin.x + 2, origin.y), rx: 7, ry: 2.2, ArtStyle.shared.shadow))
        // Legs.
        for leg in [Part.legLeft, .legRight] {
            ops.append(.fill(polygon(roundedLimb(width: 3.2, length: hip), part: leg), outfit.trousers))
            ops.append(.fill(polygon([ArtPoint(-1.8, -hip), ArtPoint(2.6, -hip), ArtPoint(2.6, -hip + 1.4), ArtPoint(-1.8, -hip + 1.4)], part: leg),
                             RGBA(hex: "#2A2A2A")))
        }
        // Torso.
        let tw = 9.0, th = 10.5
        ops.append(.fill(polygon([ArtPoint(-tw / 2, 0), ArtPoint(tw / 2, 0), ArtPoint(tw / 2 - 0.5, th), ArtPoint(-tw / 2 + 0.5, th)], part: .torso), outfit.shirt))
        // Head, hair, hat.
        let head = transform(ArtPoint(0, 2.6), part: .head)
        ops.append(.ellipse(centre: head, rx: 3.4, ry: 3.6, outfit.skin))
        ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 1.8), rx: 3.3, ry: 1.8, outfit.hair))
        switch outfit.hat {
        case .none: break
        case .cap:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.2), rx: 3.6, ry: 2.1, outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x + 2.6, head.y - 1.1), rx: 2.2, ry: 0.8, outfit.hatColour))
        case .flatCap:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.0), rx: 4.0, ry: 1.7, outfit.hatColour))
        case .bucket:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 1.2), rx: 4.8, ry: 1.2, outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.6), rx: 3.4, ry: 2.0, outfit.hatColour))
        case .bobble:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.4), rx: 3.6, ry: 2.4, outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 5.2), rx: 1.3, ry: 1.3, RGBA(hex: "#F4F0E6")))
        }
        // Arms (both hands on the grip) and the club.
        let hands = ArtPoint(0, -8.5)
        let leftShoulder = ArtPoint(-3.6, 0), rightShoulder = ArtPoint(3.6, 0)
        for s in [leftShoulder, rightShoulder] {
            let dx = hands.x - s.x, dy = hands.y - s.y
            let len = max(0.01, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / len * 1.2, ny = dx / len * 1.2
            ops.append(.fill(polygon([ArtPoint(s.x + nx, s.y + ny), ArtPoint(hands.x + nx * 0.7, hands.y + ny * 0.7),
                                      ArtPoint(hands.x - nx * 0.7, hands.y - ny * 0.7), ArtPoint(s.x - nx, s.y - ny)], part: .arms), outfit.shirt))
        }
        ops.append(.ellipse(centre: transform(hands, part: .arms), rx: 1.6, ry: 1.6, outfit.skin))
        let length = putter ? clubLength * 0.75 : clubLength
        let clubEnd = transform(ArtPoint(0.8, hands.y - length), part: .arms)
        let clubStart = transform(hands, part: .arms)
        ops.append(.stroke(ArtPath(loops: [[clubStart, clubEnd, clubStart]]), RGBA(hex: "#3A3A3A"), width: 0.9))
        ops.append(.ellipse(centre: clubEnd, rx: putter ? 1.6 : 1.3, ry: 0.9, RGBA(hex: "#8C9196")))
        return ops
    }
}
