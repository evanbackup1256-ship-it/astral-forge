# Astral Forge v2 — Definition of Done Sign-Off

> **No row is signed off until the associated audit, repro, and regression tests are complete.**
> Last updated: 2026-10-05

## Master spec checklist

| # | Deliverable | Status | Evidence | Signed |
|---|-------------|--------|----------|--------|
| 1 | Astral Forge rewritten (`--!strict`, typed, decomposed, palette preserved) | Not started | — | — |
| 2 | Game-wide bug audit (`BUG_AUDIT.md`, `REPRO_LOG.md`, `TEST_PLAN.md`) | In progress | Initial sweep fixed and documented | Devin |
| 3 | Casino complete rebuild (unique models per game, provably-fair RNG, compliance) | Not started | — | — |
| 4 | Bazaar rebuild + Skill Tree + Loadout Planner replacements | Not started | — | — |
| 5 | Guild system (announcements, members-only chat, logos, settings, rename) | Not started | — | — |
| 6 | Ranks rewrite with expanded categories | Not started | — | — |
| 7 | Regression suite passes; `NOT_TESTED.md` reviewed | In progress | `npm test` + `argon build` pass | Devin |
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
| Guild | Partial | Yes (R-22–R-26) | Partial | Partial | Partial | — |
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
