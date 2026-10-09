# Astral Forge v2 — Definition of Done Sign-Off

> **No row is signed off until the associated audit, repro, and regression tests are complete.**
> Last updated: 2026-10-09

## Current 7.0 pass

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
