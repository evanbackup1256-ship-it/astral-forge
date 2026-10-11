# Astral Forge v2

Argon-synced project for Astral Forge 7.0.0. Argon reads the existing
`default.project.json` mapping (its Rojo-compatible project format). The game version is **not** the save-schema
version: live saves currently use `GameConfig.Game.DataVersion = 21`. Do not bump
that value or delete the `DataService` legacy transfer without save fixtures.

## Versions

| What | Version |
|------|---------|
| Game (GameConfig.Game.Version, package.json) | 7.0.0 |
| Save schema (GameConfig.Game.DataVersion) | 21 (do not bump without save fixtures) |
| Lune (tests) | 0.10.5 |
| Argon (Studio sync) | 2.0.29 |
| Node / npm packages | Node 24; roblox-ts 3, TypeScript 7, React 17 (types only; runtime packages are vendored in `vendor/`) |
| Python (asset tools) | 3.14 |

The verification suite is the scripts/verify_*.luau guards run by lune run scripts/verify_project.luau.
Last updated 2026-10-09.

## Release 7.0

### Forge Specializations (in-progress revamp)

The former Star Grid destination now offers Balanced forge, Handcraft, Deep
reserves and Night shift. Each card previews actual production, vault capacity,
overcharge and offline efficiency using the same economy functions as gameplay.
Purchased GridUpgrades keep their exact saved levels and original effects as
permanent foundation bonuses; there is no wipe, refund-and-rebuy or schema bump.
Research, Domain and Forge Path retain their existing progression.

Build changes are free, normally with a ten-minute cooldown. A smaller build
cannot discard flux already in the vault: the authoritative transaction rejects
the change until the player collects it. Same-build retries are harmless, even
for a previously overfull vault. Equipped gain/trade-off rates persist across
rejoin and do not change when live tuning changes. Optional Experience Config
keys are `SpecializationGain` (default 1.3, bounded 1.05–1.5),
`SpecializationTradeoff` (default 0.85, bounded 0.5–0.95) and
`SpecializationRespecSeconds` (default 600, bounded 60–3600).

The obsolete 960-line renderer, unused purchase handler and old story are
retired. The internal `StarGrid` route ID and compatibility readers remain.
Snapshot previews are reused within a second when outputs and policy are
unchanged, expire at the next second, and invalidate after successful mutations.
The shared snapshot builder also supplies the UI Labs fixture.
`verify_specializations.luau` executes the real formulas, dispatch/atomic owner,
snapshot builder and client retry closure, including Omega-sized balances,
full-vault rollback, cooldown, live-rate freezing, remount and late responses.

### Retired Bazaar settlement

Bank balance, accrued savings interest, term principal (plus matured interest),
profile prizes and recoverable rollover prizes return through the existing
atomic profile owner. Held lottery tickets share the saved rollover pot in
proportion to saved ticket counts, without a rake. The old save did not record
each ticket's purchase price, so this is a proportional settlement, **not an
exact stake refund**. Prize and ticket settlements use separate saved markers;
an earlier prize refund cannot consume the held-ticket entitlement.

Completed, unclaimed contracts from the last saved contract board are awarded
once, even after that board's day ends. Already claimed contracts are not paid
again; incomplete contracts retire without newly accumulating progress.
Bank/lottery/contract compatibility data remains readable under DataVersion 21.
An unrepresentable credit or failed earned reward leaves the entire transaction
uncommitted and the claim owed. The market exposes a pending-settlement message
instead of reporting a successful refund. Stardust/core reward grants now reject
increments that would disappear at the balance's numeric precision.
Automatic failed settlement retries are spaced by 30 seconds; the market's
Refresh action retries immediately, and repeated failure logs are bounded.

`verify_black_market.luau` covers pooled-pot conservation, separate markers,
copied/sanitized fixtures, completed/claimed contract settlement, precision
rejection and atomic rollback. It cannot recover a historical pot overwritten
or removed by the former server's global rollover implementation; live
multi-server migration and persistence-outage journeys remain unverified.

### Active encounters (in-progress revamp)

Salvage Runs unlock alongside Worlds at level 7: three authored wreck sites
open in zones 1, 3 and 6, with three saved choices, elemental advantages,
optional objectives and explicit strain/cargo outcomes. They are not timed
Command expeditions. Artifact Trials unlock alongside Command at level 11
and use owned Command artifacts, six family-specific rules and bounded
mastery (seven successes). Stardust milestone payouts occur only at mastery
1, 3 and 7 per companion; subsequent practice cannot farm the same reward.

Optional Experience Config keys are `SalvageDailyLimit` (default 3, bounded
1–12) and `EncounterStardustUnit` (default 4, bounded 1–100). Rewards are frozen
when a run begins; daily allowance resets at midnight UTC. Choices, history
and mastery persist under the additive `Encounters` profile field without
changing DataVersion 21. Start/choice replay and reward grants use the existing
atomic transaction owner. A balance too large to represent a small stardust
increment rejects the final choice; players may explicitly finish without
stardust rather than receive a false grant or become trapped.

`scripts/verify_encounters.luau` executes actual encounter and reward code,
all family rules, allowance/reset, save sanitization, replay mismatches,
capacity rejection/explicit forfeiture and injected grant rollback, plus
the actual client retry closure. Multiplayer and real persistence-outage
journeys remain required before release sign-off.

The 7.0 revamp removes casino gameplay and rebuilds the Black Market,
inventory, crate perks and artifact presentation. Equipped artifacts are visible
in the world, custom chat and player list. Guild community tools, domain-tree
visuals, UI audio, context-aware motion, mobile editing and rebirth presentation
are updated alongside reports, feedback, ranks, admin tools and event effects.
Save schema remains **21**. Offline guards and compilation do not replace Studio
multiplayer, device, audio-permission and save/load testing before Roblox publish.

The polish regression guard checks dense and compact trade envelopes, invalid
item arrays, pending-offer/session safeguards, motion timing at 15-144 fps and
all animated-title styles. Artifact sprites retain their animation speed across
dropped frames. Selected domain labels retain foreground priority, and projected
UI owns its geometry instead of competing with generic layout repairs.
Number units update correctly even while their amounts remain unchanged.
Research headings reserve space for batch controls, Shop wallets use compact
currency labels, and feedback impact controls have numbered levels with a
separate touch-sized phone row. Shared buttons and feedback dialog travel use
measured scale coordinates for genuine fractional-pixel movement: Roblox's
UDim offsets truncate fractions even without explicit rounding. The motion
regression checks resize updates and measurement-subscription cleanup. Shared
panels and domain confirmation/tree overlays use the same measured motion.
Report sheets, the level roadmap and offline-reward dialogs also preserve
fractional entrance travel without changing their actions or focus behavior.
Player-list entrances and notification entrance, swipe and hover positions use
the same measured-coordinate helper.
Player cards measure their actual width after padding and scrollbar changes;
their stat/action grids reserve integer-sized cells and all social actions have
48-pixel touch targets. Shared, inventory, shortcut and world grids round gutter
reservation up to avoid accidental extra rows.
Ranks uses the shared button chrome, sounds and search field. Its top three
players have live avatar viewmodels with turn controls, medal-colored podiums
and score comparison bars; narrow panels stack the podium cards. Player/name/ID
and guild/tag search preserves original rank numbers, and a personal-standing
filter complements the existing standing card. Avatar loading exposes retry
states and cleans up cameras, worlds and late completions.
Artifact visuals reject unfinished builds after departures, respawns, unequips
or a newer refresh, preventing stale nameplates and partial visual leaks.
Existing non-retired progression remains intact; full visual and multiplayer
review is tracked in `NOT_TESTED.md`.

The Premium shop loads its four developer products and four game passes from
the same `SharedData("MonetizationConfig")` bundle used by the server, rather
than waiting for a retired standalone module. Load failures are logged and
shown in the shop. Store section tabs measure their actual host width and
reflow into multiple full-height rows instead of squeezing six labels into
one phone row. Artifact shop cards no longer stack beam fans, halos and a
diamond icon over the elemental sprite; their acquisition badge says
"Shop exclusive". `verify_shop_catalog.luau` exercises the actual catalog loader
and tab geometry. This pass has not received rendered Studio/device signoff.
LayoutGuard now diagnoses component-owned layouts rather than globally
shrinking text, truncating labels, moving siblings or snapping animated groups.
Shared text does not truncate by default; standard button labels wrap at their
existing font size and remain visible to diagnostics. Explicit local text
fitting keeps essential text above a 12-pixel floor. Named page sections
attribute issues to their layout owner. The mobile level shortcut has a
header-height touch target rather than a 16-pixel label hitbox; rail/page
headings reserve the measured line height instead of clipping descenders.

The diagnostic ring holds at most 128 issues. Collision traversal resumes
across frames, including later siblings in large groups; collection and pair
work share the 256-step/deadline budget. Recurring deduplicated defects still
drive inspection priority. Hidden/clipped content and disabled world-space
layers are excluded. Only an element explicitly marked
`LayoutGuardRecovery="Canvas"` or `"FloatingPanel"` permits that recovery kind;
ordinary component geometry remains untouched. Canvas underflow is measured
on the scrolling axes from real content, including scale, scroll position,
positioned rows and trailing padding. Recovery preserves the other axis;
content already inside the viewport does not fabricate an overflow.

In the client developer console, invoke
`game.Players.LocalPlayer.PlayerGui.AstralForgeLayoutDiagnostics:Invoke()`
for copied owner/path/detail/sample records, the resize epoch, counters and the
actual tracked count. The endpoint is outside React-owned root descendants and
is removed on root retirement. Records are historical observations within the
current epoch, not a claim that every recorded issue is still mounted.
`verify_layout_ownership.luau` executes actual diagnostic, repair, binding,
collision and shared-text code; `verify_layoutguard_resize.luau` checks resize
resets without discarding learned priorities. Whole-game/device sign-off
remains open.

### Original branding

The shared logo uses original path-drawn lettering and an AF/anvil mark, with
cream and brass artwork rather than procedural diamonds or extra effects.
`tools/assetgen/build_branding.ps1` regenerates the transparent 4096x1536
wordmark, 1024x1024 compact mark and 2048x2048 square game icon. Roblox upload
IDs are recorded in `assets/asset_ids.json` and exported by `ArtKit("Icon")`.
Replacing artwork requires an upload and matching references; a local render
alone does not update the experience.

The authored mark/wordmark are integrated into desktop chrome, boot/loading
and server-transfer branding. They preserve their aspect ratio; short
landscape reserves separate space for the mark, status and wrapped tips.
Animated loading status now centers in its real parent instead of a fixed
left-aligned 340-pixel child. The retired Star Grid loading tip is replaced.
Image-instance probes preload all three assets, report failures and dispose
on completion or unmount. `verify_branding.luau` executes the actual lockup,
status, responsive boot geometry and preload lifecycle.

All three uploaded assets were visibly inspected in Studio and reported
`ImageLabel.IsLoaded=true`. Desktop, Galaxy A06 portrait and short-landscape
startup renders were inspected. This does not change the published
experience's icon metadata or constitute whole-game sign-off.

### Visibility-budgeted elemental characters

`CompanionPlayback.luau` owns one shared UI sprite clock instead of one
Vendor/Sprite connection per character and aura. At most 24 image layers
animate simultaneously. Admitted visible cards remain continuously animated;
additional cards retain their still pose until a slot opens. Admission scans
at most 64 registrations per pass, reaching later rows after scrolling.
Clipped/offscreen labels, disabled screens, invisible ancestors and fully
transparent CanvasGroups stop crop updates. The last release disconnects the
clock. Existing reduced-motion/still props and the platform reduced-motion
preference stop playback without removing character art or auras.

Equipped world companions retain their own owner: crop work runs only at
atlas cadence, respects the billboard draw distance and camera frustum, and
caps animated companions at 12. Character/aura frames stay synchronized.
`verify_companion_playback.luau` and the expanded presence checks execute
actual scheduler/culling code, including later rows, frame bounds, preference
changes and cleanup. Studio mounted all 57 character/aura pairs (114 layers):
all images loaded after scrolling, only 24 layers were active, clipped rows
stopped, hidden playback fell to zero, and unmount disconnected the driver.
This is workload/lifecycle evidence, not a CPU/GPU performance benchmark.

### Hex and authored-sprite presentation pass

The domain now uses a scrollable 2D hex grid with ancestor-path highlighting,
zoom controls and a stacked phone detail panel. Retired 3D-domain rendering
code was removed; progression and unlock rules are unchanged. Ambient
decoration uses slow mint/cyan/violet aurora curtains, with a seamless clock
wrap, fewer curtains on constrained devices and a still reduced-motion mode.

Bolt uses a custom twelve-pose sprite atlas, retaining his interactions,
pointer, speech and particles. Regenerate the local atlas with
`node scripts/draw_bolt.cjs`; uploading a replacement also requires updating
the image asset reference. Tutorial masks hide and block unrelated controls
while leaving the current required target accessible. Bolt, his pointer and
trails use fractional coordinates rather than stepped pixel offsets.

Star Charts and Signal Cipher have since been removed from active navigation,
protocol actions, server dispatch and presentation. Their saved progress and
historical leaderboard readers remain for compatibility. Salvage Runs and
Artifact Trials replace them with server-authoritative decisions and retry
protection. Forge Specializations replaces Star Grid while preserving earned
grid bonuses; the bounded migration and save/rejoin checks are documented
in the current sign-off.
Reports and settings choices/navigation reuse the shared controls. Resource
chips scroll horizontally instead of being discarded to fit either the desktop
topbar or the separate mobile header.
The logo uses custom vector strokes, and shared Text supports subtle shadows.

This is a verified presentation pass, not completion of the entire expanded
revamp. Trading, changelogs, mail, crew, overview, research, milestones and
artifact/crate refinements still need the additional design work requested.
Physical gamepad/mobile, human audio and multiplayer sign-off remain open.

The ranks follow-up removes over 1,000 lines of unreachable presentation,
retaining the active avatar podium, all fourteen player categories and their
data adapters. Gamepad focus now lives in the active dashboard. Regression
checks exercise that dashboard and its adapters rather than the retired code.
The latest authorized Studio Edit inspection confirms the character, authored
wheel and Black Market sources are synchronized through Argon. This does not
constitute Roblox publication; see `SIGNOFF.md`.

### Black Market and 2D wheel follow-up

The stable `Bazaar` route now opens only the Black Market. Its 36-item catalog
provides 24 hourly offers by default, with 2-8 units per player per offer:
these are personal purchase limits, not shared global scarcity. Categories,
search, sorting, quantity totals, saved supplies and the last 50 purchases are
available. Favorites and purchase history survive save sanitation and rejoining;
Quick Find category links use the shared Browse helpers.

Supply inspection shows current inventory holdings, selected quantity, total
cost and personal hourly limits without granting rewards or changing progression.
Single-supply offers are compared by flux per reward unit using large-number
arithmetic. Different crate keys, different boosts and mixed kits are not
presented as equivalent; sold-out matching packs remain visible for reference.
The pending legacy recovery notice uses the actual player's user ID, including
pooled tickets independently of already-settled pending prizes.

Prices equal a fixed amount of steady production time, discounted by 20-45%
and floored at 1,000 flux. Prices and balances retain Omega number/string
serialization. Orders validate quantity, offer, currency, bounded quote,
shipment identity and request ID on the server. Receipts survive the current
and preceding hourly shipment; replay returns the original result without a
second charge, reward or history entry. Client timeouts retain the same order
ID and expose a retry action, including after closing and reopening the page.
An uncertain transport response is not treated as a confirmed rejection.

The optional Experience Config `BlackMarketOfferCount` accepts integers from
12 through 36. It defaults to 24 when absent, and a server freezes the selected
count for its current shipment. A published key is still required to use live
tuning. Cross-server configuration changes reject incompatible quotes; a
globally versioned shipment/configuration rollout remains unfinished.

Retired bank balances and accrued claims, capped savings interest, term
principal (with earned interest for matured terms), profile pending prizes and
the legacy rollover's pending user prize are returned to Cash through the
existing atomic mutation/save-dirty path, not by mutating snapshot reads.
The payout and retirement markers commit together. Rejected transactions keep
the entitlement owed; repeated recovery does not pay twice. DataVersion stays
21. Recoverable pooled ticket value and completed unclaimed contracts now settle
once under the retirement policy documented below. Missing historical pots and
individual ticket prices were not retained by the old lottery. Purchased grid
bonuses remain permanent foundation bonuses; compatibility data is preserved.

The wheel uses an original enamel image with 2D numbered sectors, brass pegs,
a glass highlight, hub and responsive clicker. Shared reward glyphs remain
upright independently of rotor motion; small wheels retain readable numbers
instead of crowding the sectors. The result console uses the same authored
glyphs, not viewports. The unused flat/kit/machine renderers and their local
dependencies are removed. Console titles wrap, details use 12-pixel text and
the page scroll owns the wheel, console and complete prize legend.

Every player spin sends its saved `ExpectedSpin` sequence. The atomic grant
stores a latest receipt alongside the token, counter and pity state; replaying
that sequence returns the original award without rolling or charging again.
Stale sequences reject rather than becoming new spins. Receipt sanitation
preserves valid results across saves/rejoins. Interrupted requests keep the
same sequence through timeouts and screen remounts, and the confirmation action
remains available after a token was consumed. Late replies cannot release a
newer input latch. The wheel checks both prize ID and index against its catalog
instead of clamping a malformed result into a fabricated winner.

The reward pool, token rules, pity threshold and six-hour cooldown are unchanged.
The legend explicitly labels standard odds and explains the restricted pool
used by guaranteed spins; it does not present normal odds as guaranteed-spin
probabilities. Availability copy no longer promises a daily reset.

`verify_wheel_transactions.luau` executes the actual progression/reward and
atomic-owner code, covering replay, stale/invalid sequences, cooldown, pity,
free-spin rewards, copied/sanitized rejoin receipts and failed-grant rollback.
It also executes the actual client closure for double input, transport
uncertainty, timeout/remount retries, late reply isolation and invalid prize
responses. `verify_presentation.luau` checks sector, number and reward-glyph
alignment for all 20 prizes at four diameters and both motion preferences.

Authorized Studio UI verification awarded Prism Flux Cell on sequence 61,
consumed one token, advanced the counter to 62 and landed on sector 17 at 72
degrees. The next session retained the receipt and restored that same result
on the 359×718 portrait device and 705×338 landscape viewport. Wheel-specific
text-bound scans found no overflow on those two viewports. An earlier
unrepresentable Stardust award rejected without consuming a token or changing
the counter. These are bounded tests, not gamewide, real save-outage or
multiplayer sign-off. Other UI surfaces still reported LayoutGuard repairs.

`verify_black_market.luau` executes the actual reward/service code and atomic
rollback behavior. `verify_client_polish.luau` executes the actual market request
closure, and `verify_presentation.luau` checks every wheel winner's alignment,
upright labels and reduced-motion details. Desktop and 360-pixel portrait
captures confirm mounted character artwork, market reflow and the wheel face.
An 800×360 landscape capture confirms the compact resource/navigation shell and
scrollable market body. Studio was stopped and restored to its default viewport.
These are bounded observations, not sign-off for every screen, live spin
landing, purchase/save-failure recovery, multiplayer or the complete revamp.

## Getting Started

### High-resolution elemental artwork

`tools/spritegen/build_elements_hq.py` redraws the existing 57 elemental
animations at native resolution, rather than enlarging the old PNGs. Each
lossless 4096×4096 atlas contains 36 frames of 682×682 pixels: four times
the previous frame width and over sixteen times the pixel detail.
This is a 4K **atlas**, not 4K per animation frame. The engine may still
stream lower-resolution textures on constrained devices.

Generate with `python tools/spritegen/build_elements_hq.py`; add `--upload`
to use the existing Open Cloud uploader. Outputs and a resumable,
content-hashed manifest live in `assets/generated/sprites/hq`.
For faster generation, `python tools/spritegen/build_elements_parallel.py --upload`
uses a bounded rendering pool while one parent coordinates uploads and manifest
writes. Verified completed assets are reused; do not run both builders together.
Use `--workers 2` to reduce memory pressure. `--recover-rendered` validates
orphaned PNGs from an interrupted run of the same generator before reusing them.
Windows manifest sharing locks are retried with a bounded backoff; persistent
locks are reported instead of silently losing upload progress.
Only run `python tools/spritegen/apply_elements_hq.py` after all 57 uploads
finish. It verifies source hashes, dimensions, nonempty/distinct frames and
uploaded IDs before changing the shared sprite configuration. A partial
generation never replaces the working in-game atlas IDs.
The active presentation pairs all 57 animated characters with these original
effect atlases as a soft aura behind each companion. Characters are authored
with `tools/spritegen/build_characters.py`; after both collections are uploaded,
`tools/spritegen/apply_character_auras.py` pairs their IDs without replacing the
characters. Do not use `apply_elements_hq.py` to activate the old effect-only
presentation. UI auras share the character's playback speed and reduced-motion
setting; public equipped-companion auras reuse the existing distance-gated
animation clock. No additional particles, trails, or diamond overlays are added.
Run `lune run scripts/verify_character_auras.luau` to check all asset pairs,
layer order, reduced motion, crop sizes, and animation cleanup.
The new paired presentation still needs an in-game visual check.

ImageLabel playback uses
**170.5-pixel crops** in the delivered 1024-square UI texture, not the
682-pixel source-frame coordinates; those previously produced blank crops
even when assets reported successfully loaded. Fractional offsets preserve
the exact source boundaries. The 4K files remain source artwork; this does
not promise 4K GUI texture delivery. Corrected still and animated sprites
were visually checked in Studio, including the actual artifact shop.
Source atlas hashes,
all 2,052 nonempty frames and each original animation's distinct-frame count
were checked. Run `python tools/spritegen/verify_elements_hq.py` for the
packing/alpha/manifest-retry regression checks.

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
