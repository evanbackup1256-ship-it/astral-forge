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

## Sync Studio after a GitHub merge

Argon syncs **local disk only**. A cloud agent push to `origin/master` does **not**
update Roblox Studio until you pull on this machine and restart `argon serve`.

```bash
cd /path/to/astral-forge
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
# Expect at or after: b3ce6aa9973827e2a7cdeab2fd51fe431cad8e62
# Game integrate tip (must be ancestor): 5e55aab2c0dd28a3151353483da923fcc41605ec
git merge-base --is-ancestor 5e55aab HEAD && echo integrate OK

# Confirm color / trade / inventory / playability landed:
git merge-base --is-ancestor d3b0d55 HEAD && echo color-pc OK
git merge-base --is-ancestor 9bcb0c5 HEAD && echo trade OK
git merge-base --is-ancestor 9c30593 HEAD && echo inventory OK
git merge-base --is-ancestor a08ddef HEAD && echo playability OK

# Stop any old Argon session, then:
argon serve default.project.json
```

In Studio: reconnect the Argon plugin to that session (or stop/start sync).
Default branch is `master` on `origin` only — do not stay on feature branches like
`cursor/client-page-features-4e51` if you want the integrate tip.

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
