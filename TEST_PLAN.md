# Astral Forge v2 — Test Plan

> Living document. Each system section links to its harness and sign-off row.
> Last updated: 2026-10-05

## 1. Continuous verification

Run before every commit:

```powershell
npm test                                  # lune run scripts/verify_project.luau
argon build default.project.json -x -o "Astral Forge v2.rbxlx"
```

## 2. Per-system test matrix

| System | Unit / extract tests | Boundary tests | Cross-system tests | Studio QA | Sign-off |
|--------|---------------------|----------------|-------------------|-----------|----------|
| Data stores | `verify_project.luau` profile version guards, sanitize, DataService residual gates | Max stacks, zero currency, overflow, session-lock steal simulation | Save/load roundtrip, migration DV21, trade recovery | Profile load/save with copied v4.12 fixture | Pending |
| Remotes | Session gate production path, RemoteFirewall residual | Replay/Gen/N nonce, high-value nonce, rate-limit overflow | Admin commands, economy mutations, trade handshake | Device Simulator + Controller Emulator | Pending |
| Replication | State push/pull extracts | Large state payload, partial state, schema drift | Mobile/console, low-FPS, high-ping | Join/leave stress | Pending |
| Currency | Economy/admin regress, envelope extract, Omega budgets | Zero, negative, NaN, `math.huge`, max persisted number | Inventory, trade, bazaar, casino, rebirth | Real purchase flow in sandbox | Pending |
| Inventory | InventoryMath extract | Empty/full bags, salvage parity, socket/market | Trade escrow, bazaar listing, casino reward crates | UI inventory drag/drop | Pending |
| Cooldowns | Session gate parity, client GRANT_ACTIONS | Fast repeat actions, clock skew, expired nonces | Rate limit vs optimistic rollback | Spam-click test | Pending |
| Guild | Guild math extract | Permission denial, role change, succession | Chat filtering, logo upload, announcement persistence | Multi-player guild session | Pending |
| Ranks | Rank math, progression/lab extract | Retroactive rewards, migration from old system | Skill Tree / Loadout Planner replacements | UI claim flow | Pending |
| Casino | Casino math guards, RTP checks | Bet limits, loss caps, provably-fair seed replay | Mid-round disconnect, rejoin, anti-cheat | Per-game viewport QA | Pending |
| Bazaar | Bazaar math guards, trade settle invariants | Price validation, anti-scam, escrow timeout | Inventory, currency, guild treasury | Listing/buy-order flow | Pending |
| Astral Forge | ForgeEchoMath, anomaly pulse, CommandMath | State machine transitions, overlapping inputs, cost overflow | Ranking, planning, social boosts | Visual continuity sign-off | Pending |

## 3. Boundary-test checklist

- [ ] Max currency (`MAX_PERSISTED_NUMBER`) — ensure no overflow/NaN.
- [ ] Zero currency — confirm no division by zero, rewards still apply correctly.
- [ ] Empty inventory — equip/salvage/market disabled gracefully.
- [ ] Full inventory — rewards queued/mailed instead of lost.
- [ ] Duplicate actions — idempotency via `TxnId`/`Gen`/`N`.
- [ ] Session lock stolen — profile marked broken, player kicked, no ghost session.
- [ ] Fast shutdown — lottery rollover, convergence flush, pending trade journals written.
- [ ] Moderated asset — CasinoKitLoader rejects with log, no crash.
- [ ] Offline rejoin — faulted trade recovered, convergence stashed contributions drained.

## 4. Device & performance QA

- [ ] Phone portrait / landscape
- [ ] Tablet 4:3
- [ ] Foldable mid-height
- [ ] Desktop 1080p / ultrawide
- [ ] TV-safe margins
- [ ] Software keyboard does not cover inputs
- [ ] Two simultaneous touches do not double-fire
- [ ] 30 FPS low-end device: no long loops in RenderStepped

## 5. Regression suite

Location: `scripts/verify_project.luau` (and any new `REGRESSION_SUITE/` scripts).

Add a test for every fix:
- Reproduce the original failure in a minimal harness.
- Assert the fix prevents it.
- Assert the fix does not regress the happy path.

## 6. Known release blockers requiring manual QA

1. Casino/crate kit asset ID is placeholder (`KitReady=false`).
2. All monetization ProductId/PassId values are placeholder zeroes.
3. Creator-follow reward has no production verification source.
4. Discord moderator allowlist uses placeholder/example IDs.
