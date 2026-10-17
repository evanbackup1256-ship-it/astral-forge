# Astral Forge v2 — Definition of Done Sign-Off

> **No row is signed off until the associated audit, repro, and regression tests are complete.**
> Last updated: 2026-10-10

## Current 7.0 pass

### Bounded character playback

The shared ElementFx component now uses one visibility-budgeted companion
clock rather than separate Vendor/Sprite drivers. Admission checks are
bounded to 64 registrations per pass and active work to 24 image layers.
Visible admitted cards animate continuously; excess cards keep their still
pose until space opens. Hidden/clipped/offscreen content, disabled screens
and fully transparent CanvasGroups stop crop writes. Reduced-motion/still
props and the platform preference are respected. Speed changes can return
to the configured default. Release is idempotent and the final release
disconnects the driver.

World presence stops work between atlas frames, culls behind-camera/offscreen
and out-of-range billboards, and caps animated companions at 12. Its paired
character/aura crops remain synchronized; platform reduced motion also
suppresses the equip fade. Actual-code tests cover 150 UI registrations,
continuous admission, later scrolling rows, visibility/clipping, platform
changes, exact crop math and disconnect/restart. World fixtures cover
camera gaps, frustum margins, actual draw distance, 30 companions, the
12-companion cap and reduced-motion/offscreen write suppression.

Authorized Studio mounted all 57 character/aura pairs. Registered=114,
Active=24; a visible crop advanced, a scrolled-off crop froze, hiding the
host produced Active=0, and restoring it resumed 24. All 114 images reported
IsLoaded=true after scrolling through the entire collection. Unmount
reported Registered=0, Active=0, Connected=false. This demonstrates bounded
work and cleanup, not representative CPU/GPU profiling or complete reaction
art. The full suite, 338-file O0/O1/O2 compilation and mapped Argon build
pass. Whole-game completion remains open.

### Original branding and responsive startup

Created and refined original centerline lettering, an AF/anvil compact mark
and a restrained square icon. The local RGBA sources are 4096x1536,
1024x1024 and 2048x2048. Uploaded references are recorded in the asset ID
manifest and shared ArtKit exports. All three uploaded images were visibly
inspected together in authorized Studio and reported IsLoaded=true.

The desktop lockup and loading/server-transfer branding use the authored
artwork with aspect-preserving fitting, not separate font labels or primitive
monogram strokes. Actual desktop and Galaxy A06 portrait/short-landscape
startup screens were captured. A fixed-width loading-status child was
incorrectly left-aligned on desktop; status glyphs now center in the actual
host. Short-landscape geometry separates the mark, wordmark, progress/status
and wrapped tips. The obsolete Star Grid tip is removed.

Raw asset-string preload probes returned Failure even for a known loaded
legacy image; ImageLabel-instance probes returned Success for all three new
assets. Startup now uses instance probes, reports genuine fetch failures and
disposes probes on success, exceptions and unmount. Actual-code regressions
cover these lifetimes, responsive lockups, centered status and boot bounds.
No claim is made that Roblox experience-icon metadata was published.

The actual server-transfer component was mounted separately for visual QA;
no real transfer was triggered. Final portrait and short-landscape previews
showed both status/message labels at 12 pixels with TextFits=true. They wrap
inside the phone host; missing optional messages no longer display Roblox's
default "Label". The responsive center keeps progress clear of the two
bottom rows. The previews were unmounted after inspection.

A live phone event notice exposed a separate "Community Forge" truncation.
Its owner now uses available mobile width, preserves the full title and
reserves distinct title/timer/progress rows. Actual banner fixtures cover all
event names at phone, landscape and desktop widths. The subsequent live
portrait Stardust Rain notice reported TextFits=true and zero current-epoch
layout diagnostics. This is not a full event/device certification.
The final full offline suite, 337-file O0/O1/O2 compilation, mapped Argon
build and whitespace checks pass. Whole-game, multiplayer and publication
sign-off remain open.

### Component-owned layout diagnostics

LayoutGuard no longer installs text scaling/truncation, narrows labels, moves
siblings, changes input layers or snaps animated CanvasGroups. Canvas and
floating-panel recovery require exact per-element opt-ins. Short canvases
produce diagnostics; adequate canvases do not. Disabled SurfaceGui/BillboardGui
layers are excluded alongside disabled ScreenGuis. The bounded 128-record ring
attributes named page sections and copies snapshots. Collection/collision work
resumes within a shared 256-step/deadline budget instead of starving later
sibling pairs. Repeated observations preserve learned inspection priority.

Shared button labels wrap without ellipses at their existing font size and
are no longer excluded from diagnostics. Shared essential text fitting keeps
a 12-pixel floor. The phone level shortcut uses the header-height hitbox.
Measured mobile-header spacing and desktop rail/page-title line-height defects
were corrected in their components, not by guard mutations.

The debugger confirmed React mounting removed the initial root-child endpoint;
the replacement PlayerGui sibling exposes the actual live guard. Current
Studio startup showed tracked=356, advancing counters and zero diagnostics.
Real Quick Find navigation opened Command. Desktop and Galaxy A06 portrait
(359x718 device; 359x660 root) and short landscape (705x338 device; 705x280 root)
showed zero issues in their final stable resize epochs. Earlier same-pass
Wheel and Shop inspections also showed no new portrait/landscape diagnostics.
Transient observations were retained rather than hidden; they are not an
all-screen sign-off. The four Command sections and saved wheel result remain.

The full offline suite, 337-file O0/O1/O2 compilation, mapped Argon build and
diff checks pass. Actual-code regressions cover later sibling collisions,
deadlines, endpoint lifetime/controller identity, non-mutating text, scaled
canvas adequacy/underflow on both axes, positioned rows/trailing padding,
recovery-kind isolation, bounded owner conflicts and local readable fitting.
Full mobile/editor/accessibility, multiplayer, save-outage and performance
sign-off remain open. No publication, commit, push or merge is claimed.

### Wheel replay, restored results and readable console

The sole active wheel remains 2D. Unused alternate renderers are removed.
Its numbered sectors now include shared authored reward glyphs where there is
room, with upright counterrotation and no independent glyph animation clocks.
Console titles wrap rather than shrinking to 9-pixel text; reward/error details
use 12-pixel text and additional vertical space owned by the page scroll.
Standard odds, guaranteed-spin rules and actual cooldown copy are distinguished.

Saved spin sequences and latest receipts prevent repeated input/retries from
rolling or consuming another token. Client uncertainty, timeout, remount and
late reply handling retain the original request. Saved receipts restore the
display, and mismatched prize identity/index never fabricates a winner.
Actual progression/reward/atomic-owner regressions cover replay, stale/invalid
sequences, cooldown, pity, free-spin reward bag reconstruction, rejoin sanitation
and failed-grant rollback. Actual client closure tests cover the recovery paths.
Presentation tests cover 20 winners at four diameters and both motion settings.

Authorized Studio UI spin 61 awarded Prism Flux Cell, consumed exactly one
token (10164→10163), advanced Spins (61→62) and landed on sector 17 at 72 degrees.
The next session preserved the same receipt; the actual phone wheel restored
that result at 359×718 and after rotation to 705×338. Page-specific text-bound
scans found no overflow. An earlier high-balance Stardust grant rejected with
unchanged token/counter/balance. Other shell surfaces still logged LayoutGuard
repairs and gaveUp; whole-game layout and performance sign-off remain open.

The full offline suite, 336-file O0/O1/O2 compilation, mapped Argon build and
diff checks pass. The specific temporary build was removed, and Studio returned
to Edit/default simulation. Argon Edit inspection confirmed the latest console,
glyph renderer and shared icon helper. No publication, commit, push or merge
is claimed. Real save outages and multiplayer wheel journeys remain unverified.

### Forge Specializations and retirement entitlements

Four live build choices now replace the player-facing Star Grid. Their previews
execute actual economy functions, while purchased grid levels remain unchanged.
The 960-line old renderer, unused purchase handler and obsolete story are
removed; internal route compatibility and legacy effect readers remain.
The real dispatch/atomic-owner regression covers full-vault rejection, cooldown,
same-build retry, saved gain/trade-off rates and live tuning. Snapshot/cache and
client regressions cover same-second reuse, bounded expiry, policy changes,
uncertain transport, stable retry, remount and stale callback isolation.

Authorized Studio desktop, 360-pixel portrait and short landscape inspections
show the actual build screen. Portrait text-bound checks found no overflow
within this page. A real UI change equipped Deep reserves; server snapshots
confirmed the larger capacity and unchanged foundation bonuses. Save release
completed, and the following play session displayed the saved Deep reserves
build. The account was restored to Balanced forge through the real UI after
the normal cooldown. This is not multiplayer, production-enforcement or full-device sign-off.
Other shell surfaces still logged LayoutGuard repairs/gaveUp during rotation;
the overall layout rewrite remains open.

Retired lottery ticket value now settles proportionally from the recoverable
saved pot, with a marker independent from pending prizes. Completed unclaimed
contracts on the last saved board settle once, with old compatibility records
retained. Tests cover pot conservation, copied/sanitized profiles, previous
prize refunds, already-claimed contracts and atomic precision/grant rollback.
The old lottery did not persist individual stakes, and its shared rollover key
could overwrite another server: exact stakes and missing historical pots
cannot be reconstructed from that data. No live lottery payout or real save
outage was injected for this verification.

The final offline suite, all 336 files at O0/O1/O2 and scoped diff checks passed.
The mapped Argon place build passed, and its temporary output was removed.
This remains uncommitted work, not a published or fully signed-off revamp.

### Active encounter implementation

Salvage Runs and Artifact Trials now have real server-authoritative saved
decision flows, three authored sites, six elemental trial rules, existing
Command companion ownership, bounded mastery and once-only milestone grants.
Live Config defaults are documented in README. The real service registry,
protocol, firewall, progression ladder, routes, Quick Find, save sanitizer
and state-adoption policy are wired. Startup verification caught and fixed
an omitted service registration and missing progression rules before handoff.

Offline encounter regression executes the existing reward function and atomic
clone/commit owner, including failed-grant rollback, repeated requests,
mid-run sanitize/rejoin, daily allowance, all family rules and high-balance
reward rejection. Actual client closure checks cover double taps, uncertain
transport, stable retry, remount and late completion.

Authorized Studio desktop and 360-pixel portrait captures show the actual
character-led trial, readable rules, saved scores and scrollable choices.
A live trial and freighter salvage were exercised through real UI input.
The existing test account has a stardust balance too large to represent these
small grants: final choices correctly reject, then explicitly finishing without
stardust advances the encounter with a zero-reward receipt. This is not evidence
of a successful positive live payout. Full character expression art, deeper
encounter variety and multiplayer/persistence-outage journeys are still open.
The overall revamp remains in progress; nothing is release-signed-off here.

### Consolidated revamp: market transactions and authored wheel

This section supersedes earlier Sky minigame and synchronization observations.
The overall consolidated revamp remains **in progress**, not release-signed-off.
Starting committed SHA remains `e17c01821c15a53f9a19db18e5def118261e86a9`;
the new work is uncommitted and has not been published to Roblox.

The authorized Astral Forge Studio instance (place 135153679037687) confirmed
the saved character/2D wheel/Black Market sources in Edit. Argon PID 26760 is
serving them, and the mapped place builds successfully. Desktop captures show
the actual character atlases and market; a Samsung Galaxy A06 simulation in
portrait shows the market header and filters wrapping, a horizontally accessible
resource header, scrollable stock and the mounted 2D enamel wheel.
An 800×360 landscape capture confirms the compact resource/navigation shell and
scrollable market body. Studio is back in Edit with device simulation stopped.
Startup logs include a missing optional `BlackMarketOfferCount` Experience Config
key; the default catalog count is used. Studio security is observational/bypassed
for this session, so these observations do not prove production enforcement.

Market regression tests execute actual catalog/reward code, invalid and
production-changed quotes, capacity rejection, sold-out stock, current/previous
shipment receipt replay, mismatched request IDs, large-number charges, atomic
partial-grant rollback, rejected/retried legacy refunds, persistent favorites
and bounded purchase history. The actual client request closure is tested for
same-frame double taps, transport uncertainty, stable retry IDs, timeouts and
completion after closing the page. The old removed-minigame presentation checks
now test 2D wheel landing alignment for all 20 prizes at four diameters, upright
sector labels and reduced-motion details, while retaining aurora/Bolt/report tests.

The full offline suite passed after replacing obsolete retirement assertions;
all 330 source/build files compiled at O0/O1/O2 with zero failures. Further edits
must rerun those gates. No live products, reports or market orders were submitted
for these visual checks. Live spin landing, multiplayer/disconnect/save-failure
journeys and full device/performance sign-off remain open.

The settlement and specialization sections above supersede this first refund
policy. Active encounter implementation is described above, but deeper
encounter content, merchant/procurement/admin systems, original logo deployment
and the complete mobile/editor rewrite remain unfinished. Earlier passing
guards must not be read as completion of those requirements.

### Native 4K elemental atlases

**Playback correction:** the original 682-pixel ImageLabel crops were
incorrect. A visible side-by-side client repro showed a blank high-resolution
crop despite `IsLoaded == true`, while the whole sheet and old sprite rendered.
The same replacement image rendered correctly with a 170.5-pixel crop:
682 source pixels scaled by 1024/4096. Shared metadata now separates the
4096-square source from the delivered UI texture. Both ElementFx and public
artifact glyphs inherit the corrected fractional coordinates. The importer
preserves this distinction on regeneration. Earlier load/offset checks below
did not prove visual correctness and must not be read as that sign-off.

After correction, a screenshot of the actual mounted ElementFx components
showed Fire, Crystal, Lightning, Neon, Frostfire and Water, with an animated
Fire companion. The underlying artifact shop also displayed its sprites
instead of blank cards. Source/frame-boundary regressions require exact
fractional playback crops inside 1024 pixels, not source-sized crops.

All 57 elemental sheets were redrawn at native 682×682 frame resolution,
packed into lossless 4096×4096 PNGs and uploaded. The completed manifest
records each source SHA-256 and replacement Roblox asset ID. Verification
checked all 2,052 frames for content, correct dimensions and no loss of
distinct poses compared with each legacy animation (Neon's intentional
seven repeated electrical states remain intact). These are 4K atlases,
not 4K individual animation frames.

The shared configuration is wired to all replacements. Studio Edit source
confirmed the new frame size and Fire ID; in Play, every one of the 57
ImageLabels loaded successfully. A real mounted ElementFx sample displayed
12 distinct Crystal frame offsets with then-incorrect source-sized crops while the
reduced-motion companion stayed at one offset. Diagnostic GUIs were removed.
Direct Edit-mode PreloadAsync calls failed for both new and known-working old
assets; successful client loading supersedes that non-client probe.

Native packing, crisp alpha-core preservation and transient/persistent
Windows manifest-lock handling have executable regressions. Full 4K texture
delivery depends on Roblox/device streaming; this does not guarantee every
device always renders its highest mip or establish game-wide mobile memory
performance.

### Ranks cleanup and Edit synchronization boundary

The active ranks dashboard now owns gamepad focus on entry and category/scope
changes. Executable fixtures verify live-host focus, mouse isolation,
missing/destroyed hosts and cancellation on cleanup. The retired ranks
renderer, podium/row/guild helpers and unused dependencies were removed:
1,070 presentation lines, without deleting the current dashboard or its
fourteen categories. Tests execute the retained metadata, score eligibility,
self-score and server adapters, including Omega ordering and stable ties.
Legacy guards now inspect the active renderer instead of counting motion
keywords in dead code. Physical controller behavior remains unverified.
The full project verifier passes after the cleanup. All 332 source/build
files compile at O0/O1/O2, the strict audit has zero errors and one existing
register-headroom warning, and the Argon place build succeeds.

PR #67 is merged and the presentation changes are saved in the repository.
However, the latest Edit-mode check still found the older Studio sources.
Argon is serving on port 8000 and waiting for its plugin's **Accept**
confirmation. A desktop click did not apply the changes, and the user was
unavailable to confirm them. Do not treat earlier Play-mode observations or
a successful Argon build as evidence of persistent Edit synchronization.

### Hex, tutorial and minigame follow-up

The 2D domain hex layout passed geometry sweeps across 1-16 nodes, eight tiers
and three zoom levels, plus desktop and phone portrait captures. Retired
3D-domain presentation was removed without changing progression. Report
reason/context/block controls and settings choices/navigation use shared
chrome; report tests execute payload preservation, failed-response retry and
success-only blocking. No real reports or blocks were submitted.

The final 128-pixel Bolt atlas loaded live and displayed four distinct frames.
All 57 sampled movement frames retained fractional coordinates; the pointer's
start-position error was zero in the sampled pose. A physical mouse test
registered one required-target click and zero hidden unrelated clicks through
the updated TextButton masks. Executable tests cover gamepad confirm
pass-through, CTA/next dispatch, exit duplicate suppression and focus confinement.
Physical controller navigation has not been signed off.

Cipher displayed four distinct 3D glyph models after local key presses:
44 inert parts, four changing model poses and zero network dispatches.
Phone captures showed both minigames and shared settings controls. Star Charts
mounted 47 parts for the first configured constellation. Reduced motion kept
its scene still, and replacement disposed of the preceding WorldModel.
Aurora mounted 14 curtains live; executable tests cover constrained/disabled
ambient, reduced-motion clock gating and continuous geometry at clock wrap.
Mobile-header geometry tests cover seven widths at two heights and preserve
all three unlocked resources, rather than dropping currencies that do not fit.
The real phone header mounted three chips in a 300-pixel canvas with a
161-pixel visible rail. Scrolling 139 pixels exposed the final chip; its right
edge was within 0.2 pixels of the rail edge. Aurora motion was observed live,
and a freshly loaded chart scene confirmed the next star's neon highlight.

The full offline verifier passes, and all 332 source/build Luau files compile
at O0/O1/O2. The strict audit reports zero errors and one register-headroom
warning. Argon responds and builds the place. These bounded checks do not
complete the remaining screen redesigns or establish game-wide visual,
audible, hardware or multiplayer sign-off.

### Earlier 7.0 checks

The ranks/player-card follow-up replaces fractional grid gutters with safe
integer reservation in shared, inventory, shortcut and world layouts. A live
70-case Studio sweep (14 widths, 2-6 columns) retained every intended column.
Expanded player cards now measure their own padded width: the real list at
431 pixels produced a three-by-two stat grid and two-by-two 48-pixel action
grid, with Report inside the expanded card. Isolated 288/439/440-pixel cards
also fit every action. Shared icon-bearing button labels explicitly remain
above their surfaces on Global-Z hosts.

Ranks now shares the game's buttons, SFX and search input. Desktop screenshots
confirmed three fully rendered avatars, medal podiums, names and scores;
a 380-pixel panel stacked the avatar cards with wrapped names. Turn was
exercised and changed the camera. Avatar accessory joints must settle before
camera framing; anchoring only the root corrected an initially oversized
bounding box. Offline tests execute actual loader success, failure, timeout
and disposal during both loading stages, plus literal search and existing
player/guild refresh behavior. No social/report/purchase mutation was submitted.
These are bounded checks, not a game-wide or multiplayer sign-off.

The master checklist below records the original specification and is historical:
casino gameplay was subsequently removed at the creator's request. Do not
reintroduce it to satisfy an obsolete checklist row.

Current work restores compact trade transport, session-change invalidation,
array validation and the dedicated polish regression guard. Selected domain
labels stay above depth bands, projected UI is excluded from generic layout
repairs, number suffixes update without amount changes, and artifact sprites
maintain their timing on dropped frames. Existing features are retained.

The full offline verifier passes. All 330 Luau files compile at O0/O1/O2.
The source audit reports zero errors and one register-headroom warning.
The Argon project build passes.
Studio MCP verified the synced version 7.0 source and clean client/server
startup. Desktop inventory/search/domain smoke checks and iPhone 17 Pro
portrait domain layout were observed. A second playtest confirmed the selected
domain label remains visible above the other nodes and the lattice owns its
layout. Studio was returned to edit mode with device simulation stopped.
Full multiplayer, viewport rendering,
audio playback and game-wide visual sign-off remain pending; see
`NOT_TESTED.md`. No full-game runtime sign-off is claimed.

The next live sweep fixed Research header overlap, compacted the Shop wallet
with the shared number formatter, and made feedback impact levels readable with
a separate touch-sized phone row. Shared buttons and the feedback dialog now
encode fractional pixel movement in measured scale coordinates rather than
integer UDim offsets. The regression covers actual coordinates, host resizing
and cleanup. No reports, feedback messages or purchases were submitted during
the nondestructive smoke tests.

The continued sweep reproduced and fixed an artifact visual rebuild completing
after player departure. Per-build identity and live-player/character checks now
reject stale completions and destroy their partial visuals. An isolated Studio
harness using two simulated players passed initial equip, level/effect refresh,
unequip, respawn, equip burst, departure during refresh, late join and disposer
cleanup. This verifies the presentation lifecycle, not network replication.
Shared Panel motion also retains fractional travel: live surface/shadow samples
matched 0.16, 1.4 and 7.75 pixels at two host sizes. A live domain-overlay
entrance sample recorded 17 fractional frames and settled at zero displacement.
Domain confirmation uses the same measured-coordinate path.

The report sheet, level roadmap and offline-reward dialog were mounted in
isolated live Studio checks. They recorded 7, 7 and 12 fractional entrance
frames respectively and all settled at zero displacement. Report submission,
blocking and reward collection callbacks were prohibited by the harness; no
such actions were taken. The diagnostic report module was removed afterward.

Audio follow-up independently preloaded both previously timed-out music assets.
"Celestial String Awakening 2" and "Space Station '98" returned successful fetch
status and nonzero durations (about 213 and 225 seconds). A subsequent director
snapshot showed the active deck loaded, playing and advancing, with a loaded
silent spare. The soundtrack regression now executes the actual director
against controlled Sound/task mocks: stale callbacks, active failure recovery,
pause/resume position, completed crossfade, all-failed retry and disposal passed.
This verifies control flow and asset availability in this run, not human audibility.

Player-list and notification position bindings now use measured scale
coordinates. Isolated live entrances recorded 11 and 13 fractional frames.
The player list settled at its intended 14-pixel right inset; the notification
settled at zero displacement. Notification slot/size animation, lifetimes,
swipe thresholds and gameplay actions were unchanged. Network dispatch was
replaced with a local response in the player-list probe.

## Master spec checklist

| # | Deliverable | Status | Evidence | Signed |
|---|-------------|--------|----------|--------|
| 1 | Astral Forge rewritten (`--!strict`, typed, decomposed, palette preserved) | Not started | — | — |
| 2 | Game-wide bug audit (`BUG_AUDIT.md`, `REPRO_LOG.md`, `TEST_PLAN.md`) | In progress | Initial sweep fixed and documented | Devin |
| 3 | Casino complete rebuild (unique models per game, provably-fair RNG, compliance) | Not started | — | — |
| 4 | Bazaar rebuild + Skill Tree + Loadout Planner replacements | Not started | — | — |
| 5 | Guild system (announcements, members-only chat, logos, settings, rename) | In progress | Community server/client implementation added; Argon build passes; Studio end-to-end and regression coverage pending | — |
| 6 | Ranks rewrite with expanded categories | Not started | — | — |
| 7 | Regression suite passes; `NOT_TESTED.md` reviewed | In progress | Argon build passes; Lune suite reaches existing Roblox `script.Parent` runtime dependency in `verify_economy_projection` and exits nonzero | — |
| 8 | No claims from narrow tests only | In progress | Audit trail created | Devin |

## System-level sign-off

| System | Audit complete | Bugs fixed | Regression added | Boundary tested | Cross-system tested | Sign-off |
|--------|----------------|------------|------------------|-----------------|---------------------|----------|
| Data stores | Partial | Yes | Yes (via verify_project.luau) | Partial | Partial | — |
| Remotes | Partial | Yes | Yes | Partial | Partial | — |
| Replication | Partial | Partial | Partial | No | No | — |
| Currency / economy | Partial | Yes | Yes | Partial | Partial | — |
| Inventory | Partial | Yes (R-19) | Partial | Partial | Partial | — |
| Cooldowns / rate limits | Partial | Yes | Yes | Partial | Partial | — |
| Guild | Partial | Yes (R-22–R-29) | Partial | No | No | — |
| Ranks | No | No | No | No | No | — |
| Casino | Partial | Yes (R-20–R-21, R-27–R-28) | Partial | Partial | Partial | — |
| Bazaar / trade | Partial | Yes (R-24) | Yes | Partial | Partial | — |
| Astral Forge | Partial | Yes (R-13–R-26) | Partial | Partial | Partial | — |

## Release blockers

| Blocker | Owner | Resolution required before sign-off |
|---------|-------|-------------------------------------|
| Casino/crate kit asset ID is 0 | Content/ops | Upload real kit asset and set `Kit` + `KitReady=true` |
| Monetization ProductId/PassId are 0 | Monetization | Populate real Roblox product/pass IDs |
| Creator-follow production verification | Engineering | Implement trusted follow check or remove production reward |
| Discord moderator allowlist placeholders | Engineering | Replace with real allowed moderator UserIds and shared-secret signing |
| Skill Tree / Loadout Planner design | Design/Engineering | Complete feature design before implementation |
| Per-casino-game bespoke models | Art/Engineering | Produce and integrate unique viewport models |

## Sign-off notes

- 2026-10-05: Initial defensive bug/security pass completed and committed (`8e6e8e2`, `07b9fb5`). This is an audit foundation, not full spec completion.
- 2026-10-05: Focused Astral Forge bug fixes + ForgeTheme/ForgeConfig/decomposition skeleton. R-13–R-18 fixed; `npm test` + `argon build` pass.
- 2026-10-05: Audit-driven bug fixes (R-19–R-23) + trade UID collision fix, casino free-scratch cap, guild name filter/leaderboard pagination. `npm test` + `argon build` pass.
- 2026-10-05: Additional audit fixes (R-24–R-26): lottery ticket rollover persistence, guild disband leaderboard cleanup, kicked-member profile cleanup. `npm test` + `argon build` pass.
- 2026-10-05: Casino round-history logging foundation (R-27) + `CasinoRng` foundation module (R-28). `npm test` + `argon build` pass.
- 2026-10-05: Wired `CasinoRng` into all casino games; round history now carries seed proof (R-28 complete). `npm test` + `argon build` pass.
- 2026-10-05: Guild rename implemented server-side with cost, cooldown, filtering, audit log, tag reservation, and member notification (R-29). Client UI remains pending. `npm test` + `argon build` pass.
- 2026-10-05: Added `docs/PRODUCTION_IDS.md` checklist for the two external release blockers (Casino kit asset ID and monetization Product/Pass IDs). These cannot be fixed without creating/uploading Roblox assets and products from the account that owns the experience. Code already falls back gracefully in Studio.
- 2026-10-06: Added persistent guild community service, request routing, filtering/moderation contracts, and Guild Community client UI. `argon build default.project.json` passes. Full Lune verifier exits nonzero in the pre-existing `verify_economy_projection` Roblox `script.Parent` dependency; no Roblox end-to-end test or guild sign-off claimed.
