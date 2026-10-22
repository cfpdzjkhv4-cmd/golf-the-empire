import CourseArt
import GameCore
import UIKit

/// Draws CourseArt's instructions with CoreGraphics. All the art decisions live in CourseArt;
/// this file only knows how to follow them.
enum HoleImageRenderer {
    /// `pointsPerTile` sets the detail; the scene stretches the image over the hole.
    static func image(for hole: Hole, land: LandKind, seed: UInt64, pointsPerTile: CGFloat = 16) -> UIImage {
        let ops = HoleArtist().paint(hole, land: land, seed: seed)
        let size = CGSize(width: CGFloat(hole.columns) * pointsPerTile, height: CGFloat(hole.rows) * pointsPerTile)
        return render(ops, size: size, unit: pointsPerTile, opaque: true)
    }

    /// Follows draw instructions into an image. `unit` is points per instruction unit.
    static func render(_ ops: [DrawOp], size: CGSize, unit: CGFloat, opaque: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.scaleBy(x: unit, y: unit)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            for op in ops {
                switch op {
                case .fill(let path, let colour):
                    cg.addPath(cgPath(path))
                    cg.setFillColor(cgColour(colour))
                    cg.fillPath(using: .evenOdd)
                case .stroke(let path, let colour, let width):
                    cg.addPath(cgPath(path))
                    cg.setStrokeColor(cgColour(colour))
                    cg.setLineWidth(width)
                    cg.strokePath()
                case .ellipse(let centre, let rx, let ry, let colour):
                    cg.setFillColor(cgColour(colour))
                    cg.fillEllipse(in: CGRect(x: centre.x - rx, y: centre.y - ry, width: rx * 2, height: ry * 2))
                case .clip(let path):
                    cg.saveGState()
                    cg.addPath(cgPath(path))
                    cg.clip(using: .evenOdd)
                case .endClip:
                    cg.restoreGState()
                }
            }
        }
    }

    /// A seed that stays the same for a hole however it is edited, and between launches.
    static func seed(plotID: String, hole: Int) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in plotID.utf8 { h = (h ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return h &+ UInt64(hole) &* 0x9E37_79B9_7F4A_7C15
    }

    private static func cgPath(_ path: ArtPath) -> CGPath {
        let p = CGMutablePath()
        for loop in path.loops {
            guard let first = loop.first else { continue }
            p.move(to: CGPoint(x: first.x, y: first.y))
            for pt in loop.dropFirst() { p.addLine(to: CGPoint(x: pt.x, y: pt.y)) }
            p.closeSubpath()
        }
        return p
    }

    private static func cgColour(_ c: RGBA) -> CGColor {
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }
}
