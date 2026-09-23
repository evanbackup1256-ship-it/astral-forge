# Astral Forge v2

Argon-synced project for Astral Forge 5.1.0. Argon reads the existing
`default.project.json` mapping (its Rojo-compatible project format). The game version is **not** the save-schema
version: live saves currently use `GameConfig.Game.DataVersion = 21`. Do not bump
that value or delete the `DataService` legacy transfer without save fixtures.

## Getting Started
Install the npm dependencies, then sync Studio from **source** (source of truth):

```bash
npm install
argon serve default.project.json
```

`Astral Forge v2.rbxlx` is a **local** Argon build artifact (gitignored). It may lag
`origin/master`; do not treat a checked-out or stale `.rbxlx` as newer than `src/`.
Optional rebuild after pull:

```bash
argon build default.project.json -x -o "Astral Forge v2.rbxlx"
```

Open the place in Roblox Studio with the Argon plugin and connect it to the serve
session. The vendored Luau packages in `vendor/` are mapped into
`ReplicatedStorage.rbxts_include.node_modules` by `default.project.json`; do not
delete them during `npm install`.

## Sync Studio after a GitHub merge

Argon syncs **local disk only**. A cloud agent push to `origin/master` does **not**
update Roblox Studio until you pull on this machine and restart `argon serve`.

```bash
cd /path/to/astral-forge
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
# Expect at or after: ef4134f7738d2840a6141ac4d8d127d794338bc7
# Game integrate tip (must be ancestor): 5e55aab2c0dd28a3151353483da923fcc41605ec
git merge-base --is-ancestor 5e55aab HEAD && echo integrate OK

# Confirm color / trade / inventory / playability / closeout landed:
git merge-base --is-ancestor d3b0d55 HEAD && echo color-pc OK
git merge-base --is-ancestor 9bcb0c5 HEAD && echo trade OK
git merge-base --is-ancestor 9c30593 HEAD && echo inventory OK
git merge-base --is-ancestor a08ddef HEAD && echo playability OK
git merge-base --is-ancestor 4146904 HEAD && echo pagescaffold-remaining OK
git merge-base --is-ancestor 6297d4f HEAD && echo goal-closeout OK
git merge-base --is-ancestor 3a900b4 HEAD && echo playability-residuals OK
git merge-base --is-ancestor 38d3052 HEAD && echo allowlist-polish OK
git merge-base --is-ancestor dd10c4b HEAD && echo studio-edge-harden OK
git merge-base --is-ancestor ef4134f HEAD && echo trade-gamepad-release OK

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
desktop, ultrawide layout planning, fail-closed profile version guards, and a
**Lune-safe ReleaseReadiness subset** (`scripts/verify_release_readiness.luau`:
config identity, PreviousId/ArtifactId/CrateId/Boost refs, DV21 + PlatformBadges).
It does **not** run `ReleaseReadiness.RunQuick` / `RunSoak` (Economy soak +
ProfileIntegrity recovery) — those stay Studio-only via `init.server.luau`.
Argon validates the project mapping; it does **not**
execute the game or check every Luau runtime path.

Before publishing, run Studio Device Simulator and Controller Emulator at those
sizes, plus a 4:3 tablet and 1080p/4K TV. Verify the crate reveal is centered,
its claim button is reachable by D-pad/A, the software keyboard does not cover
fields, two touches do not produce duplicate actions, and the bottom navigation
stays within the hardware safe area. Run the Studio release-readiness
(`ReleaseReadiness.RunQuick` / soak) and profile load/save tests with copied
v4.12 and current save fixtures; never use live player data as a migration test
fixture. npm test alone is not ENTIRE-game release complete.

The client adapts effects and preload work to measured performance. Roblox
controls physical render resolution, so this project cannot promise a fixed
60 FPS or prevent thermal throttling on every mobile device. Console publishing
also requires platform testing and Roblox review. The current UI cue bank has
three distinct sound asset IDs; assigning ten additional premium effects requires
licensed, game-accessible audio assets.
