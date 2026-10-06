# Astral Forge v2 — Game-Wide Bug Audit

> **Binding rule:** No system is "done" because a happy-path test passed. Every entry below must include scope, risk, evidence, and sign-off.
> Last updated: 2026-10-05

## 1. Scope & Methodology

### 1.1 Systems inventoried

| System | Primary paths | Criticality | Audit owner | Status |
|--------|---------------|---------------|-------------|--------|
| Data stores / persistence | `src/Server/AstralForge/Services/DataService.luau`, `src/Server/AstralForge/Modules/Documents/` | Critical | Devin | In progress |
| Remote request pipeline | `src/Server/AstralForge/Services/ServerServices.luau` | Critical | Devin | In progress |
| Replication / state push | `src/Server/AstralForge/Services/ServerServices.luau`, `src/Client/AstralForge/UiCore.luau` | High | Devin | In progress |
| Currency / economy | `src/Server/AstralForge/Modules/EconomyMath.luau`, `src/Server/AstralForge/Services/CoreServices.luau` | Critical | Devin | In progress |
| Inventory | `src/Server/AstralForge/Modules/ProfileBagMath.luau`, `InventoryMath` | High | Devin | Pending |
| Cooldowns / rate limits | `src/Server/AstralForge/Services/SecurityServices.luau`, `src/Client/AstralForge/CoreKit.luau` | High | Devin | In progress |
| Guild system | `src/Server/AstralForge/Services/CoreServices.luau` (GuildService) | High | Devin | Pending |
| Ranks / progression | `src/Server/AstralForge/Services/PlayerBadges.luau`, Rank dashboard | Medium | Devin | Pending |
| Casino | `src/Server/AstralForge/Services/CasinoService.luau`, `CasinoKitLoader` | High | Devin | In progress |
| Bazaar / trade | `src/Server/AstralForge/Services/BazaarService.luau`, `Modules/TradeSuite.luau` | High | Devin | In progress |
| Astral Forge | `src/Client/AstralForge/pages/PagesSystem.luau`, `CoreServices.luau` | High | Devin | Pending |

### 1.2 Audit checklist per system

1. Inventory entry points (remotes, events, timers, player lifecycle hooks).
2. Identify authority boundaries (server-authoritative vs client-trusted).
3. Boundary test: max stacks, zero currency, overflow, empty/full inventories, duplicate actions.
4. Cross-system test: save/load, currency mutations, mobile/console, low FPS, high ping.
5. Document findings with file:line and severity.
6. Reproduce before fixing; record repro in `REPRO_LOG.md`.
7. Add regression test in `scripts/verify_project.luau` or `REGRESSION_SUITE/`.
8. Sign off in `SIGNOFF.md` only after the above is complete.

## 2. Known findings from initial sweep

| Severity | System | Location | Finding | Status |
|----------|--------|----------|---------|--------|
| Critical | Config | `src/Shared/AstralForge/Shared/GameConfig.luau:7229` | Generated config overwrites `SeasonTiers`/`Milestones` with `nil`, crashing CoreServices/PagesSystem. | **Fixed** (nil guard) |
| High | Sync | `src/Shared/AstralForge/Shared/ForgeTheme.luau` | Required by CoreKit but untracked; clean checkout breaks client boot. | **Fixed** (added to git) |
| High | Client runtime | `src/Client/SharedRuntime/modules/RuntimeKit.luau:983` | `AsynchronousActorScheduler:drain` leaves lock wedged if callback throws. | **Fixed** (pcall + finally) |
| High | Client camera | `src/Client/PlayerScriptsLoader.client.luau:26` | `CurrentCamera` captured once; Roblox can replace it, leaving default controls stuck. | **Fixed** (change listener) |
| High | Server economy | `src/Server/AstralForge/Services/ServerServices.luau:3369` | `VerifyCreatorFollow` grants reward with no server-side verification. | **Fixed** (Studio-only bypass) |
| High | Server data | `src/Server/AstralForge/Services/DataService.luau:1078` + `Document.luau` | Cache mutated before `UpdateAsync`; session-lock loss creates ghost session. | **Fixed** (write-first + broken-profile kick) |
| High | Server trade | `src/Server/AstralForge/Modules/TradeSuite.luau` | Trade settlement non-atomic across two profiles. | **Fixed** (fault journal + recovery) |
| Medium | Client UI | `src/Client/AstralForge/BrowseKit.luau:181` | `useServerNow(0)` causes near-per-frame re-render. | **Fixed** (0.1s floor) |
| Medium | Client telemetry | `src/Client/SharedRuntime/modules/RuntimeKit.luau:705` | `encodeTelemetry` does not guard `record.flags`. | **Fixed** (safeU32) |
| Medium | Client rate limit | `src/Client/AstralForge/UiCore.luau:5601` | Cooldown table evicts arbitrary keys on overflow. | **Fixed** (oldest-first) |
| Medium | Server loader | `src/Server/AstralForge/CasinoKitLoader.luau` | `InsertService:LoadAsset` silently accepts untrusted content. | **Fixed** (class allowlist + id guard) |
| Medium | Server runtime | `src/Server/AstralForge/Services/MatterRuntime.luau` | Hard assert on `rbxts_include/matter`; missing vendor = total outage. | **Fixed** (pcall + no-op fallback) |
| Medium | Server anti-cheat | `src/Server/AstralForge/Services/GameAntiCheat.luau` | Cash velocity detection observational only. | **Fixed** (EnforcementEnabled flag) |
| Medium | Server data | `src/Server/AstralForge/Services/BazaarService.luau` | Lottery state only in module memory, lost on shutdown/crash. | **Fixed** (DataStore rollover) |
| Medium | Server data | `src/Server/AstralForge/Services/ConvergenceService.luau` | Pending contributions dropped on fast shutdown. | **Fixed** (shutdown flush) |
| Low | Server logging | `src/Server/AstralForge/ModuleLog.luau` | Cyclic require with `ServerServices`. | **Fixed** (telemetry injection) |
| Low | Server documents | `src/Server/AstralForge/Modules/Documents/DocumentService/Document.luau:94` | Document hooks invoked unprotected. | **Fixed** (pcall) |
| Low | Server config | `src/Server/AstralForge/ServerConfig.luau` / `Document.luau` | `SessionLockSeconds` (180) mismatch with `SESSION_EXPIRE_TIME` (600). | **Fixed** (aligned to 600) |
| Release blocker | Assets | `assets/asset_ids.json:4` | `Kit` asset ID is 0 — casino/crate kit never loads. | **Mitigated** (KitReady=false warning) |
| Release blocker | Assets | `src/Shared/AstralForge/Shared/SharedData.luau` | All monetization ProductId/PassId are 0. | **Mitigated** (startup warning) |

## 3. Findings from focused Astral Forge audits

| Severity | System | Location | Finding | Status |
|----------|--------|----------|---------|--------|
| Medium | Security/cooldowns | `src/Server/AstralForge/Services/RemoteFirewall.luau:143` | `EXEMPT_ACTIONS` (Rebirth, ClaimDaily, ClaimAllMail, VerifyCreatorFollow, trade) bypass per-action cooldown entirely, allowing ~8 Hz spam via generic rate limit only. | **Fixed** (exempt cooldowns) |
| Medium | Astral Forge | `src/Server/AstralForge/Services/CoreServices.luau:183` | `PulseAnomaly` writes `profile.Anomaly.LastActionAt` but never reads it; no server-enforced minimum pulse interval beyond 0.08s firewall cooldown. | **Fixed** (min interval + config fallback) |
| Medium | Astral Forge | `src/Server/AstralForge/Services/CoreServices.luau:771` | Echo `Capture` can call `random:NextInteger(1, 0)` when no trait matches the dominant affinity, hard-erroring. | **Fixed** (fallback to full pool) |
| Medium | Astral Forge | `src/Server/AstralForge/Services/CoreServices.luau:4680` | `PendingAnomalyActions` cleared by table-reference identity; actions appended between snapshot and clear are silently lost. | **Fixed** (drain only processed prefix) |
| Low | Client settings | `src/Client/AstralForge/pages/PagesSystem.luau:343` | `SECTION_BY_ID[activeSection].touchOnly` indexes without nil-check; stale section id crashes settings. | **Fixed** (nil-check + fallback) |
| Low | Client settings | `src/Client/AstralForge/pages/PagesSystem.luau:371` | `isChanged` uses `tonumber(entry.default) or 0`, so string-valued settings never show as changed unless exactly "0". | **Fixed** (type-aware compare) |
| Low | Client state | `src/Client/AstralForge/UiCore.luau:5600` | Cooldown eviction uses wall-clock timestamps without monotonic guard; backwards clock can evict wrong entries. | Pending |
| Low | Client request | Multiple | `ActionRequest`, `PurchaseQueue`, `PlanningViews.useAction` each duplicate busy/generation/timeout logic on top of `dispatch`. | Pending |
| Info | Architecture | Compiled bundles | Codebase is roblox-ts-style compiled Luau (`__defs`/`__load` registry); no TypeScript source exists. Refactor must target `.luau` bundles. | Documented |

## 4. Additional findings fixed

| High | Inventory / trade | `src/Server/AstralForge/Modules/TradeSuite.luau:749` | Trade receiver inserts incoming relics under sender UID, silently overwriting a different owned relic (item loss). | **Fixed** (re-key incoming items with receiver NextId) |
| Medium | Casino / economy | `src/Server/AstralForge/Services/CasinoService.luau:154` | Free scratch card payout cap uses `profile.Cash*4`, allowing whales to win up to 4x their balance risk-free. | **Fixed** (flat FREE_SCRATCH_BASE cap) |
| Low | Casino / input | `src/Server/AstralForge/Services/CasinoService.luau:187` | Flip accepts any non-Cashout op as "Flip" on active round. | **Fixed** (validate op is Cashout or Flip) |
| Medium | Guild / safety | `src/Server/AstralForge/Services/CoreServices.luau:1243` | Guild names validated by charset only; no TextService filtering (ToS risk). | **Fixed** (filter via Security.Filter before Create) |
| Low | Guild / UX | `src/Server/AstralForge/Services/CoreServices.luau:1577` | `GetLeaderboard(page)` ignores `page` and always returns top 20. | **Fixed** (fetch 100, slice by page, cache page 0) |

## 4. Additional findings fixed

| Medium | Bazaar / lottery | `src/Server/AstralForge/Services/BazaarService.luau:19` | Lottery tickets live only in server memory; players lose paid tickets on shutdown even though the pot rolls over. | **Fixed** (persist Tickets in rollover snapshot) |
| Low | Guild / cleanup | `src/Server/AstralForge/Services/CoreServices.luau:1386` | Disband deletes guild doc and tag but leaves OrderedDataStore leaderboard row as an orphan placeholder. | **Fixed** (remove leaderboard entry on disband) |
| Medium | Guild / membership | `src/Server/AstralForge/Services/CoreServices.luau:1412` | Kick removes member from guild doc but does not clear the victim's `profile.Guild`; kicked player keeps bonuses until rejoin. | **Fixed** (clear victim profile + push state if in-server) |

## 4. Unresolved / release-blocker items

These require real Roblox assets, admin secrets, or product decisions that cannot be generated by code alone.

1. **Casino/crate kit asset ID is 0.** Upload the kit and set `assets/asset_ids.json["Kit"]` to the real ID, then set `KitReady = true`.
2. **Monetization IDs are 0.** Populate real `ProductId`/`PassId` values before release.
3. **Creator-follow verification** has no trusted production API; currently gated to Studio only.
4. **Discord moderator allowlist** in `AdminService.luau` contains placeholder/example IDs only.

## 5. Audit process log

| Date | Action | Result |
|------|--------|--------|
| 2026-10-05 | Parallel subagent sweep (Client / Server / Shared) | Findings consolidated above |
| 2026-10-05 | Defensive fix pass committed as `8e6e8e2` and `07b9fb5` | `npm test` and `argon build` pass |
| 2026-10-05 | Focused Astral Forge client/server/visual audits | New findings added above |

## 6. Gaps / NOT_TESTED cross-references

See `NOT_TESTED.md` for items that were not covered and why.
