# Astral Forge v2

Argon-synced project for Astral Forge 5.1.0. Argon reads the existing
`default.project.json` mapping (its Rojo-compatible project format). The game version is **not** the save-schema
version: live saves currently use `GameConfig.Game.DataVersion = 21`. Do not bump
that value or delete the `DataService` legacy transfer without save fixtures.

## Getting Started
Install the npm dependencies, then build the place with Argon:

```bash
npm install
argon build default.project.json -x -o "Astral Forge v2.rbxlx"
```

Open the place in Roblox Studio with the Argon plugin, then start an Argon session
from the project directory:

```bash
argon serve default.project.json
```

Connect the Studio plugin to that session. The vendored Luau packages in
`vendor/` are mapped into `ReplicatedStorage.rbxts_include.node_modules` by
`default.project.json`; do not delete them during `npm install`.

## Checks

Install [Lune](https://lune-org.github.io/docs/) for the pure layout tests, then run:

```bash
npm test
argon build default.project.json -x -o "Astral Forge v2.rbxlx"
```

`npm test` covers phone portrait/landscape, short landscape, tablet, foldable,
desktop, ultrawide layout planning, and fail-closed profile version guards.
Argon validates the project mapping; it does **not**
execute the game or check every Luau runtime path.

Before publishing, run Studio Device Simulator and Controller Emulator at those
sizes, plus a 4:3 tablet and 1080p/4K TV. Verify the crate reveal is centered,
its claim button is reachable by D-pad/A, the software keyboard does not cover
fields, two touches do not produce duplicate actions, and the bottom navigation
stays within the hardware safe area. Run the Studio release-readiness and profile
load/save tests with copied v4.12 and current save fixtures; never use live player
data as a migration test fixture.

The client adapts effects and preload work to measured performance. Roblox
controls physical render resolution, so this project cannot promise a fixed
60 FPS or prevent thermal throttling on every mobile device. Console publishing
also requires platform testing and Roblox review. The current UI cue bank has
three distinct sound asset IDs; assigning ten additional premium effects requires
licensed, game-accessible audio assets.
