# Reproduction log

## BUG-005: Top-bar branding truncates at compact desktop widths

Reproduction: the preserved Studio screenshot at `audit/evidence/AF_BASELINE_DESKTOP_20261005.png` shows the top-bar wordmark clipped to `ASTRA` at a 991.2 × 635.2 client viewport. `LogoLockup` used a fixed 18 px label with truncation while accessibility text scaling could enlarge it beyond its responsive slot. The wordmark now uses the shared text-fit constraint with a 12 px floor, retaining the existing icon, colors, and layout.

Verification: `scripts/verify_ui_consistency.luau` extracts and executes the production `LogoLockup` renderer, checks that compact mode supplies the full `ASTRAL` string with bounded fitting, and checks micro mode intentionally uses icon-only branding. This is source-renderer evidence; a matching Studio screenshot at the original viewport and enlarged text-scale setting remains required before closing the visual issue.

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


## CRATE-TEXTURE-001 — standalone override delivery and baked-map fallback

Reproduction: in the 2026-10-06 main-place Studio gallery, Classic, Frost and Molten body maps reported `Failure` after retry. The source manifest also replaced those embedded Blender maps with separately uploaded IDs, so the fallback path was coupled to the same unverified delivery channel. Removed the three overrides and kept the uploaded GLB material maps as the source of truth.

Verification: 2026-10-07 Studio Play exposed all 40 crate MeshParts to the client. A `ContentProvider:PreloadAsync` pass returned 40 callbacks, all `Enum.AssetFetchStatus.Success`; the server boot had no crate-loader error. `scripts/verify_crate_asset_manifest.luau` checks the uploaded kit ID, 20 unique skins, and absence of unverified texture overrides. This is fetch evidence for one Studio account/session; visual quality, fresh-user access, published-client delivery and device review remain open.


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

Verification: `scripts/verify_rank_categories.luau` checks all nineteen player board IDs, each store name and query mapping, profile projection, public roster values and own/server/global wiring. Studio Play accepted read-only `GetLeaderboard(BazaarDeals)`, `GetLeaderboard(Events)`, and `GetLeaderboard(HiddenSecrets)` calls; each route returned `ok=true`, and the empty Events and HiddenSecrets boards returned zero rows. `scripts/verify_server_events.luau` executes the production event method and verifies once-per-window counting. `scripts/verify_hidden_ranks.luau` executes production milestone visibility, confirms the existing EventHorizon, ForgeApex, and StoryArchivist claims count retroactively, and checks Quick Find uses server reveal state. Argon readback confirmed the source sync; Studio boot reached `5.1.0 ui is up` without game-source errors and returned to Edit mode. The dashboard presents the twelve master-spec categories: Combat, Economy, Exploration, Social, Guild, Forge, Casino (score-only Arcade), Bazaar, Events, Seasonal, Prestige, and Hidden/Secret. Live secret reveal/claim interaction, nonempty cloud data, production Cloud OrderedDataStore behavior, season rollover, leaderboard claims/rewards/history/closest-progress, reset or rollback semantics, and cross-server behavior remain unverified or incomplete.

## RANK-NAV-001 — the flat board picker made the expanded rankings hard to browse

The Ranks dashboard showed all nineteen player boards and Guilds as one large grid. Players had no category-first way to find a board. The dashboard now filters by the twelve master-spec categories—Combat, Economy, Exploration, Social, Guild, Forge, Casino (score-only Arcade), Bazaar, Events, Seasonal, Prestige, and Hidden/Secret—plus board search. Selecting a category resets the visible board to one belonging to that category. The Guild ranking remains its own board, separate from player scores.

Verification: `scripts/verify_rank_categories.luau` checks all twelve category mappings and the category/search controls. Bazaar Deals, Events, and HiddenSecrets have saved-value-backed boards; `verify_server_events` and `verify_hidden_ranks` exercise the production methods for those categories. Studio accepted a read-only HiddenSecrets request and returned an empty board; the actual reveal/claim UI and nonempty cloud-backed score have not been tested. No native input, responsive screenshot, or controller/phone interaction test was performed.


## STUDIO-UI-002 follow-up — latest attached boot log and fresh synced Play run

The newly attached 2026-10-07 log still contained the old `PagesSocial:3573` parse failure and Guild lazy-module cascade. The confirmed place had since been Argon-synced from the current worktree: Studio script search found `goalProgressText` at the expected declaration/use sites in `StarterPlayerScripts.AstralForge.pages.PagesSocial`. A fresh Play run reached `5.1.0 ui is up`, loaded 155 modules, and emitted no PagesSocial parse, Guild module-load, or other game-source error. Studio was returned to Edit mode afterward. This establishes a clean boot of the synced source, not a click-through of Guild interactions or proof about already-published servers; Roblox CorePackages/analytics errors are outside the game-source result.


## ARCADE-NEW-GAMES-001 — requested casino games were not connected to the public arcade

Reproduction: the active Casino view exports `ArcadePage`, whose game catalogue originally contained ten score-only games. Four additional games were represented in a dormant `CasinoTables` page backed by `CasinoExpansionMath`; those modules used practice-chip wagers and were not reachable through the active score-only route. `CasinoService.State` also normalized and returned the legacy practice-chip state. Expected: all requested public arcade games use the same fair, persisted score-only protocol, with no wager, cashout, or chance-based currency payout path. Actual: the added games were unreachable through the active route, and their dormant implementation contradicted the user's public-arcade amendment.

Correction: added Table Roulette, Quantum Roulette, Dice Table and The Infinite Card Tower to the shared arcade catalogue and implemented their controls on the active `ArcadePage`. The server engine now creates verified zero-stake rounds for each; Tower column state, score and next card are persisted, while the future deck remains private until a finished round reveals its proof. Quantum board layouts cover 0–36, remain stable for three completed rounds, then change phase and Gravity Sink position. Removed the dormant practice-chip UI/math modules and removed the saved legacy chip object from the public Casino snapshot without deleting or migrating saved player fields. The legacy `CasinoService.Play` route continues to reject wager requests.

Evidence: `scripts/verify_arcade_engine.luau` now runs all fourteen score-only definitions and exercises Tower validation, replay protection, cloned public state, JSON persistence, expiry score retention, and six quantum rounds across two board shifts. `scripts/verify_casino_expansion.luau` covers zone coverage/uniqueness, phase and shift cadence, active-route wiring, and absence of the retired wager modules. `lune run scripts/verify_project.luau`, `lune run scripts/compile_all.luau` (348 files), and `npm run format:check` pass. Argon synchronized the source to the confirmed Studio place; Edit-mode readback found all four definitions and both new shared modules.

Boundary: Studio Play input/result flow, real save/rejoin behavior, fourteen distinct viewport models, phone/controller/VR rendering, live multiplayer, and published-server behavior remain unverified. This is an implementation checkpoint, not casino sign-off.

## Bazaar marketplace — player listing surfaces

The escrow-backed service existed without a player-facing route for browsing offers or managing seller listings. Added a dedicated Player Listings tab with rarity-tinted browse cards, search and exact-string price sorting, client pagination over the active catalog, an inventory-backed listing form that excludes locked/equipped items, a no-fee seller payout disclosure, and server-paged My Listings with cancellation and payout claim actions. A centered confirmation now shows the exact item, seller, price and current balance before the server-authoritative purchase request.

Evidence: `verify_bazaar_listing_service` now checks the player page route, seller cursor size, purchase confirmation, exact-price disclosure, fee text and buy/sell/cancel/payout action wiring. The listing-specific verifier, `verify_server_events`, Luau compile sweep, formatter and Argon project build passed after the changes. These checks do not render the page or exercise a live DataStore/multi-player transfer.

Open: buy orders, offers, price history, stale-index cleanup; live item/currency transfer, payout retry and save recovery; responsive phone/controller/VR review and published-server parity. The full goal remains unsigned.

Buyer receipts are now stored in the buyer's profile in the same mutation that inserts the purchased item and marks it complete. A bounded read-only six-row cursor route returns the latest 100 sanitized receipts, and the Bazaar includes a Bought tab. `verify_bazaar_listing_math` checks invalid-record rejection and deterministic retention; `verify_bazaar_listing_service` checks route, rate limit, persistence, and UI wiring. Studio purchase recovery and rendered receipt review remain open.

The ordered Bazaar index could let missing or terminal records permanently occupy the first page and hide newer active offers. `Marketplace.Latest` now scans at most two pages, removes malformed, missing, expired, sold, and cancelled IDs, preserves escrowed/reserved entries, and stops without deletion if an authoritative listing read fails. Pure state cases and static route-budget checks pass; live OrderedDataStore paging, quotas, and races remain untested.

## BUG-008: Claimed Bazaar sales consumed active-listing capacity

Reproduction: `Marketplace.Create` counts the seller's `Bazaar.EscrowListings`, while `Marketplace.ClaimPayout` credited proceeds but left the completed listing in that map. After enough successful sales, the “50 active-listing limit” could reject new listings even when the seller had no active offers. Expected: a claimed sale frees active escrow capacity and remains visible in bounded seller history. Actual: the paid record continued to count as escrow.

Correction: payout settlement now archives the validated listing snapshot in `ListingHistory`, records the claim marker, and removes that ID from active `EscrowListings` in the same profile mutation. `BazaarMath.Ensure` keeps the newest 100 valid claimed-sale records deterministically; the seller-history endpoint pages across those and up to 50 active escrow records.

Evidence: `verify_bazaar_listing_math` executes profile sanitization fixtures for active-vs-archived separation and the 100-record bound; `verify_bazaar_listing_service` checks the payout write ordering, archive, slot release, and 0–150 cursor validation. Live DataStore/cross-server retries and player UI rendering remain unverified.

## ARCADE-VIEWPORT-001 — active arcade had no distinct per-game 3D preview

Source reproduction: the active `ArcadePage` had no viewport scene, and the older `CasinoViewport` used one roulette-wheel fallback for most kinds beyond Jar, Cards, and Dice. Expected: each of the fourteen public score-only games displays its own recognizable scene, with an isolated camera/world lifetime and reduced-motion behavior. Actual: the active page displayed no game model, and the older fallback could misrepresent unrelated games as roulette.

Correction: added `ArcadeViewport` with dedicated cabinet/table/board/conveyor/graph scenes for all fourteen `ArcadeConfig` IDs, then added a selected-game preview section to `ArcadePage`. Scene instances use isolated `WorldModel` and `Camera` instances, clean up their render connection and world on unmount, and suppress idle movement when soft motion is enabled.

Evidence: `verify_arcade_viewports` verifies every configured game has an explicit builder, the active page selects the scene by game ID, reduced-motion gating exists, and cleanup destroys the world/disconnects the connection. `scripts/compile_all.luau`, the full `scripts/verify_project.luau` suite, `npm run format:check`, and `argon build default.project.json -x` pass. This is source and build evidence only.

Open: reconnect Argon to Studio, render all fourteen scenes, review model composition/framing/materials/lighting, and verify phone/controller/VR layout and performance. No casino viewport quality sign-off is claimed.


## ARCADE-VIEWPORT-002 — viewport builder exceeded the module-size guideline

Reproduction: after ARCADE-VIEWPORT-001, `ArcadeViewport.luau` had 643 lines and combined the React component, scene lifetime, geometry helpers and all fourteen builders. The master engineering requirement calls for modules near or below 400 lines so they can be reviewed and changed independently.

Correction: split the component, shared geometry helpers, seven instant/action builders, seven table/card builders and resolver into five modules (72, 160, 198, 235 and 30 lines). The resolver remains explicit and errors on an unknown game kind; every configured game uses its own builder function.

Evidence: `scripts/verify_arcade_viewports.luau` parses both registries, checks complete unique mappings, selected-scene wiring, lifecycle cleanup, reduced-motion handling, unknown-ID validation order and the 400-line ceiling. In an isolated compiled Studio Edit snapshot, all fourteen builders instantiated successfully (Slots 19, Blackjack 25, Roulette 43, Poker 27, Crash 19, Dice 19, Coin Flip 12, Keno 42, Mines 52, Plinko 53, Table Roulette 39, Quantum Roulette 39, Card Tower 36, Dice Table 21 BaseParts). An unknown ID was rejected without creating any Workspace child. The focused check, prior full project suite, `scripts/compile_all.luau`, `npm run format:check`, `git diff --check`, and `argon build default.project.json -x` passed. Rendered ViewportFrame quality, camera framing, mobile/controller/VR fit, frame cost and main-place Argon readback remain unproven.
