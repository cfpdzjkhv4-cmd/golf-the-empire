import UIKit

/// The one place the game loads art from. Everything is asked for by manifest id;
/// no other file in the app knows a file name or path.
@MainActor
final class AssetLibrary {
    static let shared = AssetLibrary()

    struct Entry: Decodable, Identifiable, Hashable {
        let id: String
        let category: String
        let description: String
        let sizePt: String
        let frames: String
        let variants: String
        let format: String
        let priority: String
        let source: String
        let notes: String
        /// image, audio, capture or cut.
        let kind: String
        /// placeholder, final, missing or cut.
        let status: String
    }

    private struct Index: Decodable {
        let assets: [Entry]
    }

    let entries: [Entry]
    private var cache: [String: UIImage] = [:]

    private init() {
        if let url = Bundle.main.url(forResource: "asset_index", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let index = try? JSONDecoder().decode(Index.self, from: data) {
            entries = index.assets
        } else {
            entries = []
        }
    }

    var categories: [String] {
        var seen: [String] = []
        for e in entries where !seen.contains(e.category) { seen.append(e.category) }
        return seen
    }

    func entry(_ id: String) -> Entry? { entries.first { $0.id == id } }

    /// The image for a manifest id. Never nil: anything not yet made draws a labelled stand in.
    func image(_ id: String) -> UIImage {
        if let cached = cache[id] { return cached }
        let image = UIImage(named: id) ?? missingImage(id)
        cache[id] = image
        return image
    }

    private func missingImage(_ id: String) -> UIImage {
        let size = CGSize(width: 96, height: 96)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.systemRed.setStroke()
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.stroke(CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
            let text = NSAttributedString(string: id, attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.label,
            ])
            text.draw(in: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12))
        }
    }
}
