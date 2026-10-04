import Foundation

/// A feature that has already appeared too often on this course, so it counts for less.
public struct RepeatedFeature: Equatable, Sendable {
    public let hole: Int
    public let kind: FeatureKind
    /// 4 means "the 4th island green on the course".
    public let occurrence: Int
    /// Share of its normal value it still earns, e.g. 0.6.
    public let valueShare: Double
}

public struct CourseDesign: Equatable, Sendable {
    /// 0 to 10, one decimal place.
    public let score: Double
    public let word: String
    /// Each hole's analysis on its own.
    public let holes: [HoleAnalysis]
    /// Each hole's rating once repeats elsewhere on the course are taken into account.
    public let effectiveHoleScores: [Double]
    public let repeats: [RepeatedFeature]
    /// Index of the signature hole (best hole, 7.5 or more), if any.
    public let signatureHole: Int?
    public let featureKinds: Int
    public let brutalHoles: Int
}

public struct CourseDesigner: Sendable {
    public let balance: Balance
    private var analyzer: HoleAnalyzer { HoleAnalyzer(balance: balance) }
    private var rules: HoleRules { HoleRules(balance: balance) }

    public init(balance: Balance) {
        self.balance = balance
    }

    public func design(of holes: [Hole]) -> CourseDesign {
        let d = balance.design
        let analyses = holes.map(analyzer.analyze)
        let n = analyses.count
        guard n > 0 else {
            return CourseDesign(score: 0, word: word(for: 0), holes: [], effectiveHoleScores: [], repeats: [],
                                signatureHole: nil, featureKinds: 0, brutalHoles: 0)
        }

        // Repetition: each kind is free on holes/6 holes (at least one); later ones decay.
        let allowance = max(1, n / d.repetition.holesPerFreeRepeat)
        var seen: [FeatureKind: Int] = [:]
        var repeats: [RepeatedFeature] = []
        var effective: [Double] = []
        for (i, analysis) in analyses.enumerated() {
            guard analysis.isPlayable else {
                effective.append(0)
                continue
            }
            var scaled: [Double] = []
            for feature in analysis.features where feature.points > 0 {
                let occurrence = (seen[feature.kind] ?? 0) + 1
                seen[feature.kind] = occurrence
                var share = 1.0
                if occurrence > allowance {
                    share = pow(d.repetition.decay, Double(occurrence - allowance))
                    repeats.append(RepeatedFeature(hole: i, kind: feature.kind, occurrence: occurrence, valueShare: share))
                }
                scaled.append(feature.points * share)
            }
            let negatives = analysis.features.filter { $0.points < 0 }.map(\.points) + [-analysis.fairness.penalty]
            effective.append(HoleAnalyzer.score(base: analysis.baseScore, positives: scaled, negatives: negatives, balance: balance))
        }

        let average = effective.reduce(0, +) / Double(n)
        let kinds = Set(analyses.flatMap(\.positiveKinds)).count
        let pars = Set(zip(holes, analyses).filter { $0.1.isPlayable }.map { $0.1.par })
        let parBonus = pars.count >= 3 ? d.allParsBonus : pars.count == 1 ? d.singleParPenalty : 0
        let best = effective.max() ?? 0
        let bestIndex = effective.firstIndex(of: best)
        let brutal = analyses.filter { $0.fairness.band == .brutal }.count
        let brutalPenalty = Double(brutal) / Double(n) > d.brutalShareLimit ? d.brutalCoursePenalty : 0

        var score = average * d.averageWeight
            + min(d.maxFeatureKindBonus, Double(kinds) * d.pointsPerFeatureKind)
            + parBonus
            + (best >= d.bestHoleBonusFrom ? d.bestHoleBonus : 0)
            - brutalPenalty
        score = (min(10, max(0, score)) * 10).rounded() / 10

        return CourseDesign(
            score: score, word: word(for: score), holes: analyses, effectiveHoleScores: effective,
            repeats: repeats, signatureHole: best >= d.signatureFrom ? bestIndex : nil,
            featureKinds: kinds, brutalHoles: brutal
        )
    }

    public func word(for score: Double) -> String {
        balance.design.words.first { score >= $0.from }?.word ?? "Basic"
    }

    /// Total length in yards, for event requirements.
    public func yards(of holes: [Hole]) -> Int {
        Int(holes.reduce(0) { $0 + rules.yards($1) }.rounded())
    }

    public func par(of holes: [Hole]) -> Int {
        holes.reduce(0) { $0 + (rules.isPlayable($1) ? rules.par($1) : 0) }
    }
}
