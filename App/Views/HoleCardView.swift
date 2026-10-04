import GameCore
import SwiftUI

/// Rating, detected features, fairness and the most useful tip for one hole,
/// plus the course design score. The Milestone 2 hole card grows from this.
struct HoleCardView: View {
    let design: CourseDesign
    let holeIndex: Int

    private var analysis: HoleAnalysis { design.holes[holeIndex] }
    private var effective: Double { design.effectiveHoleScores[holeIndex] }
    private var repeats: [RepeatedFeature] { design.repeats.filter { $0.hole == holeIndex } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hole \(holeIndex + 1)").font(.headline)
                if analysis.isPlayable {
                    Text("Par \(analysis.par) · \(Int(analysis.yards.rounded())) yards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if design.signatureHole == holeIndex {
                    Label("Signature hole", systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color(uiColor: PlaceholderPalette.rating(9)))
                }
                Text(effective > 0 ? String(format: "%.1f", effective) : "·")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(Color(uiColor: PlaceholderPalette.rating(effective)))
            }

            if !analysis.isPlayable {
                Text("Not playable yet: it needs a tee, a pin on a green, and 80 yards or more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(analysis.features.enumerated()), id: \.offset) { _, feature in
                        Text(feature.points > 0 ? feature.name : "\(feature.name) \(String(format: "%.1f", feature.points))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(feature.points > 0 ? Color.green.opacity(0.18) : Color.red.opacity(0.18), in: Capsule())
                    }
                    Text("\(analysis.fairness.band.rawValue) for golfers")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(fairnessColour.opacity(0.2), in: Capsule())
                }

                ForEach(Array(repeats.enumerated()), id: \.offset) { _, r in
                    Text("\(ordinal(r.occurrence)) \(r.kind.name.lowercased()) on this course: worth \(Int((r.valueShare * 100).rounded()))% here.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if effective != analysis.score {
                    Text(String(format: "Rated %.1f on its own.", analysis.score))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let tip = analysis.tips.first {
                    Label(tip, systemImage: "lightbulb")
                        .font(.subheadline)
                }
            }

            Divider()
            HStack {
                Text("Course design")
                Spacer()
                Text(String(format: "%.1f", design.score)).bold().monospacedDigit()
                Text(design.word).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var fairnessColour: Color {
        switch analysis.fairness.band {
        case .fair: .green
        case .testing: .orange
        case .brutal: .red
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

/// Lays chips out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
