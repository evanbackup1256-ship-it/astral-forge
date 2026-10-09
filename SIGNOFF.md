# Astral Forge v2 — Definition of Done Sign-Off

> **No row is signed off until the associated audit, repro, and regression tests are complete.**
> Last updated: 2026-10-09

## Current 7.0 pass

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
