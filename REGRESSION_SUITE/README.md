# Regression suite coverage

Run lune run REGRESSION_SUITE/run.luau from the repository root. The entry calls scripts/verify_project.luau, which enumerates the existing named verification modules.

Current audited groups:

- Arcade engine: verify_arcade_engine exercises ten game kernels, privacy projections, save/load, action receipt/version fences, expiry and breaks. Native isolated gateway evidence is in audit/evidence/ARCADE_SERVER_STAGE_20261005.md; the full production request path remains unverified.
- Roll proofs: verify_roll_proofs checks SHA/HMAC against independently generated fixtures and verifies deterministic streams/commitments. The player-facing full outcome verifier remains incomplete.
- Arcade migration: verify_arcade_migration checks one-time refunds for unfinished legacy stakes, duplicate calls, restored profiles and huge/malformed balances. Live rollout and failure recovery remain open.

- Renderer bug checks: verify_render_sources and verify_runtime_feedback execute actual icon/chat functions with incomplete inputs. They do not render an entire live page.
- Purchase status: verify_purchase_session and verify_premium_presentation cover state/receipt ordering and a headless React tree; native checkout and live visuals are not exercised.
- Layout guard: verify_layout_guard_engine covers temporal deferral, budget stopping, rollback and collision iteration. Real frame-time measurements and all platform layouts remain open.
- Palette contract: verify_forge_theme compares the new named palette to the captured baseline, checks immutable source colors and exercises accessibility reset/composition. Actual screenshots are still required.
- Guild document lifecycle: verify_guild_document_lifecycle is the first persistence reproduction/regression group. Its mock retry/success semantics do not substitute for a live multi-server DataStore run.
- Guild community wiring: verify_guild_community_wire checks protocol and firewall action coverage, SessionGate grants, filtered-name routes, persistent community writes, cross-server messaging bounds and the guild UI entry points. It is a source-parity guard; live TextService, MessagingService and visual behavior still require Studio verification.
- Ascension Path respec: verify_ascension_path checks saved-tree migration, preservation of unrelated Domain data, bounded known-node refunds, Stardust price gates, repeated-respec scaling and preservation of unknown legacy markers. It tests the pure rules; it does not trigger the live action or validate the responsive confirmation UI.
- Expedition planning: verify_expedition_planner and verify_command_math check route affordability, committed Signals, bounded route terms, crew/reward/artifact consequences, versioned legacy snapshots and client/server/firewall wiring. They do not charge a live save or prove rendered device layouts or rollback behavior.
- Expanded ranks: verify_rank_categories checks sixteen player-board IDs against profile value projection, separate OrderedDataStores, server leaderboard routing, public roster summaries and own-score UI fields. It does not verify cloud DataStore budgets, season rollover/reset rules, claim rewards, or rendered platform layouts.
- Bazaar listing transitions: `verify_bazaar_listing_math` tests record sanitization and reservation/settlement rules; `verify_bazaar_listing_service` checks route/firewall/session wiring and saved-escrow-before-activation ordering. Both are incomplete evidence: real StoreAccess transactions, multiplayer purchases, delivery/recovery and UI/device behavior remain open.

Legacy candidate groups for economy, guild goals, escrow, casino math, layouts, sessions and migration are indexed in BUG_AUDIT.md. Their coverage is not expanded by merely including them in this entry point. New-feature groups will be added with explicit behavior, failure cases and gaps as those implementations land.
