# 🔮 ASTRAL FORGE & GAME-WIDE OVERHAUL — MASTER SPECIFICATION

**A complete, binding rebuild specification** covering Astral Forge, a full game-wide bug audit, the Casino and Bazaar rebuilds, replacement progression/planning features, the Guild system, and the Ranks rewrite.

> **Guiding principle:** Visual continuity is a hard constraint. Architecture, internals, systems, and layout are not. Every claim of completion must be backed by a written audit trail — no exceptions, no happy-path-only sign-offs.

---

## 📘 PART 1 — Astral Forge Overhaul

**Objective:** Rebuild Astral Forge's internals, systems, layout, and architecture without altering its established color identity.

### 1.1 — Luau Rewrite Requirements
- Every script rewritten with `--!strict`
- Explicit return types on every public function
- `type` aliases for every data shape
- No implicit `any`, no `any` leakage, no `unknown` casts
- No `wait()` — `task.wait` only
- No deprecated globals
- No `:WaitForChild` without timeout on critical paths
- No god-modules over \~400 lines
- Header comment on every module: purpose, owner, dependencies, last-reviewed

### 1.2 — Module Decomposition
- `ForgeService`, `ForgeRollResolver`, `ForgeCostCalculator`, `ForgeUIController`
- `ForgeInventoryBridge`, `ForgePersistence`, `ForgeAnalytics`, `ForgeAntiCheat`
- `ForgeTheme` — every color by name, no scattered hex
- `ForgeConfig` — every magic number documented

### 1.3 — Remote & State Architecture
- Typed `RemoteRegistry`, schema-validated payloads
- Per-player rate limiting on every remote
- Idempotency keys on all forge server calls
- State machine: **Idle → Charging → Rolling → Resolving → Animating → Idle**
- Overlapping inputs queued or rejected — never silently merged
- All transitions logged; server authoritative on rolls, costs, rewards

### 1.4 — Visual Preservation Contract
- Audit every existing color before touching code
- Zero hex literals outside `ForgeTheme` after refactor
- No layout changes without explicit approval
- Animation feel preserved; rarity gradients recognizable at a glance
- Before/after screenshots required for sign-off

---

## 🐛 PART 2 — Game-Wide Bug Audit

**The rule:** No feature is "done" because one happy-path test passed. **Completion requires a written audit.**

### 2.1 — Mandatory Process
1. Inventory every system in `BUG_AUDIT.md`
2. Reproduce before fixing — steps, expected, actual, stack trace
3. Cross-system testing — data stores, remotes, currency, save/load, mobile/console, low-FPS, high-ping
4. Boundary testing — max stacks, zero currency, overflow, empty/full inventories, dupes
5. Regression suite — TestEZ or custom harness
6. Explicit gaps — list what was NOT tested and why

### 2.2 — Systems Requiring Audit
Data stores · Remotes · Replication · Currency · Inventory · Cooldowns · Guild systems · Ranks · Casino · Bazaar · Astral Forge

### 2.3 — Banned Anti-Patterns
- ❌ "Tested it once, works."
- ❌ "Works on my machine."
- ❌ "It's probably fine."
- ❌ Marking fixed without a repro log
- ❌ Closing a bug without understanding why

### 2.4 — Deliverables
`BUG_AUDIT.md` · `REPRO_LOG.md` · `TEST_PLAN.md` · `REGRESSION_SUITE` · `NOT_TESTED.md` · `SIGNOFF.md`

---

## 🎰 PART 3 — Casino Complete Rebuild

**The rule:** Every casino game uses its own distinct, high-quality viewport model. **No shared generic prop. No placeholder boxes.**

### 3.1 — Games & Bespoke Models
- **Slots** — machine, reel drums, lever anim, payline lighting
- **Blackjack** — felt table, card shoe, chip stacks, dealer rig
- **Roulette** — wheel physics, ball model, 3D betting grid
- **Poker** — table, card meshes, chip denominations
- **Crash** — animated graph viewport, multiplier curve model
- **Dice** — tumbling physics rig, outcome sync
- **Coin Flip** — dedicated coin model, flip arc, edge case
- **Keno** — purpose-built board
- **Mines** — grid board, detonation VFX
- **Plinko** — peg field, drop chute, bucket landing

### 3.2 — Core Systems
Betting · Payout · Provably-fair seeds (client + server + nonce) · Session state · Anti-cheat · Disconnect handling · Mid-round rejoin

### 3.3 — UI & Presentation
Wallet · History · Stats · Limits · VIP/tier hooks · Responsible-gaming caps · Per-game lighting, camera, VFX, sound

### 3.4 — Verification & Compliance
RNG path documented · House edge published · Payout math checked · Bet limits server-side · Loss caps enforced · Provably-fair exposed to players · All outcomes logged

---

## 🏪 PART 4 — Bazaar Rebuild + Replacement Features

### 4.1 — Bazaar Rebuild Scope
New layout · Player storefronts · Listings · Buy orders · Offers · Trade escrow · Server-side price validation · Persistent listings · Anti-scam

### 4.2 — Bazaar UI & Visual Language
Responsive grid · Rarity tinting · Fuzzy search · Price history graph · Storefront pages · Escrow window · Notifications · Distinct from Casino

### 4.3 — Replacement Feature A (Progression)
**Skill Tree / Ascension Path** — branching, respec cost, passives, capstones, visual tree, distinct UI, versioned schema

### 4.4 — Replacement Feature B (Planning)
**Squad Loadout Planner / Expedition Route System** — pre-mission planning, route choices, resource commitment, real consequences, distinct UI/data/impact

### 4.5 — Removal & Migration
Remove all old refs · Migration path · Map old ranks to Skill Tree · Map old plans to Loadouts · Changelog · Archive · Rollback plan

---

## 🛡️ PART 5 — Guild System

### 5.1 — Persistent Announcements
Leadership-authored · persisted · editable · timestamped · attributed · pin/archive/expiry · notifications · rate-limited

### 5.2 — Members-Only Guild Chat
Server-side membership checks per message · `TextService:FilterStringAsync` per speaker · `GetNonChatStringForBroadcastAsync` for display · rate limits · mute/ban · paginated history · **no client-trusted content**

### 5.3 — Guild Logos
Upload/select · moderation queue · size limits · caching · fallback · theming · change log

### 5.4 — Configurable Logic & Settings
Join mode · member cap · rank permission matrix · tax rules · announcement perms · chat perms · treasury · diplomacy

### 5.5 — Guild Renaming
Cost · cooldown · name validation · reservation system · audit log · member notification · historical tracking

---

## 🏆 PART 6 — Ranks, Standards & Definition of Done

### 6.1 — Ranks: Expanded Categories
Combat · Economy · Exploration · Social · Guild · Crafting/Forge · Casino · Bazaar · Events · Seasonal · Prestige · Hidden/Secret

### 6.2 — Ranks: UI Rebuild
Tabs/radials · progress viz · reward preview · claim flow · history · filter/sort · closest-to-completion · search · no copy-pasted frames

### 6.3 — Ranks: Data & Migration
Versioned schema · migration · rollback · retroactive rewards · analytics · server-authoritative · all rank-ups logged

### 6.4 — Engineering Standards
Expanded Luau · consistent naming · server authority · validated remotes · logged mutations · test plan per system · colors by name · magic numbers in config · module headers

### 6.5 — Definition of Done
1. ✅ Astral Forge rewritten, palette preserved
2. ✅ Bug audit complete, regressions codified
3. ✅ Casino: unique models per game
4. ✅ Bazaar rebuilt with anti-scam
5. ✅ Old rank/plan systems removed; 2 new features shipped
6. ✅ Guild systems live with server-side controls
7. ✅ Ranks rewritten with more categories
8. ✅ **No "done" claims from narrow tests**

### 6.6 — Final Notes
This specification is **binding**. Partial completion is not completion. Narrow tests are not verification. Every section must be independently audited, signed off, and cross-referenced against the Definition of Done before the project is finished.

If a section cannot be completed as specified, it is documented as incomplete — never silently downgraded, never marked done on a technicality, never merged with a caveat hidden in a commit message.

The audit trail is the deliverable. The code is the artifact. The spec is the contract.

## User amendment — 2026-10-05

The user selected **Public arcade without betting**. This supersedes Part 3's wagers, payouts and house-edge requirements. The ten distinct games and bespoke models remain required. Gameplay is score-only: no currency, token, item or Robux wagers; no cashouts; no random currency/item payouts; no score exchange. Verification, persistence, history, statistics, authority and play-break controls still apply.
