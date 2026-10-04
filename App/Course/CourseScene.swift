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
    func show(_ hole: Hole, land: LandKind, resetCamera: Bool) {
        columns = hole.columns
        rows = hole.rows
        let texture = SKTexture(image: Self.render(hole, land: land))
        texture.filteringMode = .nearest
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

    /// Flat placeholder art: one coloured square per tile.
    private static func render(_ hole: Hole, land: LandKind) -> UIImage {
        let px: CGFloat = 8
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let size = CGSize(width: CGFloat(hole.columns) * px, height: CGFloat(hole.rows) * px)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for y in 0..<hole.rows {
                for x in 0..<hole.columns {
                    guard let t = hole[x, y] else { continue }
                    let variant = (x * 7 + y * 13) % 5 == 0 || (t == .fairway && y % 2 == 0)
                    PlaceholderPalette.colour(for: t, land: land, variant: variant).setFill()
                    ctx.fill(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px, width: px, height: px))
                }
            }
        }
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
