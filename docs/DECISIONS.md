# Decisions log

Decisions made after DESIGN.md version 2, newest first. Where these and DESIGN.md disagree, these win until DESIGN.md is updated.

## October 2026: Milestone 2 art (Claude's calls, flagged to Harry)

1. **Holes are drawn as vector shapes, not tiled textures.** The tile grid is traced into smooth outlines (fairways, greens, bunkers, water, sea) and painted in flat colour with soft shading, light from the top left. This replaces most `tex_*`, `mask_edge_soft`, `ovl_bunker_lip` and `ovl_mowing` manifest rows: those looks are now drawn in code by `CourseArt/HoleArtist.swift`. A fine grain texture may still be added later.
2. **One style guide**, `Packages/GameCore/Sources/CourseArt/Resources/style.json`, read by the game and by every generator.
3. **The golfer rig is drawn face on**, like a TV camera behind the ball, with nine poses blended into animation frames at run time and outfits (shirt, trousers, skin, hair, five hats) chosen per golfer.
4. Art can be reviewed without a phone: `make preview`.
5. **The first hole has a club area below it**: clubhouse (four levels, stone in the north, brick in the south), pro shop, range and a car park that fills up on busy days.
6. **Condition shows**: below 75% the fairways and greens brown and wear patches appear.
8. **Footbridges** (Harry's idea): a Bridge paint tool that only works over water, and an "Island green with a bridge" helper. For the ball and the hole analysis a bridge is still water, so an island green stays an island green.
9. **Zooming**: pinch zooms about your fingers, double tap zooms in on a spot (and back out), and there are zoom buttons on screen for Macs and one handed play.
7. **Sound is synthesised** by `art/audio.py`: 14 effects and 3 ambience loops (birdsong, wind, sea). No music in version 1. Club strikes and applause sound a little thin; free CC0 recordings are the upgrade if wanted (log their licences).

## October 2026: Milestone 2 rules (Claude's calls, flagged to Harry)

1. **Golfers now score like real club golfers.** The prototype's golfers were far too good: ordinary players averaged level par, even on island greens, so hazards never bit. Shot numbers are retuned (shorter hitting, wider sprays, harder putting) so a 20 handicapper drops about a shot a hole and an island green costs ordinary golfers a ball every other round. Numbers are in `balance.json` under `shots`; ScoringTests prints the table.
2. **Reviews judge a round against the golfer's own handicap**, not against par. Otherwise realistic scores would make every review a grumble.
3. **Fairness on the hole card comes from a playtest**: 40 ordinary golfers play the hole in the simulator, and the card says how they scored and how many balls they lost. The quick estimate from hazards still drives the course design score (it has to be instant while painting); CalibrationTests compares the two.
4. **Does design pay?** Over four game weeks in May, a signature layout takes 1.3 to 1.5 times more money than an auto layout on the same plot, and averages about 4.2 stars against 2.9. DESIGN.md hoped for about double. Busy plots hit the tee sheet limit (one group every 8 minutes), so design shows up in the fee you can charge rather than in more golfers. Revisit in the balance pass; DesignPaysTests prints the numbers.

## October 2026: version 1 scope

Version 1 is a smaller, complete game, worth £1.99 with no placeholders. It contains course design with proper phone build tools; golfers, reviews and Percy; running the club (fees, condition, greenkeepers, clubhouse, shop, range); the calendar and close of play books; the map with the 66 hand made plots; quiet sales and sealed bids; simplified rivals; events up to The Championship; a tutorial; three challenges; the art and sound those screens need.

Challenges in version 1 are Back from the brink, Stockbroker belt and Shoestring. The waiting list needs members and Rising tide needs storms, so they arrive with those updates.

Moved to free updates: members and committee, storms and erosion, inbox, Gazette and Fairway Review, legendary venues, live auctions, selling clubs, administration sales, generated sites, iCloud saves, music. The data and rules already written for these stay in GameCore unused until then.

## October 2026: price

1. **Paid upfront at £1.99. No in-app purchases, ever.** Replaces the free download plus £5.99 unlock in DESIGN.md section 1. No StoreKit purchase code, no unlocks, no tip jar. Later content ships as free updates.

## October 2026: review of the handoff pack (agreed with Harry)

1. **Minimum iOS is 17.**
2. **Percy's costume changes.** No sheepskin coat (too close to a real broadcaster's trademark). He now has a waxed field jacket over a Fair Isle jumper, a tweed flat cap, half moon spectacles, a furled umbrella and a hip flask. The manifest row `portrait_percy` is updated. Harry can still change this before the portrait is drawn.
3. **Hole analysis moves into Milestone 1** so the heart of the game is tested from the start.
4. **Build costs are raised** so features cost real money. Prototype per tile: rough 5, fairway 15, green 60, bunker 30, water 80, trees 20, tee 150. Now: rough 5, fairway 30, green 150, bunker 120, water 400, trees 40, tee 500. An auto laid 18 holes costs about £70k (was about £38k); ringing a green with water adds about £12k. Provisional until the Milestone 2 balance pass. Numbers live in `balance.json`.
5. **Repeating a feature earns less.** Each feature kind (island green, dogleg and so on) counts in full on up to holes ÷ 6 holes (3 on 18 holes, 1 on 9). Each repeat after that is worth 60% of the one before. The hole card says so ("4th island green on this course: worth 60% here").
6. **Fairness.** Every hole gets a severity score from its hazards and a band: Fair, Testing or Brutal. Brutal holes lose up to 2 rating points and the tip says why; a course with over a third of its holes brutal loses 0.5 of design score. This is a first estimate; Milestone 2 calibrates it against the shot simulation (penalty strokes and pick ups by ordinary golfers).
7. **Challenges start on fixed dates** (in `challenges.json`) so the season is the same for every player. Career still starts on the real date.
8. **Undo and redo** are core to Build mode. Undo (with refund) is in GameCore now; one finger drag is one undo step.

## Still open

* **Debt.** Cash can go negative in the prototype and nothing happens. Needs designing: overdraft limit and interest, a bank letter, forced sale of a course, bankruptcy as a loss state in challenges.
* **Redesigning an open hole.** Proposal: construction takes days in proportion to the tiles changed, and the hole is closed meanwhile.
* **Hand made plots near legendary venues.** Several sit in the same town as a famous club with a similar sounding name (Ganton has both "Vale Heath" and "Potter Brompton Heath"). Review for passing off before launch.
