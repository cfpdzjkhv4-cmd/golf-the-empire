import Foundation

/// Turns draw instructions into SVG, for previews and the asset gallery outside the game.
public enum SVGRenderer {
    public static func svg(_ ops: [DrawOp], width: Double, height: Double, scale: Double) -> String {
        var defs = ""
        var body = ""
        var clipCount = 0
        func path(_ p: ArtPath) -> String {
            p.loops.map { loop in
                guard let first = loop.first else { return "" }
                var d = String(format: "M%.2f %.2f", first.x * scale, first.y * scale)
                for pt in loop.dropFirst() { d += String(format: "L%.2f %.2f", pt.x * scale, pt.y * scale) }
                return d + "Z"
            }.joined()
        }
        func paint(_ c: RGBA) -> String { "fill=\"\(c.hex)\" fill-opacity=\"\(String(format: "%.3f", c.a))\"" }
        for op in ops {
            switch op {
            case .fill(let p, let c):
                body += "<path d=\"\(path(p))\" fill-rule=\"evenodd\" \(paint(c))/>\n"
            case .stroke(let p, let c, let w):
                body += "<path d=\"\(path(p))\" fill=\"none\" stroke=\"\(c.hex)\" stroke-opacity=\"\(String(format: "%.3f", c.a))\" stroke-width=\"\(String(format: "%.2f", w * scale))\" stroke-linejoin=\"round\"/>\n"
            case .ellipse(let centre, let rx, let ry, let c):
                body += String(format: "<ellipse cx=\"%.2f\" cy=\"%.2f\" rx=\"%.2f\" ry=\"%.2f\" ", centre.x * scale, centre.y * scale, rx * scale, ry * scale) + paint(c) + "/>\n"
            case .clip(let p):
                clipCount += 1
                defs += "<clipPath id=\"c\(clipCount)\"><path d=\"\(path(p))\" clip-rule=\"evenodd\"/></clipPath>\n"
                body += "<g clip-path=\"url(#c\(clipCount))\">\n"
            case .endClip:
                body += "</g>\n"
            }
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(width * scale))" height="\(Int(height * scale))" viewBox="0 0 \(Int(width * scale)) \(Int(height * scale))">
        <defs>\(defs)</defs>
        \(body)</svg>
        """
    }
}
