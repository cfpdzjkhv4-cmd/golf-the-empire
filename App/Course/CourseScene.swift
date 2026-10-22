import CourseArt
import GameCore
import SpriteKit
import UIKit

/// Draws one hole and moves a camera over it.
///
/// The hole is tall and narrow, so instead of shrinking it to fit the screen the camera
/// fills the width and starts at the tee; drag to look up the hole, pinch to zoom.
/// In paint mode one finger paints and two fingers move the camera.
@MainActor
final class CourseScene: SKScene {
    var onPaint: ((GridPoint) -> Void)?
    var onStrokeEnded: (() -> Void)?
    /// +1 for the next hole (swipe left), -1 for the previous one.
    var onSwipe: ((Int) -> Void)?

    var paintMode = false {
        didSet { pan?.minimumNumberOfTouches = paintMode ? 2 : 1 }
    }

    /// World units per tile. The camera's scale does the zooming.
    private let tile: CGFloat = 24
    private let cameraNode = SKCameraNode()
    private let holeNode = SKSpriteNode()
    private let teeMarker = SKShapeNode(rectOf: CGSize(width: 14, height: 8), cornerRadius: 2)
    private let flag = SKNode()
    private var columns = 16
    private var rows = 32
    private var teeWorld = CGPoint.zero
    private var pan: UIPanGestureRecognizer?
    private var pinch: UIPinchGestureRecognizer?
    private var lastPainted: GridPoint?
    private var painting = false

    // Watch a round
    private let ball = SKShapeNode(circleOfRadius: 3)
    private let ballShadow = SKShapeNode(ellipseOf: CGSize(width: 6, height: 3))
    private lazy var golfer = GolferSprite(heightInWorld: tile * 1.15)
    private var pendingShot: CheckedContinuation<Void, Never>?

    private var worldSize: CGSize { CGSize(width: CGFloat(columns) * tile, height: CGFloat(rows) * tile) }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x2F4A2A)
        addChild(cameraNode)
        camera = cameraNode
        addChild(holeNode)

        teeMarker.fillColor = .white
        teeMarker.strokeColor = UIColor(white: 0.3, alpha: 1)
        teeMarker.zPosition = 2
        addChild(teeMarker)

        let pole = SKShapeNode(rectOf: CGSize(width: 2, height: 30))
        pole.fillColor = .white
        pole.strokeColor = .clear
        pole.position = CGPoint(x: 0, y: 15)
        let pennant = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 1, y: 30))
            p.addLine(to: CGPoint(x: 15, y: 25))
            p.addLine(to: CGPoint(x: 1, y: 20))
            p.closeSubpath()
            return p
        }())
        pennant.fillColor = UIColor(hex: 0xF2C230)
        pennant.strokeColor = .clear
        flag.addChild(pole)
        flag.addChild(pennant)
        flag.zPosition = 3
        addChild(flag)

        ball.fillColor = .white
        ball.strokeColor = UIColor(white: 0.25, alpha: 1)
        ball.lineWidth = 0.75
        ball.zPosition = 6
        ballShadow.fillColor = UIColor(white: 0, alpha: 0.3)
        ballShadow.strokeColor = .clear
        ballShadow.zPosition = 5
        golfer.zPosition = 4
        for node in [ball, ballShadow, golfer] {
            node.isHidden = true
            addChild(node)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("CourseScene is built in code")
    }

    override func didMove(to view: SKView) {
        guard pan == nil else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = paintMode ? 2 : 1
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
        self.pan = pan
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        self.pinch = pinch
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        cameraNode.setScale(min(max(cameraNode.xScale, minScale), maxScale))
        clampCamera()
    }

    // MARK: Showing a hole

    /// Redraws the hole. With `resetCamera`, jumps back to the tee at full width.
    func show(_ hole: Hole, land: LandKind, seed: UInt64, resetCamera: Bool) {
        columns = hole.columns
        rows = hole.rows
        let texture = SKTexture(image: HoleImageRenderer.image(for: hole, land: land, seed: seed))
        texture.filteringMode = .linear
        holeNode.texture = texture
        holeNode.size = worldSize

        if let tee = hole.tee {
            teeMarker.isHidden = false
            teeMarker.position = world(tee)
            teeWorld = teeMarker.position
        } else {
            teeMarker.isHidden = true
            teeWorld = CGPoint(x: 0, y: -worldSize.height / 2 + tile * 2)
        }
        if let pin = hole.pin {
            flag.isHidden = false
            flag.position = world(pin)
        } else {
            flag.isHidden = true
        }
        if resetCamera { lookFromTee() }
    }

    /// Centre of a grid square in scene coordinates. Row 0 is the far end, at the top.
    private func world(_ p: GridPoint) -> CGPoint {
        CGPoint(
            x: (CGFloat(p.x) + 0.5) * tile - worldSize.width / 2,
            y: worldSize.height / 2 - (CGFloat(p.y) + 0.5) * tile
        )
    }

    private func grid(_ point: CGPoint) -> GridPoint? {
        let x = Int(floor((point.x + worldSize.width / 2) / tile))
        let y = Int(floor((worldSize.height / 2 - point.y) / tile))
        guard x >= 0, y >= 0, x < columns, y < rows else { return nil }
        return GridPoint(x: x, y: y)
    }

    // MARK: Camera

    /// Scale that fits the hole's width with a small margin.
    private var fitScale: CGFloat { (worldSize.width + tile) / max(size.width, 1) }
    private var minScale: CGFloat { fitScale / 3 }
    /// Zoomed out far enough to see the whole hole.
    private var maxScale: CGFloat { max(fitScale, (worldSize.height + tile) / max(size.height, 1)) }

    private func lookFromTee() {
        cameraNode.setScale(fitScale)
        let visible = size.height * fitScale
        cameraNode.position = CGPoint(x: 0, y: teeWorld.y + visible / 2 - tile * 2.5)
        clampCamera()
    }

    private func clampCamera() {
        let scale = cameraNode.xScale
        let halfW = size.width * scale / 2, halfH = size.height * scale / 2
        let maxX = max(0, worldSize.width / 2 - halfW + tile)
        let maxY = max(0, worldSize.height / 2 - halfH + tile)
        cameraNode.position.x = min(max(cameraNode.position.x, -maxX), maxX)
        cameraNode.position.y = min(max(cameraNode.position.y, -maxY), maxY)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let view else { return }
        let t = g.translation(in: view)
        let scale = cameraNode.xScale
        cameraNode.position.x -= t.x * scale
        cameraNode.position.y += t.y * scale
        g.setTranslation(.zero, in: view)
        clampCamera()

        if g.state == .ended && !paintMode {
            let v = g.velocity(in: view)
            if abs(v.x) > 900 && abs(v.x) > abs(v.y) * 2 {
                onSwipe?(v.x < 0 ? 1 : -1)
            }
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard g.scale > 0 else { return }
        let next = cameraNode.xScale / g.scale
        cameraNode.setScale(min(max(next, minScale), maxScale))
        g.scale = 1
        clampCamera()
    }

    // MARK: Watch a round

    private func world(_ v: GridVector) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * tile - worldSize.width / 2, y: worldSize.height / 2 - CGFloat(v.y) * tile)
    }

    /// Dresses the golfer for a new round.
    func dressGolfer(seed: UInt64) {
        golfer.dress(seed: seed)
    }

    /// Puts the golfer and ball on the tee.
    func startRound(at start: GridVector?) {
        guard let start else { return }
        let p = world(start)
        ball.position = p
        ballShadow.position = p
        golfer.removeAllActions()
        golfer.position = CGPoint(x: p.x - 9, y: p.y - 2)
        for node in [ball, ballShadow, golfer] { node.isHidden = false }
        follow(p, duration: 0.6)
    }

    /// Animates one shot: flight with height, bounce and roll, then the golfer walks after it.
    func play(_ shot: Shot) async {
        let from = world(shot.from), landing = world(shot.landing), end = world(shot.end)
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            pendingShot = done
            ball.position = from
            ballShadow.position = from
            ball.isHidden = false
            ballShadow.isHidden = false
            // After a drop or a stroke and distance the ball isn't where the golfer walked to.
            golfer.removeAction(forKey: "walk")
            golfer.removeAction(forKey: "legs")
            golfer.xScale = abs(golfer.xScale)
            golfer.position = CGPoint(x: from.x - 9, y: from.y - 2)
            ball.setScale(1)
            let flight: SKAction
            let shadowFlight: SKAction
            if shot.isPutt {
                let time = 0.5 + Double(hypot(end.x - from.x, end.y - from.y)) / 160
                flight = .move(to: end, duration: time)
                flight.timingMode = .easeOut
                shadowFlight = .move(to: end, duration: time)
                shadowFlight.timingMode = .easeOut
            } else {
                let air = 0.6 + shot.carryYards / 260
                let height = min(2.2, 1 + shot.carryYards / 180)
                let up = SKAction.scale(to: height, duration: air / 2)
                up.timingMode = .easeOut
                let down = SKAction.scale(to: 1, duration: air / 2)
                down.timingMode = .easeIn
                let roll = SKAction.move(to: end, duration: 0.35)
                roll.timingMode = .easeOut
                flight = .sequence([.group([.move(to: landing, duration: air), .sequence([up, down])]), roll])
                shadowFlight = .sequence([.move(to: landing, duration: air), .move(to: end, duration: 0.35)])
            }
            // Swing first, then the ball goes.
            golfer.run(golfer.swingAction(putt: shot.isPutt)) { [weak self] in
                guard let self else { return }
                self.ballShadow.run(shadowFlight)
                self.follow(end, duration: shot.isPutt ? 0.8 : 1.2)
                self.ball.run(flight) { [weak self] in
                    guard let self else { return }
                    if shot.holed {
                        self.ball.isHidden = true
                        self.ballShadow.isHidden = true
                        self.golfer.react(GolferRig.celebrate)
                    } else if shot.outcome == .water || shot.outcome == .outOfBounds {
                        self.golfer.react(GolferRig.despair)
                    } else {
                        let distance = hypot(end.x - self.golfer.position.x, end.y - self.golfer.position.y)
                        self.golfer.walk(to: CGPoint(x: end.x - 9, y: end.y - 2), duration: min(1.3, 0.4 + Double(distance) / 120))
                    }
                    self.finishShot()
                }
            }
        }
    }

    private func finishShot() {
        let done = pendingShot
        pendingShot = nil
        done?.resume()
    }

    /// Hides the ball and golfer, and releases anyone waiting on a shot.
    func clearRound() {
        for node in [ball, ballShadow, golfer] { node.isHidden = true }
        finishShot()
    }

    private func follow(_ point: CGPoint, duration: TimeInterval) {
        let scale = cameraNode.xScale
        let halfW = size.width * scale / 2, halfH = size.height * scale / 2
        let maxX = max(0, worldSize.width / 2 - halfW + tile)
        let maxY = max(0, worldSize.height / 2 - halfH + tile)
        let target = CGPoint(x: min(max(point.x, -maxX), maxX), y: min(max(point.y + halfH * 0.25, -maxY), maxY))
        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        cameraNode.run(move, withKey: "follow")
    }

    // MARK: Painting

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard paintMode, touches.count == 1, let touch = touches.first else { return }
        painting = true
        lastPainted = nil
        paint(at: touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard painting, let touch = touches.first else { return }
        paint(at: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishStroke()
    }

    private func paint(at point: CGPoint) {
        guard let cell = grid(point), cell != lastPainted else { return }
        lastPainted = cell
        onPaint?(cell)
    }

    private func finishStroke() {
        guard painting else { return }
        painting = false
        lastPainted = nil
        onStrokeEnded?()
    }
}
