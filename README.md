# Astral Forge v2

## Canonical project links

- GitHub repository: [evanbackup1256-ship-it/astral-forge](https://github.com/evanbackup1256-ship-it/astral-forge) (`origin`).
- Roblox Studio target: Astral Forge, place ID `135153679037687`.
- Argon project: this checkout's `default.project.json`; `argon serve default.project.json` connects Studio through `localhost:8000`.
- The Studio DataModel is a sync target. Commit and push source changes to GitHub separately; Argon synchronization does not publish the Roblox experience.

Argon-synced project for Astral Forge 5.1.0. Argon reads the existing
`default.project.json` mapping (its Rojo-compatible project format). The game version is **not** the save-schema
version: live saves currently use `GameConfig.Game.DataVersion = 21`. Do not bump
that value or delete the `DataService` legacy transfer without save fixtures.

## Versions

| What | Version |
|------|---------|
| Game (GameConfig.Game.Version, package.json) | 5.1.0 |
| Save schema (GameConfig.Game.DataVersion) | 21 (do not bump without save fixtures) |
| Lune (tests) | 0.10.5 |
| Argon (Studio sync) | 2.0.29 |
| Node / npm packages | Node 24; roblox-ts 3, TypeScript 7, React 17 (types only; runtime packages are vendored in endor/) |
| Python (asset tools) | 3.14 |

The verification suite is the scripts/verify_*.luau guards run by lune run scripts/verify_project.luau.
Last updated 2026-10-07. GitHub `origin`, the Argon project mapping, and the confirmed Studio place were checked together on this date.
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

You are already inside the repo folder when the PowerShell prompt shows
`...\Astral Forge v2>` — **do not** `cd /path/to/...` (that is a placeholder and
will fail). Stay put, or `cd` to your real clone (example:
`C:\Users\evanm\OneDrive\Desktop\Astral Forge v2`).

If git prints `Deletion of directory '.git/objects/...' failed` under OneDrive:
pause OneDrive sync for this folder (or move the clone out of OneDrive), answer
`n` to abort the stuck delete retry, then re-run `git pull`. OneDrive file locks
break git object cleanup.

If `git pull` aborts with `Your local changes ... would be overwritten by merge`,
your tree is dirty (often leftover Argon/Studio edits). Discard local edits and
fast-forward to tip:

```powershell
git fetch origin
git checkout master
git reset --hard origin/master
git rev-parse HEAD
```

```powershell
# From your Astral Forge v2 folder (already there — skip cd).
# Windows PowerShell 5: do not use bash `&&` — use `; if ($LASTEXITCODE -eq 0)` as below.
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
# Studio sees whatever is on disk, so confirm you are on the tip you expect:
git log --oneline -5

# Stop any old Argon session, then:
argon serve default.project.json
```

In Studio: reconnect the Argon plugin to that session (or stop/start sync).
Default branch is `master` on `origin` only — do not stay on feature branches like
`cursor/client-page-features-4e51` if you want the integrate tip.

## Checks

The full suite (every module's syntax and the register limits) is `lune run scripts/verify_project.luau`; commit only on exit code 0.

Install [Lune](https://lune-org.github.io/docs/) for the pure layout tests, then run:

```bash
npm test
argon build default.project.json -x -o "Astral Forge v2.rbxlx"
```

`npm test` covers phone portrait/landscape, short landscape, tablet, foldable,
desktop, ultrawide layout planning, fail-closed profile version guards, and a
**Lune-safe ReleaseReadiness subset** (`scripts/verify_release_readiness.luau`:
config identity, PreviousId/ArtifactId/CrateId/Boost refs, achievement/mail/story
envelopes, Trading/Guild/RemoteFirewall knobs, Continuum/Lab/ForgePath/Wheel
envelopes, TradeSettle.RunHostGuest wiring, DV21 + PlatformBadges).
It does **not** run `ReleaseReadiness.RunQuick` / `RunSoak` (Economy soak +
ProfileIntegrity recovery) — those stay Studio-only via `init.server.luau`.
Argon validates the project mapping; it does **not**
execute the game or check every Luau runtime path.

### Studio QA checklist (ENTIRE-goal closeout)

`npm test` alone is **not** ENTIRE-game release complete. Sign off the items
below on the tip SHA after `git pull origin master` + Argon reconnect. Capture
walkthrough / Device Simulator evidence before claiming ENTIRE complete.

**0. Argon pull tip SHA (do this first)**

```powershell
# From your Astral Forge v2 folder — skip any `cd /path/to/...` placeholder.
# If pull aborts on dirty local files: git reset --hard origin/master
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
argon serve default.project.json
```

Reconnect the Argon plugin in Studio. Do not QA a stale `.rbxlx` or feature branch.

**1. Device Simulator sizes** (Test → Device Emulator / Device Simulator)

| Size | Notes |
|------|--------|
| Phone portrait (~390×844) | Bottom nav inside safe area; crate reveal centered |
| Phone landscape (~844×390) | Notch + home-indicator insets |
| Short landscape (~640×320) | Chrome must not dominate; CTAs reachable |
| iPhone SE portrait (~375×667) | Compact content budget |
| Tablet (~768×1024) | Plus a 4:3 tablet variant |
| Foldable (~600×700) | Mid-height stack |
| Desktop 1080p (~1920×1080) | Readable PC density |
| Ultrawide (~3440×1440) | No crushed side panels |
| 1080p / 4K TV | Ten-foot / TV-safe margins |

Also: software keyboard open (portrait + landscape) must not cover input fields;
two simultaneous touches must not double-fire actions.

**2. Controller Emulator — FocusClaim paths** (Emulate gamepad / Controller Emulator)

With gamepad enabled, confirm D-pad/A can reach and activate each host (Selection
parks via `GamepadNavigationService.FocusClaim`):

- Crate reveal CLAIM (stage + overlay)
- Trade Ready / Confirm / Cancel
- Story Continue/Back; Mail CLAIM/ARCHIVE
- Rebirth CONFIRM; Continuum FORGE; Missions/Lab CLAIM ALL
- Anomaly PULSE/BANK strip; Wheel SPIN; Forge Path CLAIM NOW
- Inventory SOCKET/UPGRADE; Boosts Activate; Milestones CLAIM
- Guild CLAIM REWARD; Convergence CLAIM; Echo LINK SLOT
- Research BUY ALL; Star Grid BUY ALL
- Shop CLAIM CODE; Admin ARM/RUN; Credits primary CTA
- Command commander/weekly/expedition/season CLAIM
- Settings GUIDE/UPDATES
- Chat SEND

**3. ReleaseReadiness (Studio-only)**

From a Studio play session (see `init.server.luau` wiring):

1. `ReleaseReadiness.RunQuick()` — Economy cost envelope soak + ProfileIntegrity recovery
2. `ReleaseReadiness.RunSoak()` — long Studio-only economy soak (`RunService:IsStudio()` gated)
3. Profile load/save with **copied** v4.12 and current save fixtures — never live player data

UNTIL steps 0–3 have tip-SHA evidence, ENTIRE-game remains **not complete**
even if `npm test` is green.

The client adapts effects and preload work to measured performance. Roblox
controls physical render resolution, so this project cannot promise a fixed
60 FPS or prevent thermal throttling on every mobile device. Console publishing
also requires platform testing and Roblox review. The current UI cue bank has
three distinct sound asset IDs; assigning ten additional premium effects requires
licensed, game-accessible audio assets.

## Balancing the economy

Judge pacing changes with the simulator, not by feel:

```bash
lune run scripts/sim_pacing                    # current GameConfig
lune run scripts/sim_pacing <path> <gain> <tap> [days]   # before/after copies, policy knobs
```

It reads the real machine, zone and economy numbers and plays a steady player
(best-payback purchases, rebirth once the reward is >= `gain` x current cores).
Findings on the current config: the first ~5 hours are tightly paced, and zones and
machines are gated by rebirth COUNT, so a player who rebirths often reaches zone 6
in about 2 hours while one who waits for big payouts does not reach zone 5 in two
weeks. The rebirth screen therefore names the next count-gate and says to rebirth
often. Do not bump `DataVersion` for balance changes: tune `GameConfig` numbers.
## The sanctuary (retired)

The walkable sanctuary, its ore outcrops, waystones and rift bosses were removed. Saved ore balances and the
Foundry upgrades players already bought are kept: `SharedData#OreConfig` (exposed as `GameConfig.Ore`) still
sanitizes them on load and `Economy.OreEffect` still applies the upgrades, so no save migration was needed and
`DataVersion` stays 21. The old code is in git history.

## Configs you can edit

| What | Where |
|------|-------|
| Credits: categories (Owner, Developers, Moderators, Testers, ...), people, card style, avatars, tabs, search, motion | `SharedData#CreditsConfig` (`src/Shared/AstralForge/Shared/SharedData.luau`) |
| Guided tour: steps, Bolt's lines, what each step highlights and waits for | `SharedData#TutorialScript` |
| Report reasons (client) | `SharedData#PlayerlistModel.REASONS`; the server list is `ProfileMath#ReportLedger.REASONS` and must match (`scripts/verify_playerlist.luau` checks) |
| Left rail sections | `CoreKit#navRouteTable` `NAV_GROUPS` |

The tutorial finds what to highlight by GuiObject `Name` (for example `WorkshopBuyClaim`, `Nav_Research`).
`scripts/verify_tutorial.luau` fails if a step points at a name the UI no longer sets.
