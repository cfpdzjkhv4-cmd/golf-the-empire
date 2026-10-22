# CLAUDE.md: Golf: The Empire

## Who you're working with
Harry Copeland owns this project. He is a technical project manager in live events, not a programmer, and he wants you to write all the code. Explain what you're doing in plain English, keep him in the loop on decisions, and tell him exactly what to click in Xcode when he needs to. He uses a Mac and will test on his iPhone. He prefers direct, concise answers, likes being challenged rather than agreed with, and does not want dashes (em or en) in messages to him.

## What we're building
A premium British golf empire game for iPhone and iPad. Read `docs/DESIGN.md` before writing any code; it is the source of truth for every system and number. `prototype/prototype-5.html` is a working browser prototype of the whole game: open it in Safari to see how things should feel, and read its source when the design doc is unclear. **Do not port the prototype line by line.** Rebuild it properly.

`docs/DECISIONS.md` records decisions made since DESIGN.md version 2 and wins where they differ. `README.md` has the build commands and code layout.

## The asset pack is a first class part of this project, and you make it
The game ships with a complete asset pack (art, animation, music, sound) and **nothing is bought or commissioned**. You produce every asset as code, vector art, procedural generation or synthesis. Read `docs/ASSET_PACK.md` for the art direction and pipeline.

1. `docs/assets_manifest.csv` lists every asset by id, with size in points, frames, variants, format, priority and a `source` column saying how to make it.
2. Build the shared style guide first (palette, strokes, light direction, shadows, grain). Every generator reads it. Consistency across hundreds of generated assets depends on this.
3. Keep every generator in `art/`. One command regenerates the whole pack, renders @2x and @3x, builds atlases and audio, and names files by manifest id.
4. All code loads assets **by manifest id only**, through one asset layer. Never hard code a file path anywhere else.
5. People and trees are **vector rigs animated in code**, never hand drawn frame sequences.
6. Build a debug **asset gallery** so Harry can review everything on his phone and request changes by id.
7. Start with the hero set in ASSET_PACK.md and iterate with Harry until he's happy before mass producing the rest.
8. If a feature needs an asset that isn't in the manifest, add a row in the same change and tell Harry.
9. Don't add paid tools, paid asset packs or paid AI image services. Free CC0 audio and a permissively licensed SoundFont are allowed; log their licences.

## Stack
* Swift, SpriteKit for the game world (course view, map), SwiftUI for menus, sheets, inbox and HUD.
* Minimum iOS: agree with Harry; suggest iOS 17.
* Saves: Codable JSON on device, then iCloud (CloudKit or iCloud key value / documents) in a later milestone. Version every save and write migrations.
* No third party dependencies without asking Harry first.

## Architecture rules
* **Simulation core is separate from rendering.** A pure Swift `GameCore` module owns the state and all rules (economy, golfers, shot sim, auctions, rivals, members, storms, events, press). It has no SpriteKit or SwiftUI imports and can be run headless.
* The core advances in game minutes and is **deterministic given a seed**, so tests can replay days.
* Game data lives in JSON resources, not code: plots, land types, facilities, events, rivals, challenges, all Percy and press text.
* Rendering and UI observe the core and send it commands.
* Keep every balancing number in one place (a `Balance` file or JSON) so tuning doesn't mean hunting through code.

## Testing
* XCTest for the core: run 30+ simulated days headless for each mode and challenge, assert no crashes, cash and reputation within sensible bounds, every system fires (auction resolves, storm erodes, review written, Gazette sent).
* The prototype was tested the same way (headless days in a script); keep that habit.
* Add a balance report test that prints daily revenue, rounds and rep for a few reference plots so tuning changes are visible.

## Milestones
1. **Foundations.** Xcode project, GameCore skeleton, data files from DESIGN.md, asset manifest loader, placeholder generator, save and load. One course on screen with placeholder terrain.
2. **Style guide and one course, playable, with design scoring.** The hero hole art and golfer rig, hole analysis and the hole card, Build tools, auto layout, golfers and shot sim, fees, reviews, Percy text, Run tab, watch a round, upkeep, condition, facilities.
3. **The empire.** Calendar and close of play books, map of Britain, generated sites, quiet sales, sealed bids, live auctions, selling clubs, rivals, legendary venues, administration, events and The Championship rota.
4. **Depth.** Members and committee, storms and erosion, inbox, weekly Gazette, The Fairway Review, milestones.
5. **Modes and polish.** Start screen, challenges, tutorial, settings, iCloud saves, accessibility (Dynamic Type, VoiceOver labels, colour blind safe terrain).
6. **Art and audio pass.** Finish every manifest asset through the generators, tune animation timing, compose and render the music, mix ambience.
7. **Release.** App Store assets, TestFlight with Harry's testers, performance on older iPhones, submission.

Show Harry something he can run on his phone at the end of every milestone.

## Course design is the heart of the game
Harry's strongest piece of feedback: course design must matter and must not feel like a gimmick. DESIGN.md section 7 defines the hole analysis (island greens, doglegs, carries, showcase bunkers and so on), the course design score and everything it drives. Get this feeling great before anything else: clear feedback while building, real rewards in reviews and money, and tools that make building those features satisfying on a phone.

## Fix these known prototype problems as you go
* The hole view is tall and thin on a phone; use a camera that follows the hole rather than shrinking it to fit.
* Build mode pauses time; redesigning a hole on an open course should close that hole for the rest of the day.
* See DESIGN.md section 15 for the full list.

## Never
* Use real people's names, voices or likenesses (Percy Hollis is fictional and must not be an impression of anyone).
* Use "The Open", R&A marks, real club names or logos, or map tiles.
* Add ads, loot boxes, energy timers, premium currency or in-app purchases of any kind. The game is £1.99 upfront.
