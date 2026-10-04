# Asset pack specification: AI only

**Budget rule: nothing is bought or commissioned.** Every asset is produced by Claude (in chat or Claude Code) as code, vector art, procedural generation or synthesis. The only unavoidable costs are the Apple Developer account and the Claude subscription.

That rule decides the art style. AI is weak at hand drawn, painterly art and frame by frame animation, and strong at clean vector shapes, procedural textures and code driven animation. So the game commits to a style that plays to those strengths, rather than chasing a look it can't reach.

`assets_manifest.csv` lists all 265 assets. The `source` column says how each one is made.

| Source | Assets |
|---|---|
| Code drawn vector (SVG/PDF) | 92 |
| Code drawn vector (SVG), rendered to PNG | 53 |
| Code drawn vector parts, animated in code | 25 |
| Synthesised by script (optional upgrade: CC0 recordings, free) | 24 |
| Procedural: generated texture script | 23 |
| Code drawn vector, rendered to PNG | 14 |
| Procedural particles (SpriteKit emitters) | 11 |
| Composed by Claude as MIDI, rendered with a free licensed SoundFont | 8 |
| Synthesised noise beds by script (optional upgrade: CC0 recordings, free) | 8 |
| Captured from the game, framed in code | 5 |
| Cut | 2 |

## The look: "illustrated Ordnance Survey meets travel poster"

* **Flat vector illustration** with soft shading, in the spirit of mid century British railway posters and OS maps. Clean shapes, limited palette, subtle grain. Think Mini Metro, Pocket City, Alto's Adventure: games that look premium because the style is disciplined, not because it's detailed.
* **One shared style guide in code** (`ArtStyle.swift` / `style.json`): palette tokens, stroke widths, light direction (top left), shadow colour and opacity, corner radii, grain amount. Every generator reads it, which is what keeps hundreds of generated assets consistent.
* **Palette:** British, not American. Soft greens, heather purple, gorse yellow, slate, sandstone, grey seas, overcast light. Light and dark mode for UI.
* **Readability:** fairway, green, rough, bunker, water and sea distinguishable at a glance and for colour blind players (texture as well as colour).
* **Original work only.** No likeness of real people (Percy included), no real club logos, nothing resembling The Open or its trophy.

## How each kind of asset is made

**Terrain and textures.** Scripts generate seamless textures (grass with mowing stripes, raked sand, water, sea, heather) using noise functions, rendered at @2x and @3x. Course shapes are drawn in code as smooth blobs, exactly as the prototype does, with textures clipped inside them.

**Trees, buildings, props, map, portraits, UI.** Written as SVG by Claude, from the style guide, then rendered to PNG (or kept as PDF vectors for icons). Clubhouses get stone (north) and brick (south) versions for each level. The map of Britain is an original vector illustration. Percy and the other characters get flat illustrated portraits, not photoreal ones.

**Golfers and people: rigs, not sprite sheets.** Hand drawn animation frames are the one thing AI can't produce consistently, so we avoid them entirely. Each person is a vector rig: separate head, torso, arms, legs and club, posed and animated in code (walk cycle, address, swing, putt, celebrate, despair). One rig, recoloured and varied by body shape, skin tone, clothes and hat, gives hundreds of different golfers who all animate perfectly. Trees sway the same way.

**Effects.** SpriteKit particle emitters: rain, storm spray, splashes, sand, divots, leaves, confetti, gulls.

**Music.** Claude composes each piece as MIDI (themes, loops, auction tension with intensity layers) and Claude Code renders it to audio using a free, permissively licensed General MIDI SoundFont. Light, warm, brass and strings, a bit of brass band humour. If Harry wants, he can record the main theme himself instead.

**Sound effects and ambience.** Synthesised by script: UI clicks, chimes, gavel, till, splashes, wind, rain and surf noise beds. Some sounds synthesis does poorly (club strikes, crowd applause). The free upgrade is CC0 public domain recordings, which cost nothing; log their source.

**Voice.** Cut. Percy is text only. On device speech synthesis would sound robotic and kill the character; his lines work better written.

**App Store screenshots and preview video.** Captured from the game, framed by a code generated template.

## Pipeline for Claude Code

1. An `art/` folder holds every generator: SVG source files and scripts, one per manifest entry or family, all reading the shared style guide.
2. One command (`make assets`) regenerates the entire pack, renders @2x and @3x, builds texture atlases and audio files, named by manifest id.
3. The game loads everything by manifest id through a single asset layer.
4. A debug **asset gallery** screen shows every asset in place, so Harry can review the whole pack on his phone and ask for changes by id ("make icon_inbox rounder", "darker gorse").
5. Iterate in batches by category, Harry reviewing each batch, starting with the hero set below.

## Hero assets (do these first, iterate until Harry loves them)

1. **The style guide and one finished hole** (terrain, trees, a golfer, the flag). Everything else follows from this.
2. **The golfer rig** and its swing.
3. **The map of Britain.**
4. **Percy's portrait.**
5. **App icon and logo**, once the name is decided.

## Honest limits

* The game will look **stylish and clean, not lush.** That's a deliberate choice, and flat illustration ages well.
* Expect many rounds of iteration on hero assets; that's tokens and Harry's time rather than money.
* Synthesised club strikes and crowds will sound thin; use free CC0 recordings if it bothers you.
* Keep a licence log for any CC0 audio and the SoundFont.
