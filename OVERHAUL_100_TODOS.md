# Astral Forge overhaul — 100-item working checklist

This checklist turns the active overhaul into 100 concrete, trackable deliverables. It preserves the binding specification in [MASTER_SPEC_REQUEST_20261006.txt](MASTER_SPEC_REQUEST_20261006.txt) and the public-game rule: arcade play has no betting, wagers, cashout, or chance-based economy prizes.

Checked items have current repository or test evidence. An unchecked item remains open; passing source tests alone do not imply live Studio, device, multiplayer, persistence, or published-game verification.

## Project direction and engineering baseline

- [x] 01. Capture and preserve the original user specification and its public arcade constraint.
- [x] 02. Record the current palette baseline and guard it with color regression checks.
- [x] 03. Keep a master bug audit, repro log, verification plan, regression suite, gaps list, and unsigned sign-off.
- [ ] 04. Inventory every shipped client, server, persistence, remote, UI, audio, event, and monetization system.
- [ ] 05. Resolve all remaining high-severity and repeated Studio console errors with repro evidence.
- [ ] 06. Check every changed module for strict types, explicit public signatures, and clear ownership headers.
- [ ] 07. Reduce oversized, tightly coupled modules into documented, testable units.
- [ ] 08. Remove unbounded critical waits, deprecated APIs, implicit globals, and unsafe casts.
- [ ] 09. Put shared colors, tuning values, limits, and asset references in named configuration.
- [ ] 10. Keep every final claim linked to direct test, runtime, visual, or persistence evidence.

## Bug audit, data, remotes, and resilience

- [x] 11. Add project-wide syntax checks across the current Luau source set.
- [ ] 12. Exercise profile load, save, shutdown, retry, migration, and multi-server conflict paths.
- [ ] 13. Exercise malformed, missing, oversized, duplicate, and stale remote payloads.
- [ ] 14. Verify per-action rate limits, session grants, idempotency, and replay handling.
- [ ] 15. Test zero, maximum, and huge currency values without rounding or nil arithmetic.
- [ ] 16. Test inventory empty/full, capacity boundaries, duplicate IDs, locks, and equipped-item rules.
- [ ] 17. Test disconnect and reconnect during every multi-step reward or purchase flow.
- [ ] 18. Test save/store outages, quota exhaustion, failed callbacks, and recovery.
- [ ] 19. Run multiplayer concurrency checks for trade, guild, market, and reward settlement.
- [ ] 20. Reproduce and close every open issue in BUG_AUDIT.md with before/after traces.

## Forge architecture and core progression

- [ ] 21. Decompose the Forge into service, roll resolver, cost, UI, inventory, persistence, analytics, and anti-cheat modules.
- [ ] 22. Keep all Forge transitions server-authoritative and schema-validated.
- [ ] 23. Enforce the Idle → Charging → Rolling → Resolving → Animating state machine.
- [ ] 24. Reject or queue overlapping Forge actions deterministically.
- [ ] 25. Make Forge costs, results, and retries idempotent across disconnects.
- [ ] 26. Verify Forge roll fairness and log all material transitions.
- [ ] 27. Replace scattered Forge color literals with named theme entries.
- [ ] 28. Move Forge tuning constants into documented configuration.
- [ ] 29. Preserve established animation feel and recognizable rarity cues.
- [ ] 30. Capture matched before/after Forge views at desktop and mobile sizes.

## Public arcade games and fairness

- [x] 31. Replace the public casino route with a score-only arcade model without wagers or cashout.
- [x] 32. Add the four requested arcade games and persist their score-only rounds.
- [x] 33. Add replay/version fences and private state projections to the arcade engine.
- [ ] 34. Independently audit all fourteen arcade games, their scoring rules, and edge cases.
- [ ] 35. Verify fourteen distinct, high-quality game-specific 3D viewport models in rendered Studio views.
- [ ] 36. Remove duplicate, generic, placeholder, or incorrectly reused viewport models.
- [ ] 37. Verify viewport cleanup, camera lifetime, object disposal, and loading fallbacks per game.
- [ ] 38. Add per-game motion, lighting, VFX, sound, and reduced-motion behavior.
- [ ] 39. Verify reconnect, interruption, repeated input, and server restart recovery for every game.
- [ ] 40. Run a live Studio/play and published-client arcade regression without economy rewards.

## Bazaar marketplace service and escrow

- [x] 41. Add a pure listing transition model with bounded prices, leases, and idempotent settlement rules.
- [x] 42. Add a durable listing record store and an ordered public browse index.
- [x] 43. Reserve a listing record and save seller item escrow before making it publicly active.
- [x] 44. Add seller-only cancellation and idempotent item recovery.
- [x] 45. Add authenticated, rate-limited, profile-granted purchase and seller payout actions.
- [x] 46. Save payment intent before buyer debit and retain a pending recovery marker.
- [ ] 47. Verify purchase delivery, payout, cancellation, and retry flows against two real Studio profiles.
- [ ] 48. Verify market escrow across DataStore restart, server hopping, item-capacity failure, and save outage.
- [ ] 49. Add market pagination, stale-index cleanup, seller listing history, and buyer receipts.
- [ ] 50. Add persistent buy orders, offers, trade escrow, and anti-scam checks.

## Bazaar player experience and commerce surfaces

- [ ] 51. Add a player-facing listing browser with rarity-aware item cards and transparent prices.
- [ ] 52. Add an item listing form with server-validated price bounds and clear fee/payout preview.
- [ ] 53. Add My Listings with status, expiry, sale, cancellation, and recovery states.
- [ ] 54. Add a buyer confirmation panel showing item, seller, price, and resulting balance.
- [ ] 55. Add durable pending-delivery and seller-payout recovery affordances.
- [ ] 56. Add search, sorting, filters, and accessible controller navigation.
- [ ] 57. Add a responsive grid with usable phone, tablet, desktop, and console layouts.
- [ ] 58. Add price history only where reliable historical data exists.
- [ ] 59. Add clear, consistent purchase sounds, errors, loading states, and success feedback.
- [ ] 60. Verify Bazaar visuals remain distinct from the arcade and match the established palette.

## Progression replacement and expeditions

- [x] 61. Replace Next Rank with a versioned branching Ascension Path model and UI route.
- [x] 62. Replace Shift Plan with an Expedition Planner route and saved plan model.
- [x] 63. Add migration fixtures that preserve unknown legacy fields and map old progression data.
- [x] 64. Guard respec, path costs, route costs, and saved expedition terms with pure tests.
- [ ] 65. Verify live profile migration, rollback, and reward parity on legacy save fixtures.
- [ ] 66. Add readable progression previews, branch comparisons, and respec consequences.
- [ ] 67. Confirm all obsolete user-facing Next Rank and Shift Plan labels are removed.
- [ ] 68. Verify expedition commitment, interruption, route consequences, and claim persistence in Studio.
- [ ] 69. Test invalid graph choices, insufficient resources, repeated claims, and stale plans.
- [ ] 70. Capture desktop and mobile views for both replacement systems and review them visually.

## Guild community, governance, and presentation

- [x] 71. Add server-checked guild chat, announcements, settings, and logo review routes.
- [x] 72. Add membership/role validation, text filtering hooks, and bounded guild message input.
- [x] 73. Add leader rename and lifecycle regression fixtures for stale/deleted guild records.
- [ ] 74. Verify chat filtering, moderation, mute/ban, pagination, and reconnect in live multiplayer.
- [ ] 75. Add persistent announcement editing, pin/archive/expiry, attribution, and notifications.
- [ ] 76. Complete guild logo selection, moderation, caching, fallback, and change history.
- [ ] 77. Complete configurable join mode, member cap, and role permission matrix.
- [ ] 78. Define and verify guild tax, treasury, and diplomacy rules.
- [ ] 79. Complete rename reservation, cost, cooldown, audit log, and member notification.
- [ ] 80. Review Guild UI on phone, desktop, controller, and with long names/large rosters.

## Ranks, UI consistency, accessibility, and release

- [x] 81. Add nineteen separately queried player boards and category metadata, including persisted Bazaar Deals, live-event participation, and claimed hidden-achievement counts.
- [x] 82. Add board category filters, search, current-player queries, and stale-response guards.
- [ ] 83. Complete all twelve requested rank categories with authoritative criteria and migration.
- [ ] 84. Add rank reward previews, one-time claims, history, closest-to-completion, and analytics.
- [ ] 85. Verify retroactive rank eligibility and reward claims against legacy profile fixtures.
- [ ] 86. Standardize open/close behavior, exit controls, focus restore, and sound across every overlay.
- [ ] 87. Fix all known clipped, overlapping, cramped, page-scroll, and text-fit UI defects.
- [ ] 88. Verify touch targets, keyboard/gamepad flows, safe areas, and short-screen scrolling.
- [ ] 89. Verify high-contrast text, reduced motion, VR comfort, and readable animated titles.
- [ ] 90. Run a complete visual sweep on phone portrait/landscape, tablet, desktop, ultrawide, and console.
- [ ] 91. Audit UI sound consistency, cue coverage, interruption, voice budgets, and volume settings.
- [ ] 92. Verify premium shop and purchase overlay centering, cancellation, pending state, and retry.
- [ ] 93. Verify every server event produces its promised in-game visual and audio effect.
- [ ] 94. Rebuild crate models and useful skins, then verify import, appearance, ownership, and equip behavior.
- [ ] 95. Verify admin commands, permissions, command search, suggestions, feedback, and audit records.
- [ ] 96. Perform the full Studio Play smoke pass with clean server/client logs.
- [ ] 97. Perform high-ping, low-FPS, multiplayer, controller, and persistence failure tests.
- [ ] 98. Reconnect Argon and compare every changed/added/removed Studio object to source.
- [ ] 99. Publish only after a requirement-by-requirement review and the user’s release approval.
- [ ] 100. Keep SIGNOFF.md unsigned until every required section has direct evidence and no open release blocker.

## Current verification snapshot

- `lune run scripts/verify_project.luau`: passed on 2026-10-07, including the production `LogoLockup` render regression for compact branding.
- `lune run scripts/compile_all.luau`: passed (348 files at O0/O1/O2).
- `argon build default.project.json -x`: passed.
- Rank firewall parity is now covered: all nineteen configured player boards pass the `GetLeaderboard` source allowlist check. Bazaar Deals is projected through persistence, global/store, own-score, and same-server paths. Event participation counts once per positive-collection live event window. Hidden/Secret ranks count claimed hidden milestones, reveal only after completion, and stay out of Quick Find before server disclosure. The production method fixtures pass; live HiddenSecrets remote/claim checks, cloud behavior, rewards and history remain open.
- Studio Play accepted read-only `GetLeaderboard(BazaarDeals)`, `GetLeaderboard(Events)`, and `GetLeaderboard(HiddenSecrets)` requests; Events and HiddenSecrets returned empty boards, and the Studio console showed the game booted to `5.1.0 ui is up` without game-source errors. Studio returned to Edit mode.
- Argon Edit-mode readback confirms the current Studio place has the compact wordmark fit/minimum-size change from this worktree. Matching screenshot review at the baseline viewport remains open.
- Bazaar actions have pure/source-wiring coverage only; live two-player and DataStore verification remains open.
- Guild create/rename now has production-source regression coverage for actual broadcast filtering, censorship, missing/error responses, input bounds, and fail-closed routing; live TextService and saved-profile verification remain open.
- Studio is in Edit mode. Argon is connected to this worktree; selected Guild/Bazaar sources were checked after sync, while a complete source/object comparison remains open.
- `SIGNOFF.md` remains unsigned.
- Crate texture follow-up: removed unverified standalone overrides from the uploaded 20-skin Blender kit; the main-place Studio Play client fetched all 40 baked mesh textures successfully in one session. Regression suite includes the kit manifest test. Rendered post-change appearance, new-user and published-client delivery, ownership/equip UI, and persistence/device coverage remain open; item 94 stays unchecked.
- Arcade integration slice: fourteen score-only games pass engine/privacy/replay/save tests; the four added games have dedicated active-page controls, Quantum board-cycle checks, CardTower state recovery, and legacy practice-table removal tests. Studio Edit source readback confirms Argon sync. No Play interaction, phone/controller/VR render, distinct-model review, or published-server verification has been performed.
