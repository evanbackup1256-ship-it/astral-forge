# Verification plan

Contract: audit/MASTER_SPEC.md. Each system uses a named test group and an explicit coverage/gap record; do not treat the entire legacy suite as proof of the new features.

1. Preserve source/color baselines and capture actual pre-change UI views before approving Forge layout changes.
2. Reproduce defects from real pre-fix source with deterministic harnesses; retain source, expected/actual results and traces.
3. Verify typed contracts with a real Roblox-aware Luau analyzer. Lune compilation is a syntax gate, not a type-check gate.
4. Validate server operations with denied roles, malformed payloads, quota exhaustion, duplicate IDs, stale revisions, retry callbacks, failed saves, disconnects and reconnection.
5. Verify money/item conservation with zero, maximum and huge balances; full/empty inventories; duplicate settlement and rollback; concurrency across guild/market/trade/forge.
6. Check all public arcade games for audited seed/nonce paths, commitment/reveal proof, score bounds, history, privacy and rejoin; verify the public routes contain no wagers, cashout, or chance-based economy prizes. Inspect each game's distinct model in rendered views. Current offline coverage has fourteen kernels; live behavior and model review remain open.
7. Exercise bazaar listings, buy orders and offers across two players and server restarts; verify durable escrow, price checks, refunds and anti-scam boundaries. `verify_bazaar_listing_math` covers pure rules and `verify_bazaar_listing_service` checks source wiring/save ordering plus the player browser, sell form, seller history, and purchase-confirmation route. Live DataStore, two-player transfer and visual/device tests remain open.
8. Test ascension/route migration from old rank/plan fixtures, version upgrades, rollback, respec and invalid graph choices; verify expedition plan Signal commitment, saved terms, interrupted-trip migration and claim effects; confirm old user-facing references are removed.
9. Exercise guild announcements, text filters, membership checks per message, muted/banned users, pagination, logo moderation, settings, taxes, diplomacy and name reservation/cooldown conflicts.
10. Verify all player boards plus Guilds, their real profile counters/stores and own/server/global value parity; then verify retroactive eligibility, one-time claims, reward previews, history, search/sort and rank-up analytics. Current coverage has nineteen player boards and the twelve categories named in the master spec. Event participation and hidden-achievement reveal/scoring have production-method fixtures; Studio verification of the HiddenSecrets route, live claims, cloud parity, retroactivity, reward/history flows, rank-up analytics, and visual/device behavior remains open.
11. Render portrait/landscape phone, tablet, desktop, ultrawide, controller safe areas, and low-FPS/high-ping cases. Collect before/after screenshots and clean-console traces.
12. Run relevant regressions, the project suite, builds, and the final requirement-by-requirement audit. Leave SIGNOFF.md unsigned where any evidence is missing.
13. For the Blender crate kit, validate exact mesh/skin pairs and baked UV maps, verify loader import and ownership/equip paths, then collect ContentProvider results and rendered galleries on a fresh account, multiple devices and a published client. Current main-place Play evidence fetched all 40 texture IDs successfully in one Studio session; it does not replace those remaining checks.

Primary runnable entry: lune run REGRESSION_SUITE/run.luau. Per-system coverage is indexed in REGRESSION_SUITE/README.md.
