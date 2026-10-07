# Bug audit

Status: open. No system is signed off against the revised master specification.

The source/color inventory was captured before the first revised-spec theme edit. Counts below describe source inspection, not runtime verification.

Baseline: 225 project-owned Luau files; 62 exceed 400 lines; 109 carry --!strict. Dependencies are inventoried separately and have not been granted an exemption by this audit.

Authoritative contract: [MASTER_SPEC.md](audit/MASTER_SPEC.md). Full mapped file list: [source-inventory.json](audit/baseline/source-inventory.json). Color references and the 28 named base colors: [color-inventory.json](audit/baseline/color-inventory.json).

## System inventory

### SYS-01: Persistence and session locks

Source owners/integration points: src/Server/AstralForge/Services/DataService.luau; DocumentServiceBridge; ProfileMath; ReceiptLedger.
Required audit: DataStore UpdateAsync retries, locks, save failures, migration, rollback.
Existing candidate evidence: verify_document_lock; verify_session_gate; verify_profile_version; verify_profile_clamp_math. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-02: Remote registry and firewall

Source owners/integration points: src/Shared/AstralForge/Shared/Protocol.luau; src/Server/AstralForge/Services/RemoteFirewall.luau.
Required audit: Typed schemas, identity, quotas, duplicate requests, malformed and unauthorized payloads.
Existing candidate evidence: verify_firewall_data; verify_firewall_sanitize_math; verify_atomic_security. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-03: Replication and runtime lifecycle

Source owners/integration points: ClientRuntime; init.client; framework; ServerServices snapshots.
Required audit: Stale replies, disconnect/rejoin, duplicate subscriptions, state versioning.
Existing candidate evidence: verify_session_client; verify_module_loaders; verify_pagerouter_maingame. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-04: Currency, production and cooldowns

Source owners/integration points: EconomyMath; EconomyRules; ProfileMath; ServerServices.
Required audit: Zero balances, huge numbers, conservation, timers and cross-system modifiers.
Existing candidate evidence: verify_economy_regress; verify_economy_envelope; verify_forge_levels. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-05: Inventory, artifacts and crates

Source owners/integration points: InventoryMath; EconomyMath#CrateRoll; ProfileBagMath; PagesStory; PagesShop.
Required audit: Full/empty inventory, stacks, duplicate receipts, pity, item conservation.
Existing candidate evidence: verify_inventory_math; verify_shop_relics; verify_donation_receipts. Coverage must be inspected before those tests support sign-off.
New finding CRATE-ROLL-001: corrected title-case pity labels for the twelve added crates and extracted weighted selection to CrateRollResolver. Deterministic parity, pity-boundary and invalid-weight checks pass; native Studio Edit-mode fixture confirmed a Legendary pity result.
Status: partial fix verified; full persistence, client reveal, multiplayer and published-server coverage remain pending.

### SYS-06: Astral Forge and visual theme

Source owners/integration points: CoreKit#theme; ArtKit; ForgeTheme; forging/rolling service paths.
Required audit: Palette, state transitions, idempotency, rolls, costs, UI motion and decomposition.
Existing candidate evidence: verify_motion; verify_runtime_feedback; verify_forge_theme. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-07: Casino

Source owners/integration points: CasinoService; CasinoMath; CasinoExpansionMath; CasinoTables; CasinoViewport; PagesCasino.
Required audit: Ten games, fair-seed protocol, edge math, caps, history, authority, rejoin, ten unique models.
Existing candidate evidence: verify_casino_math; verify_casino_expansion. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-08: Bazaar and player commerce

Source owners/integration points: BazaarService; BazaarMath; trade services; PagesBazaar.
Required audit: Persistent listings, orders, offers, price history, escrow, replay, anti-scam.
Existing candidate evidence: verify_bazaar_math; verify_trade; verify_trade_settle; verify_settle_orchestrate. Coverage must be inspected before those tests support sign-off.
New partial evidence: `BazaarListingMath` and `verify_bazaar_listing_math` define/test a pure record and reservation state model. It is not wired to a DataStore, profile escrow, or marketplace action, so this does not close the persistence or anti-scam audit.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-09: Replacement progression and planning

Source owners/integration points: AscensionPathMath; PlanningModel; PlanningViews; UiOverlays#DomainSkillTree; Continuum/Anomaly/Command paths.
Required audit: Ascension tree and expedition routes, old-data mappings, rollback, removal of old refs.
Existing evidence: `scripts/verify_ascension_path.luau` covers legacy path-field preservation, schema migration, known-branch refunds, Stardust costs, repeat pricing, insufficient funds and unknown-node safety. The action is wired through Protocol, RemoteFirewall, ServerServices, client grants and a two-step tree UI control.
Status: partial implementation only. The respec action has not been run against a Studio fixture through the live remote; old Continuum/Anomaly user-facing pages and refs remain. Expedition route planning now has a versioned Standard/Charted/Salvage plan, atomic Signal commitment, saved claim terms and a three-choice UI, with offline migration/math/wiring checks; it is not yet a branching squad/route system. Live-save behavior, rollback, old feature-reference removal and responsive visuals remain open.

### SYS-10: Guild membership, treasury and roles

Source owners/integration points: CoreServices#GuildService; OpsMath#GuildMath; SocialProgression; PagesSocial#GuildView.
Required audit: Membership races, deleted documents, roles, contributions, disband, leader succession.
Existing candidate evidence: verify_busy_guild_txn; verify_guild_math; verify_guild_goal_math; verify_guild_document_lifecycle. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-11: Guild announcements, chat, logos and governance

Source owners/integration points: GuildCommunity; CoreServices#GuildService; ServerServices; RemoteFirewall; Protocol; PagesSocial#GuildView; pages/GuildCommunityPanel.
Required audit: Filtering, permissions, persistence, expiry, edits, moderation, rename reservation and tax rules.
Existing evidence: GuildCommunity now supplies persistent filtered chat/history, announcement lifecycle, leader-controlled community settings, logo submission/review, moderation, MessagingService publication, and leader rename. Protocol, firewall, SessionGate grants, ServerServices and GuildView are wired together. `scripts/verify_guild_community_wire.luau` checks this chain and the full offline suite/build pass.
Status: partial implementation; live TextService/DataStore/MessagingService, multi-server moderation, visual interaction, name reservation/cost/cooldown/history, role permission matrix, tax, and diplomacy remain unverified or missing.

### SYS-12: Ranks and leaderboards

Source owners/integration points: RankDashboard; SocialProgression; LeaderboardCodec; ServerServices; profile stats.
Required audit: Twelve rank categories, rewards, migration, retroactivity, paging, tie rules, claim replay.
Existing candidate evidence: verify_social_progression; rank migration and reward cases pending. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-13: Admin and game Command tools

Source owners/integration points: AdminService; AdminCommandSchema; PagesSystem#AdminView/#CommandView.
Required audit: Privilege boundaries and interactions with audited systems.
Existing candidate evidence: verify_admin_continuum_residuals; verify_atomic_security. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-14: Server events, seasons and progression rewards

Source owners/integration points: CoreServices#ServerEventService; CommandMath; ConvergenceService; event UI.
Required audit: Event start/end, schedule, reward grants, rollback, modifiers, effects at low FPS.
Existing candidate evidence: verify_server_events; verify_convergence_ops_math; verify_command_math. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-15: UI, responsive layout and accessibility

Source owners/integration points: UiCore; LayoutKit; layoutGuard; MotionKit; purchase modules; mobile settings.
Required audit: Desktop/mobile/controller, safe areas, nested scroll, focus, reduced motion, error boundaries.
Existing candidate evidence: verify_layout; verify_mobile_shell; verify_scroll_isolation; verify_motion; verify_premium_presentation. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-16: Audio, assets and animation lifecycles

Source owners/integration points: AudioKit; ArtKit; asset/viewport controllers; TitleEffects.
Required audit: Loading failures, unavailable assets, cleanup, repeated cues, leaked connections.
Existing candidate evidence: verify_audio_voices; verify_audio_voicing; verify_assets; verify_motion_continuous. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-17: Chat, social and user-generated text

Source owners/integration points: ClientRuntime chat adapter; PagesSocial; GuildService; TextChatService.
Required audit: Filtering, chat permissions, delivery membership, raw text isolation, mute/ban.
Existing candidate evidence: verify_chat_v2; verify_render_sources; guild chat tests pending. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-18: Purchases and entitlement fulfillment

Source owners/integration points: CommerceCatalog; PurchaseSession; PurchaseSignals; ServerServices receipts.
Required audit: Server-saved grant, entitlement confirmation, receipt replay, timeout/rejoin.
Existing candidate evidence: verify_purchase_session; verify_donation_receipts; verify_presentation_systems. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

### SYS-19: Tutorial, navigation and world/platform state

Source owners/integration points: BootKit; TutorialNavigator; PageRouter; VRInterface; settings schema.
Required audit: First join, feature gates, focus, transitions, platform change, legacy settings.
Existing candidate evidence: verify_tutorial; verify_settings_schema; verify_mobile_shell. Coverage must be inspected before those tests support sign-off.
Status: pending full reproduction, adversarial tests, cross-system tests and applicable visual evidence.

## Findings

- BUG-001: Old primary-project icons performed modulo on an absent atlas entry. Exact baseline reproduction recorded; guard applied previously to both worktree and primary sources. Existing public servers have not been verified.
- BUG-002: Guild UpdateAsync fallback can revive a deleted guild from cache. A retried callback can also retain an earlier approval when its final callback sees a missing document. Both faulty variants were reproduced from the retained source. Code is corrected and the headless lifecycle regression passed; live persistence closure remains open.
- BUG-003: Raw guild identity was previously saved without TextService filtering. The create/rename route now runs the actual `SecurityServices.Filter:Apply` broadcast filter before service persistence and fails closed when the filter is missing, throws, returns no text, or rejects the result. `scripts/verify_guild_identity_filter.luau` executes both production source slices and verifies maximum input length, user identity, filtered-output use, censorship passthrough, caller-payload immutability, and fail-closed route behavior. Offline regression closure is evidenced; live Roblox TextService censoring, filtered-name rendering, and published-server parity remain open.
- BUG-004: Stale copies in the main checkout can reintroduce bugs during builds/sync. Three renderer fixes were applied there earlier; full source reconciliation and rollback procedure remain pending.
- BUG-006: The older Studio Guild page bundle failed parsing at its optional goal-progress child, cascading into lazy Guild module errors. Reproduction is in `REPRO_LOG.md` / STUDIO-UI-002. Extracting the conditional child fixed live module compile/require and the fresh Play boot. Full sync is applied; Guild interaction verification remains open.
- BUG-007: `GetLeaderboard` firewall only accepted the original seven board IDs, while the client/server configured seventeen after the Bazaar Deals board was added. Requests for additional boards were rejected as invalid before querying their stores. The full current board set is now allowlisted and `verify_rank_categories` checks firewall parity for every configured player board. Studio interaction and live OrderedDataStore reads remain unverified.

## Closure policy

Every closed item must link to REPRO_LOG.md, the exact correction, meaningful regression cases, test output and any runtime/visual gaps. A green syntax check is not a feature or security sign-off.

## Arcade server implementation stage

The user-approved arcade amendment is recorded in audit/MASTER_SPEC.md. New strict modules implement ten score-only kernels, seed commitments, sealed schemas, private/public projections, replay/version fences and a server gateway. The legacy CasinoService.Play wagering entry point is disabled. UI, ten bespoke models, legacy in-flight stake refund/archive migration, real type analysis and runtime sign-off remain pending. The arcade is not marked shipped.

The public-game scan also found an active Bazaar lottery that sold flux tickets and paid a random flux pot. It is removed from Bazaar UI, service routing, remote validation, and lottery math. Existing saved legacy lottery fields are retained unchanged and are no longer exposed or claimable. `scripts/verify_bazaar_math.luau` now guards the public route and saved-data preservation. No live server session was used to reproduce this path.

- BUG-005: Initial runtime screenshot shows truncated top-bar branding at a 991.2 × 635.2 client viewport. Source screenshot preserved; layout correction requires a concrete reviewed layout under the visual-preservation contract. Open.
- ENV-001: Roblox CorePackages ProfileSharePolicyEnum timed out during startup and cascaded through the platform chat/QR modules. Full console evidence is retained. This is separated from game-owned errors; repeatability and mitigation are unverified.
- STUDIO-UI-001: The confirmed place's older `PagesSocial` source diverges from the current split worktree implementation and had four extra closing parentheses across Guild chat, announcements, moderation, and logo sections. The corrected full source compiles and its module requires in Studio Edit mode. A clean Play boot followed the initial two fixes, but no Play run followed the final two-expression correction. Specific Guild interactions and published servers remain unverified. Evidence: `REPRO_LOG.md`.
