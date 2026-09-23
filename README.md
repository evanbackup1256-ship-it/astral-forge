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

You are already inside the repo folder when the PowerShell prompt shows
`...\Astral Forge v2>` — **do not** `cd /path/to/...` (that is a placeholder and
will fail). Stay put, or `cd` to your real clone (example:
`C:\Users\evanm\OneDrive\Desktop\Astral Forge v2`).

If git prints `Deletion of directory '.git/objects/...' failed` under OneDrive:
pause OneDrive sync for this folder (or move the clone out of OneDrive), answer
`n` to abort the stuck delete retry, then re-run `git pull`. OneDrive file locks
break git object cleanup.

```powershell
# From your Astral Forge v2 folder (already there — skip cd):
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
# Expect at or after: fd27fbe
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
git merge-base --is-ancestor cbd4cf0 HEAD && echo content-gates-polish OK
git merge-base --is-ancestor 9973c1c HEAD && echo bug-polish OK
git merge-base --is-ancestor f8240e4 HEAD && echo extract-economy-more OK
git merge-base --is-ancestor d08a852 HEAD && echo extract-progression-lab OK
git merge-base --is-ancestor 227f8a5 HEAD && echo cta-clip-polish OK
git merge-base --is-ancestor 88369d7 HEAD && echo extract-anomaly OK
git merge-base --is-ancestor e693912 HEAD && echo content-bug-wave OK
git merge-base --is-ancestor a97b5a8 HEAD && echo extract-guild-bugs OK
git merge-base --is-ancestor f100cf5 HEAD && echo settle-virt-release OK
git merge-base --is-ancestor a318638 HEAD && echo extract-pagerouter-maingame OK
git merge-base --is-ancestor e304f15 HEAD && echo bug-content-wave7 OK
git merge-base --is-ancestor 897d932 HEAD && echo bug-studio-checklist OK
git merge-base --is-ancestor 3cf76a0 HEAD && echo extract-serverservices OK
git merge-base --is-ancestor 49f1d8e HEAD && echo bug-content-wave8 OK
git merge-base --is-ancestor 2a7d9a6 HEAD && echo inv-crates-admin-scaffold OK
git merge-base --is-ancestor 78e593d HEAD && echo settle-gates-more OK
git merge-base --is-ancestor eec599c HEAD && echo echo-research-virt OK
git merge-base --is-ancestor 15c0aba HEAD && echo bug-content-wave9 OK
git merge-base --is-ancestor d059e83 HEAD && echo wave10-harden OK
git merge-base --is-ancestor 8308a2f HEAD && echo split-maingame-ss OK
git merge-base --is-ancestor 2321f3d HEAD && echo bug-content-wave11 OK
git merge-base --is-ancestor 8cc1e7f HEAD && echo wave12-harden OK
git merge-base --is-ancestor 98bf1c3 HEAD && echo chat-credits-softmotion OK
git merge-base --is-ancestor 38fdd2d HEAD && echo wave13-harden OK
git merge-base --is-ancestor 45849b3 HEAD && echo softmotion-thin OK
git merge-base --is-ancestor 6385be9 HEAD && echo wave14-harden OK
git merge-base --is-ancestor d740cac HEAD && echo softmotion-admin OK
git merge-base --is-ancestor ca2bb29 HEAD && echo wave15-harden OK
git merge-base --is-ancestor d942e37 HEAD && echo wave16-harden OK
git merge-base --is-ancestor 2f66f7e HEAD && echo wave17-harden OK
git merge-base --is-ancestor e5f361c HEAD && echo softmotion-ungated OK
git merge-base --is-ancestor 0ce4e32 HEAD && echo wave18-harden OK
git merge-base --is-ancestor b829dc9 HEAD && echo economy-inv-readme OK
git merge-base --is-ancestor 3b108bb HEAD && echo wave19-harden OK
git merge-base --is-ancestor 504833d HEAD && echo dataservice-admin-extract OK
git merge-base --is-ancestor 975abca HEAD && echo wave20-harden OK
git merge-base --is-ancestor 978eaa5 HEAD && echo split-monoliths-wave20 OK
git merge-base --is-ancestor b46f905 HEAD && echo wave21-harden OK
git merge-base --is-ancestor 38d3197 HEAD && echo extract-checks-wave21 OK
git merge-base --is-ancestor 9003943 HEAD && echo wave22-harden OK
git merge-base --is-ancestor 505f565 HEAD && echo extract-checks-wave22 OK
git merge-base --is-ancestor 6af2030 HEAD && echo extract-checks-wave22-tip OK
git merge-base --is-ancestor 0e6d84a HEAD && echo wave24-offline OK
git merge-base --is-ancestor 315720b HEAD && echo wave25-offline OK
git merge-base --is-ancestor 68c71bf HEAD && echo wave26-offline OK
git merge-base --is-ancestor 78ba94a HEAD && echo wave27-offline OK
git merge-base --is-ancestor 75bbeec HEAD && echo wave28-offline OK
git merge-base --is-ancestor 268ba8a HEAD && echo wave29-offline OK
git merge-base --is-ancestor 05b12ae HEAD && echo wave30-offline OK
git merge-base --is-ancestor fd27fbe HEAD && echo wave31-offline OK

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
git fetch origin
git checkout master
git pull origin master
git rev-parse HEAD
# Expect at or after: fd27fbe
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
