/// Everything golfers notice about a course's layout, worked out once and reused
/// for every round until the holes change.
public struct CourseQuality: Equatable, Sendable {
    public let design: CourseDesign
    /// Per hole average, 0 to about 1.3: bunkers, water and trees to think about.
    public let interest: Double
    /// Per hole average, 0 to about 0.9: trees and water to look at.
    public let beauty: Double
    /// +0.3 for all three pars, 0 for two, -0.3 for one.
    public let variety: Double
    /// Holes under 100 yards, or long holes with almost no fairway.
    public let weakHoles: Int
    public let par: Int
    public let yards: Int

    public static func of(_ holes: [Hole], balance: Balance) -> CourseQuality {
        let q = balance.quality
        let rules = HoleRules(balance: balance)
        var interest = 0.0, beauty = 0.0, weak = 0, par = 0, yards = 0.0
        var pars = Set<Int>()
        for hole in holes {
            let b = Double(hole.count(of: .bunker)), w = Double(hole.count(of: .water)), t = Double(hole.count(of: .trees))
            interest += min(1, b / q.interestBunkerTiles) * q.interestBunker
                + min(1, w / q.interestWaterTiles) * q.interestWater
                + min(1, t / q.interestTreeTiles) * q.interestTrees
            beauty += min(1, t / q.beautyTreeTiles) * q.beautyTrees + min(1, w / q.beautyWaterTiles) * q.beautyWater
            let p = rules.par(hole), y = rules.yards(hole)
            par += p
            yards += y
            pars.insert(p)
            if y < q.weakUnderYards || (p > 3 && hole.count(of: .fairway) < q.weakMinFairwayTiles) { weak += 1 }
        }
        let n = Double(max(1, holes.count))
        return CourseQuality(
            design: CourseDesigner(balance: balance).design(of: holes),
            interest: interest / n,
            beauty: beauty / n,
            variety: pars.count >= 3 ? q.varietyAllPars : pars.count == 2 ? q.varietyTwoPars : q.varietyOnePar,
            weakHoles: weak,
            par: par,
            yards: Int(yards.rounded())
        )
    }
}
