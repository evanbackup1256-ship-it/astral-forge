# Verification gaps

All gaps below are open. They prevent final sign-off.

## Arcade implementation-stage gaps

- Headless kernels have been tested; live controls, bespoke models, mobile/controller inputs and latency behavior remain unverified.
- A versioned, idempotent in-flight stake refund/archive migration is implemented and headless-tested. Production rollout, interrupted-save recovery and legacy clients still need verification. The old wager entry point is disabled; saved funds are not erased.
- Hash/HMAC primitives match independent vectors, but seed entropy is not certified. Full player-facing outcome replay still needs integration.
- Starts and completions use explicit save boundaries. Intermediate steps use autosave/leave-save. Live save-failure/rejoin/crash recovery and audit-log delivery remain unverified.
- Strict flags and declared types are not a substitute for a real Roblox-aware analyzer.

- Direct Studio play launch remains unreliable: MCP reports "Start play hasn't finished yet" and Argon debug play fails with Windows error 126. A scripted StudioTestService.ExecutePlayModeAsync session did launch successfully, boot the game and render the client. The full device/multiplayer/failure matrix is still untested.
- Published Roblox version and existing server rollout: no new place publish or live-server source verification has occurred.
- Before/after Forge UI screenshots and approval of actual Forge layout changes: one initial runtime screenshot is preserved at audit/evidence/AF_BASELINE_DESKTOP_20261005.png. It is a pre-gameplay/layout-rewrite baseline captured after the exact-color theme extraction; it is not a matching before/after pair or visual sign-off.
- Roblox-aware strict type checking: no luau-analyze executable was found. Source flags/regex inventory and successful Lune compilation are not type proofs.
- Live DataStore failures, session contention, multi-server guild/market operations, TextService moderation failures, chat privacy restrictions and high-ping/low-FPS device runs remain unverified.
- The score-only arcade and guild community backend now have implementation and offline regression coverage. Live proof replay/device verification remains open; the persistent player bazaar, ascension/route migration and the requested remaining rank taxonomy/rewards still require implementation and explicit audit.
- A paid Bazaar lottery and random flux-pot payout were found during the public-arcade compliance sweep and removed from active client/service/remote paths. Its legacy profile field is preserved but no longer exposed or claimable. Live-server legacy behavior and UI interaction remain untested.
- Global strict typing, public data-shape aliases, module headers, bounded critical WaitForChild calls, complete decomposition and color centralization remain incomplete. Baseline inventories list the current gaps.
- Mapped third-party packages are inventoried. Their compatibility and interpretation under "every script" have not been signed off or silently exempted.
- Existing regressions include source-pattern checks and headless models. They do not by themselves establish actual responsive UI quality or runtime persistence semantics.


## Current crate/native-preview gaps — 2026-10-07

- Blender geometry/bake/export and native40-part asset import passed. Three runtime body textures initially failed fetching; retry/delivery investigation remains open.
- Native crate method fixtures passed owned/unowned bonus and key/inventory/count boundaries using a private profile. Full remote replay, actual persisted save/load, multi-client and device/VR testing remain incomplete.
- An unpublished local Studio bundle exposed startup failures in player/admin/guild persistence and Convergence MemoryStore construction. Isolated preview providers are implemented; native boot/save-open now succeeds. This does not validate live DataStore durability, MemoryStore distribution or MessagingService behavior.
- GuildCommunity is now integrated in this worktree. The confirmed main Studio place received only the audited GuildCommunity module and the narrowly scoped guild-name filter guard; source markers were verified. Live guild chat, cross-server delivery, moderation, and TextService behavior remain untested.


- CRATE-ROLL-001 now passes deterministic parity and Studio Edit-mode resolver checks. A full Play session against a disposable profile, persisted pity sequence across rejoin, live-client reveal and published-server behavior remain untested.

- ADMIN-MOD-001: the screenshot's nil-modulo error was not reproduced in the current worktree. An isolated mobile Studio run verified `GetAdminState` and one `GrantFlux` command with no error; all remaining command categories and the user's exact failing build remain untested.

- Guild community actions now route through Protocol, the request firewall, SessionGate grants, ServerServices, and an isolated UI panel. Chat and announcements use the existing TextService broadcast filter; records persist via UpdateAsync; local guild members receive events and production servers publish bounded, best-effort MessagingService updates. Static parity tests and the full offline suite pass. Cross-server delivery, live TextService behavior, moderation, community UI interaction, name reservation/cost/cooldown/history, taxes and diplomacy remain unverified or incomplete.

- STUDIO-UI-001: the older Guild `PagesSocial` bundle had a parse error. The corrected split source is now connected through Argon; a fresh Play run opened Guild → Community without a PagesSocial parse or Guild lazy-load error. Other Guild actions, multiplayer behavior, and published clients remain untested.

- Argon now reports a live `Astral Forge v2` connection to this worktree at `localhost:8000`, and the place was re-read after sync. Selected source checks cover the Guild module, Bazaar listing service/routes, and removal of the old `vfx` folder. A complete byte-for-byte comparison of all changed/added/removed instances is still open.

- ASCENSION-PATH-001: offline respec math/migration and the dedicated skill-tree route pass. No respec was triggered against a real saved profile. Phone, controller, and VR layout, real save behavior, and archived-data rollback remain unverified.
- EXPEDITION-PLANNER-001: offline route pricing, snapshot migration, reward/risk math and route payload wiring pass. The dedicated route opens the existing planner on its Expeditions tab. No live player Signals were charged; save/rejoin behavior, claim receipts, route interruption, and mobile/controller/VR layouts remain unverified.
- STUDIO-UI-003: obsolete Next Rank/Shift Plan navigation labels are replaced with Ascension Path and Expeditions; Argon sync and a clean Studio Play startup were confirmed. Directly opening those pages with player input, visual layout review, and published-server behavior remain unverified.
- RANK-CATEGORIES-001: nineteen player boards are wired to authoritative profile values and independent OrderedDataStores, plus the separate Guild board. The twelve spec categories include Bazaar, Events, and Hidden/Secret; the public Casino category is score-only and has no currency stakes or payouts. `verify_server_events` exercises the production event method; `verify_hidden_ranks` executes production milestone visibility and verifies hidden-claim scoring and Quick Find filtering. Fresh Studio Play accepted read-only `GetLeaderboard(BazaarDeals)`, `GetLeaderboard(Events)`, and `GetLeaderboard(HiddenSecrets)` requests; Events and HiddenSecrets returned empty boards. Live claim/reveal flow, nonempty production cloud data, season rollover/reset, cross-server freshness, rate-budget behavior under load, rewards/history/closest-progress, and phone/controller/VR layouts have not been tested in Studio or published servers.
- STUDIO-UI-002: fresh local Studio Play opens the Guild Community view without the PagesSocial parse or Guild module-load error. The Argon diff was reviewed and applied after the user approved its 16 legacy-object removals. Other Guild actions and published-server behavior remain untested.
- STUDIO-UI-002 latest-log follow-up: the confirmed Studio bundle contains the current `goalProgressText` fix; fresh Play reached `5.1.0 ui is up`, warmed 155 modules, and rendered Guild → Community without a game-source error. Studio returned to Edit mode. Other Guild interaction paths and published-server behavior remain unverified.

- Bazaar listing actions: compile, pure state tests, and source-level wiring checks pass; the purchase and payout routes are synced in Studio. No live create/cancel/purchase action was run because it would affect a real saved player's items or currency; marketplace UI, preview-store multiplayer fixtures, buyer delivery, payout claims, cross-server recovery, and published behavior remain open.
