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
        case none, cap, flatCap, bucket, bobble, visor
    }

    public enum Hair: String, CaseIterable, Sendable {
        case short, bald, long
    }

    /// What the shirt or jumper looks like.
    public enum Pattern: String, CaseIterable, Sendable {
        case plain, argyle, hoops, polo
    }

    /// The sort of golfer, which sets the look of the outfit.
    public enum Kind: String, CaseIterable, Sendable {
        /// Club stalwart: Pringle style jumper, slacks, flat cap, two tone shoes.
        case member
        /// Young gun: bright polo, cap, slim build.
        case youngGun
        /// Weekend hacker: rugby shirt, bucket or bobble hat, stocky.
        case hacker
        /// Visor, ponytail, smart polo.
        case lady
        /// Cardigan, grey hair, flat cap or nothing.
        case pensioner
    }

    public struct Outfit: Equatable, Sendable {
        public let kind: Kind
        public let shirt: RGBA
        /// Second colour for patterns and collars.
        public let trim: RGBA
        public let pattern: Pattern
        public let trousers: RGBA
        public let shoes: RGBA
        public let skin: RGBA
        public let hair: RGBA
        public let hairStyle: Hair
        public let hat: Hat
        public let hatColour: RGBA
        public let bag: RGBA
        /// Width multiplier: 0.85 is slim, 1.2 is stocky.
        public let build: Double
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
        /// The bag is slung on the back while walking or standing about, and put down to play.
        public var carriesBag = false

        public init(legLeft: Double = 0, legRight: Double = 0, torso: Double = 0, arms: Double = 0, head: Double = 0, lift: Double = 0,
                    carriesBag: Bool = false) {
            self.legLeft = legLeft
            self.legRight = legRight
            self.torso = torso
            self.arms = arms
            self.head = head
            self.lift = lift
            self.carriesBag = carriesBag
        }

        /// In between two poses, for smooth animation frames.
        public static func blend(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
            func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
            return Pose(legLeft: mix(a.legLeft, b.legLeft), legRight: mix(a.legRight, b.legRight), torso: mix(a.torso, b.torso),
                        arms: mix(a.arms, b.arms), head: mix(a.head, b.head), lift: mix(a.lift, b.lift),
                        carriesBag: t < 0.5 ? a.carriesBag : b.carriesBag)
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

    public static let idle = Pose(arms: 0.05, carriesBag: true)
    public static let address = Pose(legLeft: 0.12, legRight: -0.12, torso: 0, arms: 0, head: -0.05)
    public static let top = Pose(legLeft: 0.12, legRight: -0.08, torso: 0.18, arms: 2.4, head: 0.05)
    public static let impact = Pose(legLeft: 0.1, legRight: -0.14, torso: -0.05, arms: -0.05, head: -0.05)
    public static let finish = Pose(legLeft: 0.05, legRight: -0.3, torso: -0.25, arms: -2.5, head: -0.2)
    public static let puttBack = Pose(legLeft: 0.1, legRight: -0.1, arms: 0.35, head: -0.1)
    public static let puttThrough = Pose(legLeft: 0.1, legRight: -0.1, arms: -0.35, head: -0.1)
    public static let walkA = Pose(legLeft: 0.4, legRight: -0.4, arms: -0.15, lift: 0, carriesBag: true)
    public static let walkB = Pose(legLeft: -0.4, legRight: 0.4, arms: 0.15, lift: 0, carriesBag: true)
    public static let walkMid = Pose(arms: 0, lift: 1, carriesBag: true)
    public static let celebrate = Pose(legLeft: 0.15, legRight: -0.15, arms: 3.1, head: 0.15, lift: 2)
    public static let despair = Pose(legLeft: 0.05, legRight: -0.05, torso: 0.3, arms: 0.4, head: 0.5)


    // MARK: Outfits

    static let brights = ["#D94F3D", "#2F6DB5", "#F2C230", "#7B4FA8", "#E58A2E", "#2A9D8F", "#C2417A", "#4CB5E8", "#9BD14B"]
    static let jumpers = ["#2F4A7A", "#7A2E3A", "#3E5E3A", "#C9A24A", "#E9E1CF", "#5B6E8C", "#A0523A"]
    static let cardigans = ["#8C7A5B", "#6B4E3D", "#5F6B4F", "#9A8F84", "#4A5568"]
    static let rugby = ["#1E3A6E", "#7A1F2B", "#1F5A3A", "#2B2B2B", "#C25A1E"]
    static let slacks = ["#2B3550", "#5A5F66", "#C9B48A", "#2F3B2A", "#1F1F24", "#E8E2D2", "#6B5A45"]
    static let skins = ["#F1C9A5", "#E0AC84", "#C68B5E", "#8D5A3B", "#5C3A26"]
    static let hairs = ["#2A1E16", "#5A3A22", "#A87A48", "#C46A2E", "#E5D7A8"]
    static let greys = ["#C9C3B8", "#E6E2DA", "#9C978F"]
    static let bags = ["#1F1F24", "#7A2E3A", "#2F4A7A", "#F2F0EA", "#3E5E3A", "#8C6A3E"]

    /// A random but repeatable outfit for a golfer.
    public static func outfit(seed: UInt64) -> Outfit {
        var rng = SeededRandom(seed: seed)
        let kind = rng.pick(Kind.allCases)
        let skin = RGBA(hex: rng.pick(skins))
        let bag = RGBA(hex: rng.pick(bags))
        switch kind {
        case .member:
            let jumper = rng.pick(jumpers)
            return Outfit(kind: kind, shirt: RGBA(hex: jumper), trim: RGBA(hex: rng.pick(jumpers.filter { $0 != jumper })),
                          pattern: rng.unit() < 0.55 ? .argyle : .plain, trousers: RGBA(hex: rng.pick(slacks)),
                          shoes: RGBA(hex: "#6B4226"), skin: skin, hair: RGBA(hex: rng.pick(hairs + greys)),
                          hairStyle: rng.unit() < 0.3 ? .bald : .short, hat: rng.unit() < 0.6 ? .flatCap : .none,
                          hatColour: RGBA(hex: rng.pick(["#7A6A4F", "#5E5A4A", "#8C7A5B", "#4A4E3E"])), bag: bag,
                          build: 0.95 + rng.unit() * 0.15)
        case .youngGun:
            let shirt = rng.pick(brights)
            return Outfit(kind: kind, shirt: RGBA(hex: shirt), trim: RGBA(hex: "#F4F2EC"), pattern: .polo,
                          trousers: RGBA(hex: rng.pick(["#1F1F24", "#E8E2D2", "#5A5F66", "#2B3550"])),
                          shoes: RGBA(hex: "#F4F2EC"), skin: skin, hair: RGBA(hex: rng.pick(hairs)), hairStyle: .short,
                          hat: rng.unit() < 0.7 ? .cap : .none, hatColour: RGBA(hex: rng.pick(["#F4F2EC", "#1F1F24", shirt])), bag: bag,
                          build: 0.85 + rng.unit() * 0.08)
        case .hacker:
            return Outfit(kind: kind, shirt: RGBA(hex: rng.pick(rugby)), trim: RGBA(hex: rng.pick(["#F2C230", "#F4F2EC", "#D94F3D"])),
                          pattern: rng.unit() < 0.6 ? .hoops : .plain, trousers: RGBA(hex: rng.pick(["#2B3550", "#3A4A5E", "#5A5F66"])),
                          shoes: RGBA(hex: "#2A2A2A"), skin: skin, hair: RGBA(hex: rng.pick(hairs)),
                          hairStyle: rng.unit() < 0.25 ? .bald : .short, hat: rng.pick([.bucket, .bobble, .none, .cap]),
                          hatColour: RGBA(hex: rng.pick(rugby + ["#F2C230"])), bag: bag, build: 1.08 + rng.unit() * 0.12)
        case .lady:
            let shirt = rng.pick(brights + ["#F4F2EC", "#F2B5C4"])
            return Outfit(kind: kind, shirt: RGBA(hex: shirt), trim: RGBA(hex: rng.pick(["#F4F2EC", "#2B3550"])), pattern: .polo,
                          trousers: RGBA(hex: rng.pick(["#F4F2EC", "#2B3550", "#C9B48A", "#1F1F24"])),
                          shoes: RGBA(hex: "#F4F2EC"), skin: skin, hair: RGBA(hex: rng.pick(hairs)), hairStyle: .long,
                          hat: rng.unit() < 0.65 ? .visor : .none, hatColour: RGBA(hex: rng.pick(["#F4F2EC", shirt, "#2B3550"])), bag: bag,
                          build: 0.85 + rng.unit() * 0.08)
        case .pensioner:
            return Outfit(kind: kind, shirt: RGBA(hex: rng.pick(cardigans)), trim: RGBA(hex: "#EDE8DC"), pattern: .plain,
                          trousers: RGBA(hex: rng.pick(["#5A5F66", "#C9B48A", "#6B5A45", "#2B3550"])), shoes: RGBA(hex: "#3A2A1E"),
                          skin: skin, hair: RGBA(hex: rng.pick(greys)), hairStyle: rng.unit() < 0.4 ? .bald : .short,
                          hat: rng.unit() < 0.5 ? .flatCap : .none, hatColour: RGBA(hex: rng.pick(["#7A6A4F", "#5E5A4A", "#6B6B5E"])), bag: bag,
                          build: 1.0 + rng.unit() * 0.12)
        }
    }

    // MARK: Drawing a pose (for previews; the game builds SpriteKit nodes from the same numbers)

    /// Draw instructions for one pose, y down, with the feet at `origin`.
    public static func draw(_ pose: Pose, outfit: Outfit, at origin: ArtPoint, putter: Bool = false) -> [DrawOp] {
        var ops: [DrawOp] = []
        let ink = RGBA(hex: "#1E2420")
        let w = outfit.build
        func transform(_ p: ArtPoint, part: Part) -> ArtPoint {
            // Rotate about the part's pivot (anticlockwise, y up), lift, then flip to y down at origin.
            var pv = GolferRig.pivot(part)
            if part == .legLeft || part == .legRight { pv = ArtPoint(pv.x * w, pv.y) }
            var a = pose.angle(part)
            if part == .arms || part == .head {
                // Arms and head ride on the torso.
                let t = pose.torso
                let tp = GolferRig.pivot(.torso)
                let rx = pv.x - tp.x, ry = pv.y - tp.y
                pv = ArtPoint(tp.x + rx * cos(t) - ry * sin(t), tp.y + rx * sin(t) + ry * cos(t))
                a += t
            }
            let x = pv.x + p.x * cos(a) - p.y * sin(a)
            let y = pv.y + p.x * sin(a) + p.y * cos(a) + pose.lift
            return ArtPoint(origin.x + x, origin.y - y)
        }
        func polygon(_ pts: [ArtPoint], part: Part) -> ArtPath {
            ArtPath(loops: [pts.map { transform($0, part: part) }])
        }
        func capsule(width cw: Double, length l: Double) -> [ArtPoint] {
            // A capsule hanging straight down from the pivot.
            var pts: [ArtPoint] = []
            let r = cw / 2
            for k in 0...6 { let a = Double.pi + Double(k) / 6 * Double.pi; pts.append(ArtPoint(cos(a) * r, -l + r + sin(a) * r)) }
            for k in 0...6 { let a = Double(k) / 6 * Double.pi; pts.append(ArtPoint(cos(a) * r, -r * 0.2 + sin(a) * r * 0.2)) }
            return pts
        }
        func darker(_ c: RGBA, _ f: Double) -> RGBA { RGBA(r: c.r * f, g: c.g * f, b: c.b * f, a: c.a) }

        // Shadow on the ground.
        ops.append(.ellipse(centre: ArtPoint(origin.x + 2, origin.y + 0.3), rx: 7.5 * w, ry: 2.2, ArtStyle.shared.shadow))

        // Bag: on the back while walking, otherwise stood on the ground beside the golfer.
        func bag(at base: ArtPoint, tilt: Double) -> [DrawOp] {
            func rot(_ x: Double, _ y: Double) -> ArtPoint { ArtPoint(base.x + x * cos(tilt) + y * sin(tilt), base.y - (-x * sin(tilt) + y * cos(tilt))) }
            var o: [DrawOp] = []
            // Club heads poking out of the top.
            for (k, dx) in [-1.3, 0.0, 1.3].enumerated() {
                let tip = rot(dx + Double(k - 1) * 0.6, 12.2 + Double(k % 2) * 0.8)
                o.append(.stroke(ArtPath(loops: [[rot(dx, 10.5), tip, rot(dx, 10.5)]]), RGBA(hex: "#5A5F66"), width: 0.7))
                o.append(.ellipse(centre: tip, rx: 0.9, ry: 0.7, RGBA(hex: k == 1 ? "#3A3A3A" : "#A9AEB3")))
            }
            o.append(.fill(ArtPath(loops: [[rot(-2.2, 0), rot(2.2, 0), rot(2.4, 10.8), rot(-2.4, 10.8)]]), outfit.bag))
            o.append(.fill(ArtPath(loops: [[rot(-2.5, 9.6), rot(2.5, 9.6), rot(2.5, 11.0), rot(-2.5, 11.0)]]), darker(outfit.bag, 0.7)))
            o.append(.fill(ArtPath(loops: [[rot(0.6, 2), rot(2.2, 2), rot(2.25, 6), rot(0.6, 6)]]), darker(outfit.bag, 0.8)))
            o.append(.stroke(ArtPath(loops: [[rot(-2.2, 0), rot(2.2, 0), rot(2.4, 10.8), rot(-2.4, 10.8)]]), ink.opacity(0.45), width: 0.4))
            return o
        }
        if pose.carriesBag {
            let back = transform(ArtPoint(-3.4 * w, 1.5), part: .torso)
            ops += bag(at: back, tilt: 0.6 + pose.torso)
        } else {
            ops += bag(at: ArtPoint(origin.x + 12, origin.y - 0.4), tilt: -0.12)
        }

        // Legs, with a crease and shoes.
        for leg in [Part.legLeft, .legRight] {
            let lw = 3.2 * min(1.1, w)
            ops.append(.fill(polygon(capsule(width: lw, length: hip), part: leg), outfit.trousers))
            ops.append(.fill(polygon([ArtPoint(0.3, -1), ArtPoint(lw / 2, -1), ArtPoint(lw / 2, -hip + 1.4), ArtPoint(0.3, -hip + 1.4)], part: leg),
                             darker(outfit.trousers, 0.82)))
            let shoe = [ArtPoint(-1.9, -hip), ArtPoint(2.8, -hip), ArtPoint(2.6, -hip + 1.5), ArtPoint(-1.9, -hip + 1.5)]
            ops.append(.fill(polygon(shoe, part: leg), outfit.shoes))
            if outfit.kind == .member {
                ops.append(.fill(polygon([ArtPoint(-1.9, -hip), ArtPoint(0.2, -hip), ArtPoint(0.2, -hip + 1.5), ArtPoint(-1.9, -hip + 1.5)], part: leg),
                                 RGBA(hex: "#F4F2EC")))
            }
            ops.append(.stroke(polygon(shoe, part: leg), ink.opacity(0.5), width: 0.35))
        }

        // Torso: shape, shading, pattern, collar, belt.
        let tw = 9.0 * w, th = 10.5
        let belly = outfit.build > 1.1 ? 0.8 : 0
        let body = [ArtPoint(-tw / 2 + 0.3, 0), ArtPoint(tw / 2 - 0.3, 0), ArtPoint(tw / 2 + belly, th * 0.4), ArtPoint(tw / 2 - 0.4, th),
                    ArtPoint(-tw / 2 + 0.4, th), ArtPoint(-tw / 2 - belly * 0.3, th * 0.4)]
        ops.append(.fill(polygon(body, part: .torso), outfit.shirt))
        ops.append(.clip(polygon(body, part: .torso)))
        switch outfit.pattern {
        case .argyle:
            for row in 0..<3 {
                for col in -2...2 {
                    let cx = Double(col) * 2.6 + (row % 2 == 0 ? 0 : 1.3), cy = 2 + Double(row) * 2.6
                    ops.append(.fill(polygon([ArtPoint(cx, cy - 1.3), ArtPoint(cx + 1.3, cy), ArtPoint(cx, cy + 1.3), ArtPoint(cx - 1.3, cy)], part: .torso),
                                     (row + col) % 2 == 0 ? outfit.trim : darker(outfit.shirt, 0.8)))
                }
            }
        case .hoops:
            for k in 0..<3 {
                let y = 2.0 + Double(k) * 3
                ops.append(.fill(polygon([ArtPoint(-tw, y), ArtPoint(tw, y), ArtPoint(tw, y + 1.3), ArtPoint(-tw, y + 1.3)], part: .torso), outfit.trim))
            }
        case .polo, .plain:
            break
        }
        // Shade the side away from the light.
        ops.append(.fill(polygon([ArtPoint(tw * 0.18, -1), ArtPoint(tw, -1), ArtPoint(tw, th + 1), ArtPoint(tw * 0.25, th + 1)], part: .torso),
                         RGBA(hex: "#000000", opacity: 0.13)))
        ops.append(.endClip)
        // Belt.
        ops.append(.fill(polygon([ArtPoint(-tw / 2 + 0.3, 0), ArtPoint(tw / 2 - 0.3, 0), ArtPoint(tw / 2 - 0.3, 0.9), ArtPoint(-tw / 2 + 0.3, 0.9)], part: .torso),
                         RGBA(hex: "#2A2420")))
        // Collar.
        switch outfit.kind {
        case .member, .pensioner:
            ops.append(.fill(polygon([ArtPoint(-1.6, th), ArtPoint(1.6, th), ArtPoint(0, th - 2.4)], part: .torso), RGBA(hex: "#F4F2EC")))
        default:
            ops.append(.fill(polygon([ArtPoint(-2.2, th + 0.3), ArtPoint(0, th - 1.2), ArtPoint(2.2, th + 0.3), ArtPoint(0, th - 0.2)], part: .torso),
                             outfit.pattern == .polo ? outfit.trim : darker(outfit.shirt, 0.75)))
        }
        if pose.carriesBag {
            // Bag strap across the chest.
            ops.append(.stroke(ArtPath(loops: [[transform(ArtPoint(tw / 2 - 0.8, th - 0.4), part: .torso), transform(ArtPoint(-tw / 2 + 0.2, 1.8), part: .torso)]]),
                               darker(outfit.bag, 0.6), width: 0.8))
        }
        ops.append(.stroke(polygon(body, part: .torso), ink.opacity(0.4), width: 0.4))

        // Head: hair at the back first (ponytail), face, ears, hair on top, hat.
        let head = transform(ArtPoint(0, 2.6), part: .head)
        if outfit.hairStyle == .long {
            ops.append(.ellipse(centre: ArtPoint(head.x - 3.2, head.y + 0.4), rx: 1.5, ry: 2.8, outfit.hair))
        }
        ops.append(.ellipse(centre: head, rx: 3.4, ry: 3.6, outfit.skin))
        ops.append(.ellipse(centre: ArtPoint(head.x + 1.2, head.y + 0.6), rx: 2.0, ry: 2.6, RGBA(hex: "#000000", opacity: 0.08)))
        ops.append(.ellipse(centre: ArtPoint(head.x - 3.2, head.y + 0.2), rx: 0.7, ry: 1.0, darker(outfit.skin, 0.9)))
        switch outfit.hairStyle {
        case .short, .long:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 1.8), rx: 3.4, ry: 2.0, outfit.hair))
        case .bald:
            ops.append(.ellipse(centre: ArtPoint(head.x - 2.6, head.y - 0.3), rx: 1.0, ry: 1.4, outfit.hair))
            ops.append(.ellipse(centre: ArtPoint(head.x - 0.6, head.y - 2.4), rx: 1.1, ry: 0.6, RGBA(hex: "#FFFFFF", opacity: 0.35)))
        }
        ops.append(.stroke(ArtPath(loops: [ellipsePoints(head, 3.4, 3.6)]), ink.opacity(0.35), width: 0.35))
        switch outfit.hat {
        case .none: break
        case .cap:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.2), rx: 3.6, ry: 2.1, outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x + 2.6, head.y - 1.1), rx: 2.2, ry: 0.8, darker(outfit.hatColour, 0.85)))
            ops.append(.ellipse(centre: ArtPoint(head.x - 0.2, head.y - 4.1), rx: 0.5, ry: 0.4, darker(outfit.hatColour, 0.7)))
        case .flatCap:
            ops.append(.ellipse(centre: ArtPoint(head.x + 0.4, head.y - 2.0), rx: 4.1, ry: 1.8, outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x + 2.8, head.y - 1.5), rx: 1.8, ry: 0.7, darker(outfit.hatColour, 0.8)))
            ops.append(.stroke(ArtPath(loops: [[ArtPoint(head.x - 3, head.y - 2.6), ArtPoint(head.x + 3, head.y - 2.6)]]), darker(outfit.hatColour, 0.75), width: 0.3))
        case .bucket:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 1.2), rx: 4.8, ry: 1.2, darker(outfit.hatColour, 0.85)))
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.6), rx: 3.4, ry: 2.0, outfit.hatColour))
        case .bobble:
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 2.4), rx: 3.6, ry: 2.4, outfit.hatColour))
            ops.append(.fill(.rect(head.x - 3.6, head.y - 1.4, 7.2, 1.1), outfit.trim))
            ops.append(.ellipse(centre: ArtPoint(head.x, head.y - 5.2), rx: 1.4, ry: 1.4, RGBA(hex: "#F4F0E6")))
        case .visor:
            ops.append(.fill(.rect(head.x - 3.5, head.y - 2.6, 7.0, 1.2), outfit.hatColour))
            ops.append(.ellipse(centre: ArtPoint(head.x + 2.7, head.y - 1.6), rx: 2.3, ry: 0.8, darker(outfit.hatColour, 0.85)))
        }

        // Arms (both hands on the grip), a glove on the lead hand, and the club.
        let hands = ArtPoint(0, -8.5)
        let leftShoulder = ArtPoint(-3.6 * w, 0), rightShoulder = ArtPoint(3.6 * w, 0)
        let sleeve = outfit.kind == .youngGun || outfit.kind == .lady ? outfit.skin : outfit.shirt
        for (k, s) in [leftShoulder, rightShoulder].enumerated() {
            let dx = hands.x - s.x, dy = hands.y - s.y
            let len = max(0.01, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / len * 1.2, ny = dx / len * 1.2
            let arm = [ArtPoint(s.x + nx, s.y + ny), ArtPoint(hands.x + nx * 0.7, hands.y + ny * 0.7),
                       ArtPoint(hands.x - nx * 0.7, hands.y - ny * 0.7), ArtPoint(s.x - nx, s.y - ny)]
            ops.append(.fill(polygon(arm, part: .arms), sleeve))
            if sleeve != outfit.shirt {
                // Short sleeves: the shirt covers the top third of the arm.
                let mid = ArtPoint(s.x + dx * 0.35, s.y + dy * 0.35)
                ops.append(.fill(polygon([ArtPoint(s.x + nx * 1.15, s.y + ny * 1.15), ArtPoint(mid.x + nx * 1.1, mid.y + ny * 1.1),
                                          ArtPoint(mid.x - nx * 1.1, mid.y - ny * 1.1), ArtPoint(s.x - nx * 1.15, s.y - ny * 1.15)], part: .arms),
                                 outfit.shirt))
            }
            ops.append(.stroke(polygon(arm, part: .arms), ink.opacity(k == 0 ? 0.3 : 0.2), width: 0.3))
        }
        let length = putter ? clubLength * 0.75 : clubLength
        let clubEnd = transform(ArtPoint(0.8, hands.y - length), part: .arms)
        let clubStart = transform(ArtPoint(0, hands.y + 1.2), part: .arms)
        ops.append(.stroke(ArtPath(loops: [[clubStart, clubEnd, clubStart]]), RGBA(hex: "#4A4F55"), width: 0.9))
        ops.append(.stroke(ArtPath(loops: [[clubStart, transform(ArtPoint(0.15, hands.y - 1.5), part: .arms), clubStart]]),
                           RGBA(hex: "#1F1F24"), width: 1.2))
        ops.append(.ellipse(centre: transform(hands, part: .arms), rx: 1.6, ry: 1.6, RGBA(hex: "#F4F2EC")))
        ops.append(.ellipse(centre: transform(ArtPoint(0, hands.y - 1.1), part: .arms), rx: 1.3, ry: 1.3, outfit.skin))
        if putter {
            ops.append(.fill(ArtPath(loops: [[ArtPoint(clubEnd.x - 1.8, clubEnd.y - 0.6), ArtPoint(clubEnd.x + 1.8, clubEnd.y - 0.6),
                                              ArtPoint(clubEnd.x + 1.8, clubEnd.y + 0.6), ArtPoint(clubEnd.x - 1.8, clubEnd.y + 0.6)]]),
                             RGBA(hex: "#8C9196")))
        } else {
            ops.append(.ellipse(centre: clubEnd, rx: 1.4, ry: 0.95, RGBA(hex: "#A9AEB3")))
            ops.append(.ellipse(centre: ArtPoint(clubEnd.x + 0.3, clubEnd.y + 0.2), rx: 0.8, ry: 0.5, RGBA(hex: "#6E737A")))
        }
        return ops
    }

    private static func ellipsePoints(_ c: ArtPoint, _ rx: Double, _ ry: Double) -> [ArtPoint] {
        (0..<20).map { k in
            let a = Double(k) / 20 * 2 * .pi
            return ArtPoint(c.x + cos(a) * rx, c.y + sin(a) * ry)
        }
    }
}
