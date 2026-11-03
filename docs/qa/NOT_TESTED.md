# Astral Forge v2 — Explicitly Not Tested

> Transparency list. If it is not listed here and not signed off in `SIGNOFF.md`, it is not considered verified.
> Last updated: 2026-10-09

## Current 7.0 verification boundary

### 2026-10-11 pass

Verified live in Studio (one client, desktop 1530x635 viewport):

- [x] 7.1.0 boots clean (no errors; release notes reopen for returning players).
- [x] UI prize wheel: gradient direction confirmed. At rotations 0, 37.5 and
  200 degrees every wedge colour sits under its own label and divider, and the
  server winner lands under the pointer. Fixed a centre seam between halves.
- [x] Domain constellation renders the real 20-node tree: bound paths, pulses,
  companions on bound nodes, cyan selected path, readable at the opening zoom.
- [x] Crew, chat, settings and trade state through the real remote: crew
  lifecycle error paths, whisper guards, global send + cooldown, new Social
  settings saved, trade history reaches state. Chat tabs, Crew page, Trade page
  (Recent trades), player list overlay and Mail captured.
- [x] Fixed from the live pass: event embers drawn as drifting diamonds (now
  few, soft and round); top-bar values in a monospace font read "6 . 4 2"
  (now Builder Sans); player-list output showed 0/s for big-number production.

Still not verified:

- [ ] Two-player chat (whispers, crew channel) and trade (invite, history,
  one-sided warning): needs Studio's multi-client test, which the MCP cannot start.
- [ ] Phone, tablet and short-landscape layouts with the 11 px text floor:
  device emulation is not reachable through the MCP. The chat tab row was
  clipped at the top in the short desktop viewport; check it on phones.
- [ ] Global chat and guild relay across real servers (published place).
- [ ] Every remaining page (Settings, Shop, Black Market, Inventory, Workshop,
  Research, Milestones, Overview events) captured at phone sizes.

- [ ] Accept the pending Argon Edit-mode synchronization and verify the
  persistent sources, including DomainHexStage, SkyViewport, the authored
  Bolt atlas, MobileResourceRail and the ranks cleanup. The last Edit-mode
  source check still contained the older code despite PR #67 being merged.
- [ ] Run the current ranks focus/cleanup follow-up in Studio after sync;
  executable offline focus and adapter fixtures are not a physical
  controller or live-rendering sign-off.

The new hex domain, authored Bolt atlas, tutorial pointer masks, aurora and
minigame scene lifecycle have bounded offline/live checks recorded in
`SIGNOFF.md`. Both minigames rendered in phone portrait simulation. Four
Cipher glyph models changed pose after local key presses without submitting
a puzzle action. Settings' shared controls were captured on phone; this is
not a complete settings interaction/save-persistence test.

- [ ] Finish the additional trading, changelog, mail, crew, overview, research
  and milestone redesigns requested in the expanded pass.
- [ ] Finish artifact/crate art and animation refinements and wider shared
  control/text-shadow coverage.
- [ ] Tutorial touch/gamepad walkthrough across every step, missing targets,
  back/skip, safe areas and real controller navigation. Pointer blocking and
  callback/focus regressions do not establish physical gamepad behavior.
- [ ] Topbar access to every resource and control across phone landscape,
  narrow desktop, changing resources and active visitors/events.
- [ ] Human approval of the logo, sprite art, aurora, shadows and every screen.
- [ ] Frame-time measurements on actual mobile hardware and real-player
  multiplayer, audio and profile persistence testing.
- [ ] Remove or consolidate more unused presentation only after checking
  live callers and replacing obsolete regression assumptions.

### Earlier observations

The new ranks avatars rendered successfully in desktop and narrow-panel
captures. This supersedes the blank-render observation for ranks only; it
does not establish a fix or sign-off for every other 3D feature. Arbitrary
avatar bundles/accessories, actual phone hardware, network-latency behavior
and human audio confirmation still need broader coverage. Ranks loader
failures/timeouts/disposal and refresh/search behavior have offline regressions.
Player-card and shared-grid geometry were checked live without submitting
friendship, trade, block, report or purchase actions.
The latest UI playtest also logged soundtrack load timeouts across the playlist;
audible music remains unverified. A diagnostic dispatch guard rejected an
attempted report action; no report reached the production server.

- [ ] Full live gameplay walkthrough after the current fixes. Studio MCP connects, but the latest Edit synchronization still requires confirmation; the separate executor bridge remains disconnected.
- [ ] Measured UI frame times, rapid navigation, title rendering, audio playback and responsive trade controls on actual clients.
- [ ] Two-player trade: edit while syncing, switch sessions, reject stale replies, ready/unready, confirm and reconnect.
- [ ] Public artifact network replication across real-player respawns, unequips, upgrades and player departures.
- [ ] Human visual review of every screen for consistency with the game's palette, typography and restrained motion.

Desktop startup, inventory, quick search and domain overlay were smoke-tested,
including domain layout in iPhone 17 Pro portrait simulation (Sensor orientation,
CoreUISafeInsets). No runtime exception was observed in those paths.
The final domain smoke test confirmed the selected label stays above the other
nodes. Studio was returned to edit mode and device simulation was stopped.
Five-second desktop samples had p95 frame intervals of 11.23 ms and 11.91 ms,
with maximum intervals of 41.93 ms and 38.98 ms. These are samples, not a
before/after benchmark or a guarantee of smoothness on other hardware.

- [ ] Resolve or independently reproduce blank ViewportFrames in the current
  Studio rendering environment: both the domain meshes and a temporary
  standalone plain-cube viewport rendered blank. The diagnostic was removed.
- [ ] Confirm audible playback, not merely successful audio loading.

The follow-up live sweep opened Workshop, Research, the Daily and Artifact Shop,
Inventory, Settings and Feedback. Inventory search produced its empty state;
feedback category, impact and minimum-length states were exercised without
submitting a message. Research's heading now has a measured 20-pixel gutter
before its batch controls. Shop wallet labels fit their chips with compact
amounts. Feedback impact controls measured 48 by 48 pixels in phone simulation.
Shared button motion uses measured scale coordinates because Roblox truncates
fractional UDim pixel offsets; regression tests verify fractional travel, resize
updates and subscription cleanup.

The rendering isolation was extended: neither a ViewportFrame with direct parts,
a ViewportFrame with a WorldModel, nor a neon cube directly in Workspace appeared
in the current capture environment. This is not specific to the domain tree.
The temporary objects were removed and UI visibility restored. The renderer's
cause still needs independent Studio/client confirmation; no 3D feature was
replaced or disabled.

An isolated Studio presentation harness subsequently exercised two simulated
players through equip, upgrade, unequip, respawn, departure during refresh,
late join and disposal. It reproduced a stale-completion leak after departure;
the fixed module passed all eight lifecycle checks. Offline regressions also
execute the actual completion guard against newer builds, departures, changed
characters, unequips, disposal and removed watchers. This is not a two-client
replication test. Temporary characters and test modules were removed.

Live shared Panel samples retained 0.16, 1.4 and 7.75 pixels of travel at two
host sizes, including matching shadow travel. Domain-tree entrance produced 17
fractional-motion frames and settled at center; its confirmation dialog now
uses measured coordinates too. These checks address coordinate stepping, not
hardware-specific frame pacing.

Report-sheet, level-roadmap and offline-reward entrances were subsequently
sampled live: 7, 7 and 12 fractional frames respectively, each settling at
center. No report, block or reward-collection action was submitted. The test
module and GUI were removed. The console reported load timeouts for
"Celestial String Awakening 2" and "Space Station '98"; the music director
logged and skipped them. An independent follow-up preload returned Success for
both assets in about 0.16 seconds, with durations of about 213 and 225 seconds.
Availability was confirmed in that later run; intermittent loading and human
audibility are still not signed off. The actual director's failure, retry,
stale-callback, crossfade, pause/resume and disposal control flow now has
executable tests.

Player-list and notification entrances were sampled in isolated local UI tests:
11 and 13 fractional frames respectively, settling at their intended positions.
The player-list probe used local responses rather than requesting network
rosters or taking social actions. This is motion verification, not a real
multiplayer/social-flow signoff.

Edit-mode rendering isolation also remained blank with an opaque neon cube
after temporarily hiding an unrelated plugin welcome overlay. The overlay's
original state was restored and the cube removed. This excludes that overlay
as the explanation, but does not establish the renderer's root cause.

The existing feature set is preserved. Offline regression and compilation results
are not proof of live multiplayer behavior or full visual quality. Older casino and
replacement-feature checklist entries below are historical, not instructions to
reintroduce removed casino gameplay.

## Environment / platform

- [ ] Real Roblox client on console (Xbox/PlayStation) — no console dev kit access.
- [ ] Real mobile hardware thermal throttling / battery-saver behavior.
- [ ] Multi-region server with high-latency players.
- [ ] Live DataStore under Roblox maintenance windows or rate-limit spikes.

## Purchases / economy

- [ ] Real Robux transaction flow (requires live game + payout setup).
- [ ] Game-pass ownership webhook edge cases.
- [ ] Refund/chargeback recovery path.

## Security

- [ ] Exploit-kit injection against the client (memory scanning, remote spoofing).
- [ ] Production anti-cheat EnforcementEnabled=true soak for >24h.
- [ ] Real Discord moderation queue with signed webhook payload.

## Content

- [ ] Casino/crate kit asset when real asset ID is uploaded (`KitReady=true`).
- [ ] Per-casino-game bespoke viewport models (Part 3 of master spec).
- [ ] Guild community features end-to-end in Roblox Studio/live servers: multi-user DataStore persistence, TextService filtering, cross-server behavior, and UI moderation flows. Source implementation and Argon build are not runtime verification.
- [ ] Roblox image asset availability/permissions and platform moderation outcome for guild logos; internal leader review is not platform moderation.
- [ ] Regression coverage for guild chat, announcements, settings, mute/ban, and logo review actions.

## Social / guild

- [ ] Multi-server guild chat federation.
- [ ] Guild war / diplomacy systems (not in current scope).
- [ ] Real TextService filter policy updates.

## New replacement features

- [ ] Skill Tree / Ascension Path (Part 4.3).
- [ ] Squad Loadout Planner / Expedition Route System (Part 4.4).

## Reasons these are out of scope

- Missing assets, platform hardware, or live Roblox services.
- Features not yet designed (Skill Tree, Loadout Planner, per-game casino models).
- Malicious actor testing requires a dedicated red-team environment.

Applicable items must be verified in Roblox and recorded in `SIGNOFF.md` before
claiming full-game sign-off. The former `verify_economy_projection` environment
failure is historical; use the current verifier result rather than that old
failure to assess offline readiness.
