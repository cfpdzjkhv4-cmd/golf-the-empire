# Golf: The Empire

A premium British golf empire game for iPhone and iPad. Swift, SpriteKit and SwiftUI.

* `CLAUDE.md`: the brief for Claude.
* `docs/DESIGN.md`: the full game design. `docs/DECISIONS.md`: what has changed since.
* `docs/ASSET_PACK.md` and `docs/assets_manifest.csv`: every asset, made by code.
* `prototype/prototype-5.html`: the browser prototype, for reference only.

## Run it on your iPhone (first time)

You need: a Mac with the latest Xcode, and Homebrew.

1. In Terminal, install XcodeGen once: `brew install xcodegen`
2. In Terminal, go to this folder and make the Xcode project: `make project`
3. Open `GolfTheEmpire.xcodeproj` (double click it).
4. In Xcode, click **GolfTheEmpire** at the top of the left sidebar, then the **Signing & Capabilities** tab. Tick **Automatically manage signing** and choose your name under **Team** (add your Apple ID in Xcode > Settings > Accounts if it isn't listed).
5. Plug in your iPhone. On the phone: Settings > Privacy & Security > Developer Mode, turn it on and restart when asked.
6. In Xcode's toolbar, pick your iPhone as the run destination, then press the Play button (or Cmd R).
7. First time only, on the phone: Settings > General > VPN & Device Management, tap your Apple ID and Trust it. Then open the app.

With a free Apple ID the app stops opening after 7 days; just press Play in Xcode again.

## Everyday commands (Terminal, in this folder)

| Command | What it does |
|---|---|
| `make project` | Rebuilds the Xcode project after files are added or `project.yml` changes |
| `make test` | Runs the rules tests headless (41 tests, about 10 seconds) |
| `make assets` | Regenerates every asset by manifest id |
| `make data` | Re-extracts plots, towns and Percy's lines from the prototype |

## How the code is laid out

```
Packages/GameCore/        All the rules. No SpriteKit or SwiftUI. Deterministic from a seed.
  Sources/GameCore/
    Data/                 Loads the JSON data files (Resources/Data/*.json)
    Model/                Hole, Course, GameState
    Rules/                Hole analysis, course design score, hole generators
    Sim/                  The engine: clock, close of play, books, building and undo
    Save/                 Versioned JSON saves with migrations
  Tests/GameCoreTests/    XCTest: analysis, design, 30 day headless runs, saves, data
App/                      The iPhone and iPad app (SwiftUI screens, SpriteKit course view)
  Assets/AssetLibrary     The only code that loads art, always by manifest id
  Resources/GeneratedAssets  Output of `make assets`
art/                      Asset generators (placeholders for now)
tools/                    One off scripts
```

Every tunable number is in `Packages/GameCore/Sources/GameCore/Resources/Data/balance.json`.
