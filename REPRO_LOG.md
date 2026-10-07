# Reproduction log

## BUG-001: Missing icon atlas entry

Repro source: the preserved old primary ArtKit, copied before repair to the local temporary backup. The permanent baseline source digest is retained in source inventory; the old offending expression was VECTOR_ICON_INDEX[kind] % 2.

Steps: execute the actual old atlas-face renderer with kind = "UnknownIcon". Expected: a safe fallback icon. Actual: attempt to perform arithmetic (mod) on nil and number. The pre-fix harness asserted a failing pcall containing "mod"; the patched source was exercised with missing, invalid, numeric and unknown icon kinds.

Existing evidence: scripts/verify_render_sources.luau and scripts/verify_runtime_feedback.luau. These exercise the real functions in a headless environment; they do not prove the published game is on the same code or that all pages render.

## BUG-002: Deleted guild resurrection and retry approval leakage

Pre-fix callback source is retained in audit/repro-fixtures/GUILD-RESURRECTION.before.txt with its origin/digest. Expected: no mutation, no cache update and no success when the durable document is missing. Reproduction variants: missing live document with cached membership, and UpdateAsync callback retry from a valid document to a deleted document. Executed result: the preserved callback accepted the missing durable document and produced one durable write from the cached document. The fixed callback rejected it with zero writes and no cache/leaderboard advancement. A valid-first/deleted-second retry was also rejected. Valid writes, denied transforms, unavailable storage, Studio-only fallback, confirmed-deletion cache eviction and transient-read cache retention passed.

Reproduction harness: scripts/verify_guild_document_lifecycle.luau, which compiles and executes the actual callback source. The pre-fix source is preserved separately and intentionally reproduces the defect. Coverage gap: mocked service semantics, not a live multi-server DataStore session. Status: code corrected and headless regression verified; runtime closure remains open.

## BUG-003: Unfiltered guild identity

Source reproduction: `GuildService.Create` accepts a name argument and persists it into the guild document. Before the route guard, raw player text could reach this argument unfiltered. The create/rename route now calls the production `SecurityServices.Filter:Apply` broadcast filter before persistence and fails closed if filtering is unavailable or returns no text. The service still validates length and allowed characters after filtering; censorship placeholders that fail this rule are rejected rather than persisted. The caller payload is cloned before the filtered name replaces its value.

Verification: `scripts/verify_guild_identity_filter.luau` extracts and executes the production `Filter:Apply` method and the production create/rename route guard. It checks raw-input truncation to the 28-character bound, user attribution, successful filtered result, censorship-placeholder output, TextService exceptions, nil output, missing filter service, failed filter result, payload immutability, and that unrelated actions do not run the identity filter. It is part of `scripts/verify_project.luau`. `verify_guild_community_wire` independently guards route-to-service wiring.

Boundary: no actual guild was created or renamed in a saved player profile. Live Roblox TextService censoring, filtered-name rendering, and published-server parity remain unverified.

Studio parity: in Edit mode for the confirmed Astral Forge place (PlaceId 135153679037687), the `GuildCommunity` ModuleScript was updated to the bounded MessagingService implementation from this worktree, and `ServerServices` received the same fail-closed create/rename filter guard. Read-back confirmed the message subscription and guard are present. No Play session was run, so runtime delivery and live filter results remain unverified.

## BUG-004: Public Bazaar wager survived the arcade conversion

Source repro: the public Bazaar still displayed “Lottery”, charged flux for tickets, selected a winner from active players, and exposed a prize-claim action after the casino had been converted to score-only play. Expected: no public wager, lottery draw, or random currency/item payout anywhere in the experience. Actual: `BazaarService` accepted `Game = "Lottery"`, and the client presented ticket purchase and prize collection controls. Removed the lottery service, active math, remote allow-list entry, client tab, and controls. The legacy player-profile field is preserved without being presented or paid. The regression checks both the route surface and profile-data preservation. Studio play/publish and old-server migration behavior remain unverified.

## BUG-007: Most expanded rank boards were rejected by the request firewall

Reproduction: compare the `GetLeaderboard` IDs presented by `PagesSystem.BOARDS` to the `RemoteFirewall` branch for `Protocol.Actions.GetLeaderboard`, then submit one of the nine additional IDs (`Taps`, `ItemsFound`, `CratesOpened`, `AnomalyPulses`, `OrdersCompleted`, `Combat`, `Crafting`, `ArcadeScore`, or `Seasonal`). Expected: a configured board ID passes validation and reaches the server's mapped OrderedDataStore. Actual: the guard accepted only `Flux`, `Rebirths`, `PlayTime`, `Dust`, `Cores`, `Domain`, and `Worlds`, so each additional board was rejected as `invalid leaderboard` before service dispatch.

Correction and evidence: added the nine configured IDs to the firewall allowlist. `scripts/verify_rank_categories.luau` now checks that every current player board is also admitted by the live firewall source, in addition to its existing client/store/value projections. The focused test, full suite, Luau compile sweep, and Argon build pass. Direct Roblox remote calls, cloud OrderedDataStore availability, and cross-server results remain unverified.


## PREVIEW-STARTUP — unpublished Studio bundle

Repro: build default.project.json into a local rbxlx, open without publishing, run Play. Expected: the explicitly enabled Studio preview can boot with isolated test data. Actual: DataService.new aborts at GetDataStore before fallback, followed by endless GetSession startup warnings. Native stack: DataService:675; AstralForge:140; bootStep:93; timedBuild:112. Console reproduced in local verification Studio 46432544-1f1c-4367-88b7-e7015cb054b9, PlaceId0/GameId0.

Change under verification: shared unpublished-only preview providers for ordinary and ordered stores across DataService, GuildService and GameService. Native/published callers still use the supplied native accessor and propagate its failures. New fixture covers gating, isolation, rollback/cancellation, yield rejection, metadata and sorted pagination. Full worktree regressions pass; native constructor synchronization/startup recheck is still in progress. This is not live DataStore sign-off.

## CRATE-APPEARANCE — inconsistent default model

Source repro: CrateStage selected crate.ModelId for Classic, but CrateRevealExperience passed the Classic skin directly into the reveal. Expected: the same base crate in shop/opening. Actual: new base rigs switched to the classic chest during reveal. Added shared typed CrateAppearance resolver for both paths, with equipped-skin priority and legacy fallback tests. Native UI verification remains open.


## CRATE-ROLL-001 — added-crate pity rarity labels

Pre-fix reproduction: the twelve added crate definitions used uppercase `PityRarity` values while the item rarity catalog and weights use title-case names. When the pity threshold was reached, `rarities[crate.PityRarity]` returned nil and `CrateRoll.MinimumRank` treated the pity rank as zero, so the guaranteed-rarity filter did not activate. Corrected the new crate labels to the catalog's exact casing, then moved weighted selection into typed `CrateRollResolver` with explicit finite/nonnegative weight and random-result checks. The server resolver now uses the shared `CrateConfig` rarity order.

Evidence: `scripts/verify_crate_expansion.luau` asserts every added pity rarity is a catalog label; `scripts/verify_forge_roll_resolver.luau` compares deterministic valid-input results against the established roll function across boundaries and pity levels, and checks rejection of negative weights. The full headless regression suite passed. Studio Edit-mode execution loaded the resolver/config and verified an activated pity roll returns the Legendary definition. This does not verify a live player profile save, network receipt path, client reveal, or published server.


## ADMIN-MOD-001 — reported nil modulo crash

The reported error was not reproduced in the current worktree build. Source inspection found no modulo expression in `AdminService`; a disposable local Studio play session completed `GetAdminState` and a `GrantFlux` action through the real remote and persistence preview, with no error in Output. The local UI booted and rendered at the tested mobile viewport. This is only a smoke test: the full command catalog, malformed inputs, moderation, and the specific screenshot build have not been exercised, so the reported issue remains open.


## STUDIO-UI-001 — guild page parse failure in the confirmed place

Reproduction: the user's 2026-10-07 Studio log showed `PagesSocial:3573: Expected '}' (to close '{' at column 26), got ')'`; opening the Guild page then cascaded into `Requested module experienced an error while loading` and a React Guild page boundary error. Expected: the Guild page module loads and its UI can render. Actual: the live Studio `PagesSocial` contained extra closing parentheses in the guild chat, announcement, moderation, and logo section entries. The repo's current split `GuildCommunityPanel` implementation does not contain these malformed expressions; this proved the live bundle was stale/divergent from the worktree. Removed the four extra parentheses in the confirmed Astral Forge place (PlaceId 135153679037687).

Verification: `loadstring` compiled the complete live `PagesSocial.Source` with no error, and `require` in Studio Edit mode returned the module table. Worktree syntax scan and `scripts/verify_social_remake.luau` cover the maintained split source. This turn did not start Play, so there is no new runtime page-render evidence. Earlier Play boot evidence in this entry was from the initial two-parenthesis repair; it does not prove this follow-up bundle correction rendered in Play. Guild action behavior and published servers remain untested.


## ASCENSION-PATH-001 — no player respec for invested Domain branches

Source reproduction: the existing Domain lattice exposed branch unlocks but no player-accessible respec operation. Expected: a player who has bound branches can pay a visible cost, reset the known branch choices, and recover the skill points actually invested. Actual: only an administrator could clear nodes, while ordinary players had to keep every chosen branch.

Correction: added independent `Domain.TreeVersion`/`RespecCount` fields and a migration that preserves all other Domain values and existing node markers. `AscensionPathMath` quotes a Stardust price from Domain rank and prior respec count, counts costs only for configured nodes, preserves unrecognized inert markers, and returns only the known invested point total. Protocol/firewall/server dispatch and client state adoption are wired; the tree has a two-step confirmation and shows cost/refund details.

Evidence: `scripts/verify_ascension_path.luau` exercises legacy migration, unrelated Domain-field retention, true/legacy numeric unlock markers, insufficient funds, invalid rank, unknown nodes, refund accounting, cost deduction and repeat pricing. It is included in `scripts/verify_project.luau`; the full offline suite, syntax scan and Rojo build pass.

Boundary: no Studio action was invoked against a real player save and no mobile/controller screenshot was captured. Dedicated Ascension Path and Expedition Planner navigation now replace the old Next Rank/Shift Plan destinations; opening those pages through live UI input is still unverified.


## EXPEDITION-PLANNER-001 — expedition launches had no player planning or supply tradeoff

Source reproduction: the old launch accepted only a route ID and started immediately, while every expedition used one duration/reward profile. Expected: players can compare route approaches, commit a real resource choice, and see that choice shape a persistent expedition. Actual: expeditions exposed no route plan, no supply commitment, and no saved plan snapshot.

Correction: added versioned route snapshots to `Command.ActiveExpedition`, with `Standard`, `Charted`, and `Salvage` choices. The server validates the plan, checks and deducts Signals in the same profile mutation that launches the trip, and stores its reward/risk terms. The client now presents the route tradeoffs before launch. Claim uses the saved snapshot rather than trusting the client or silently changing a trip when configuration is edited. Old active expeditions migrate to the free Standard plan. Plan costs, duration/reward bounds, artifact chance caps, and persisted values are sanitized.

Evidence: `scripts/verify_expedition_planner.luau` exercises affordability, balance commitment quotes, legacy/corrupt snapshots, route duration, crew scaling, reward changes, risk tradeoffs, and source wiring. `scripts/verify_command_math.luau` covers versioned command migration. Dedicated navigation opens the existing Command page on its Expeditions tab; both new routes are progression-gated. `scripts/verify_replacement_routes.luau` verifies route, quick-find, ready-row, and obsolete-label wiring. The full `scripts/verify_project.luau` suite, Luau compile sweep, and Rojo build pass. This is not a full Expedition Route System: branching destination choices, squad/player collaboration, route-specific encounter resolution, rollback tooling, and rendered mobile/controller/VR verification remain open. No live profile was charged or mutated.


## STUDIO-UI-003 — retired planning labels still pointed at legacy destinations

The navigation exposed “Next Rank” and “Shift Plan” even though the project had a Domain skill tree and a more capable expedition planner. Replaced those menu destinations with a dedicated Ascension Path page and a dedicated Expeditions page that starts the existing Command view on its route-planning tab. The anomaly dashboard remains available under its own name; ready-row copy, quick-find terms, and the resource-planning link now use the replacement routes. Both routes were added to the progression ladder (Expeditions at the Command unlock; Ascension Path with Domain).

Verification: focused route checks and the full offline project suite pass; all source files pass the Luau syntax/compile sweep; Rojo produced a fresh place file. Studio Play boot reached `5.1.0 ui is up` and loaded 155 modules without a game-source error, Edit-mode grep confirmed Argon synced both component wrappers, and a Client-mode `require` confirmed both lazy page wrappers resolve to functions. The log’s Guild parse failure also does not reproduce in the current source compile sweep. The Play smoke test did not click through either new page, test a real save, or exercise phone/controller/VR layouts. Published servers and broader feature requirements remain open.


## STUDIO-UI-002 — Guild page failed to load from an older Studio bundle

The 2026-10-07 client log showed a `PagesSocial` parse error (`Expected '}' ... got ')'`), followed by Guild lazy-module load failures. The confirmed live source was an older monolithic copy, while the worktree used the current split Guild panel. The reported expression rendered the optional goal-progress label inline among `React.createElement` children; it is now computed once as `goalProgressText` and passed as a child. This keeps the conditional expression out of the argument list and makes the child tree easier to audit.

Verification: the complete live ModuleScript compiled with Studio `loadstring`, `require` returned its module table in Edit mode, and a fresh Play boot completed without a PagesSocial/Guild/module error. On 2026-10-07 a fresh Play boot after reconnecting Argon to this worktree again completed without either game-source failure; opening Guild → Community showed the members-only chat UI, and the resulting console contained no PagesSocial parse error or Guild lazy-module failure. Roblox CorePackages separately logged a GameJoinCard analytics timeout in an earlier run; that is outside the game-source result. Studio's live source includes the synced Bazaar purchase routes and an old `vfx` keyword search returned no instances. The full `scripts/verify_project.luau` suite, Lune compile sweep and Argon build pass. Other Guild actions, every-object source parity and published-server behavior remain unverified.


## RANK-CATEGORIES-001 — ranks only offered seven player scoreboards

The client, profile value projection, DataService ordered-store writes and server leaderboard reader each supported only the original seven player boards. Added eleven additional boards backed by authoritative saved values: Taps, Items Found, Crates Opened, Anomaly Pulses, Lab Orders, Warden Defeats, Ore Mined, score-only Arcade Score, Bazaar Deals completed, live-event participation, and current-season XP. Each has its own ordered store; the client supports its own value and same-server roster value, while the Guild board stays separate.

Verification: `scripts/verify_rank_categories.luau` checks all eighteen player board IDs, each store name and query mapping, profile persistence projection, public roster fields and representative values. It also checks the Bazaar and Events counters through the client and global/same-server source paths. In fresh Studio Play, read-only `GetLeaderboard(BazaarDeals)` and `GetLeaderboard(Events)` requests passed the firewall; the Events remote returned `Events` with zero entries (`EVENT_RANK_PROBE true table true nil Events 0`). `scripts/verify_server_events.luau` executes the production event-service method and verifies once-per-window counting for positive collections, distinct windows, empty collections, results, and completed Community Forge. Argon readback confirmed the participation logic and store projection reached the selected place. Studio booted to `5.1.0 ui is up` with no game-source error in the retrieved console, and returned to Edit mode. The dashboard now presents twelve categories with board search, checked by the regression. Production Cloud OrderedDataStore behavior, season rollover, leaderboard claims/rewards/history/closest-progress, reset or rollback semantics, Hidden/Secret criteria, and cross-server behavior remain unverified or incomplete.

## RANK-NAV-001 — the flat board picker made the expanded rankings hard to browse

The Ranks dashboard showed all eighteen player boards and Guilds as one large grid. Players had no category-first way to find a board. Added twelve filters backed by real metrics—Economy, Progression, Exploration, Combat, Forge, Arcade, Bazaar, Events, Seasonal, Prestige, Social, and Guild—plus a board search field. Selecting a category resets the visible board to one belonging to that category. The Guild ranking remains its own board, not folded into player scores.

Verification: `scripts/verify_rank_categories.luau` checks all twelve category mappings and the category/search controls. Bazaar Deals and Events have saved-counter-backed boards; `verify_server_events` covers event participation behavior against the production method. Hidden/Secret criteria are still missing. No native input, responsive screenshot, or controller/phone interaction test was performed.


## STUDIO-UI-002 follow-up — latest attached boot log and fresh synced Play run

The newly attached 2026-10-07 log still contained the old `PagesSocial:3573` parse failure and Guild lazy-module cascade. The confirmed place had since been Argon-synced from the current worktree: Studio script search found `goalProgressText` at the expected declaration/use sites in `StarterPlayerScripts.AstralForge.pages.PagesSocial`. A fresh Play run reached `5.1.0 ui is up`, loaded 155 modules, and emitted no PagesSocial parse, Guild module-load, or other game-source error. Studio was returned to Edit mode afterward. This establishes a clean boot of the synced source, not a click-through of Guild interactions or proof about already-published servers; Roblox CorePackages/analytics errors are outside the game-source result.
