# Master specification status — 2026-10-07

Authority: MASTER_SPEC_REQUEST_20261006.txt and MASTER_SPEC.md, with the user's public-arcade amendment. This is a requirements tracker, not completion sign-off.

## Part 1

Incomplete. Current inventory: 247 first-party Luau files, 129 strict headers, 62 over400 lines, 1327 word-any candidates and 268 unbounded WaitForChild candidates. These are source scans, not type/runtime proofs. ForgeTheme and typed Arcade RemoteRegistry components exist; the required complete Forge decomposition, complete schema coverage/state transitions, public shape/return typing and global color centralization are unproven or missing. Before/after actual-game/device visual verification remains required.

## Part 2

Incomplete. BUG_AUDIT.md, REPRO_LOG.md, TEST_PLAN.md, REGRESSION_SUITE, NOT_TESTED.md and SIGNOFF.md exist. Actual repro/fix evidence covers selected loader, rendering, guild-lifecycle, arcade and profile-load issues. The complete cross-system/failure/device/multiplayer audit has not been performed. Existing source-marker checks do not count as full behavior verification.

## Part 3

Incomplete. Ten score-only game kernels, seed commitment/reveal primitives, idempotent requests, projections, history and legacy stake migration are implemented and headless-tested. Public casino remains an arcade without betting per explicit user selection. Ten bespoke finished viewport rigs and full native UI/device/rejoin verification remain incomplete. Partial Blender builders exist for Slots, Coin Flip and Dice; they are not a ten-model sign-off.

## Part 4

Incomplete. The public Bazaar lottery wager and chance payout have been removed and regression-guarded, with legacy profile records retained but inactive. `BazaarListingMath` sanitizes records and models reservation, expiry, settlement and idempotent seller claims. `BazaarListingService` now connects authenticated create/browse/cancel actions to a versioned listing store, ordered index, profile escrow saved before activation, and idempotent cancellation recovery. `verify_bazaar_listing_math` and `verify_bazaar_listing_service` cover pure transitions and source-level wiring, but real StoreAccess transactions and cross-server recovery remain untested. Buyer purchase/delivery, seller proceeds, storefront UI, offers/buy orders, price history, search, notifications and anti-scam recovery are still missing, so the marketplace is not shipped. The existing Domain tree now has independently versioned legacy preservation and a server-priced respec with point refunds, plus a confirmation control; `verify_ascension_path` passes in the offline suite. Expedition launches now offer three server-priced route plans with Signal commitment, saved reward/risk snapshots and legacy-safe migration; `verify_expedition_planner` covers the math and source wiring. Dedicated Ascension Path and Expeditions routes replace the old Next Rank/Shift Plan navigation labels, with corresponding progression gates and quick-find links; `verify_replacement_routes` covers the connection. Full replacement-data migration, a complete branching squad/route system, rollback, cross-platform route interaction, persistent marketplace behavior and distinct visual sign-off remain unfinished.

## Part 5

Partial. Guild deleted-document resurrection and retry/denial handling have repro/regression coverage. Filtered members-only chat/history, announcements, settings, logo review, moderation and leader rename are routed through server validation, session grants, persistent documents, and a dedicated responsive community panel. `scripts/verify_guild_community_wire.luau` checks route/auth/schema parity; the complete offline suite, StyLua checks, and Rojo build pass. The confirmed main Studio place (PlaceId 135153679037687) now has the bounded cross-server guild delivery module and fail-closed filtered create/rename source. That source sync is verified; runtime messaging and live TextService moderation are not. Rename reservations/cost/cooldown/history, granular role permissions, taxes, diplomacy and native multi-server testing remain unfinished.

## Part 6

Incomplete. The Ranks page exposes eighteen persisted player boards—Flux, Rebirths, Play Time, Stardust, Cores, Domain, Worlds, Taps, Items Discovered, Crates Opened, Anomaly Pulses, Lab Orders, Warden Defeats, Ore Mined, score-only Arcade Score, Bazaar Deals, live-event participation, and current-season XP—plus the separate Guild board. Added boards are wired through authoritative profile values, per-board OrderedDataStores, public server roster summaries, the client board list and own-score display. The dashboard groups the boards into twelve searchable categories, including Bazaar and Events. Event participation increments once per player per positive-collection live event window and is tested against the production service method. Hidden/Secret ranking criteria are still missing; production cloud behavior, rewards/claims/history/closest progress, retroactivity/versioning/rollback/analytics, remaining engineering standards, and runtime visual verification remain unfinished. No part is signed off from narrow tests.

## Additional authorized crate work

21 crate definitions and 20 skin definitions are present, including12 additions each. All new crates have key offers; owned equipped skins award bounded deterministic essence. A Blender workshop with20 body/lid rigs,40 1024px texture maps, GLB validation and art-review fixes was built and uploaded as88755990794383. Native main-Studio asset load verified40 exact part names and no missing textures. Actual gameplay/save/replay/controller/mobile/VR verification remains in progress. This asset import is not full crate or game sign-off.
