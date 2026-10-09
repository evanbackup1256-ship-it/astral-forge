# Astral Forge v2 — Explicitly Not Tested

> Transparency list. If it is not listed here and not signed off in `SIGNOFF.md`, it is not considered verified.
> Last updated: 2026-10-09

## Version 7.0 runtime verification still required

- [ ] Live measured FPS/frame-time comparison on desktop and mobile, including
  dense domains, inventory, chat and repeated panel transitions.
- [ ] Visual acceptance against the established palette, typography and spacing;
  a cohesive, intentionally designed feel requires human playtest review.
- [ ] Two-client trade: all currencies, boosts, keys and six artifacts; edits while
  syncing, cancellation, reconnects, readiness reset and final settlement.
- [ ] All 37 animated title styles rendered by HyperText in Roblox.
- [ ] Artifact equip/upgrade/respawn visibility for multiple clients and distance
  culling; custom chat and player-list consistency.
- [ ] Domain selection changes, zoom, touch/gamepad navigation and reduced motion.
- [ ] UI SFX playback and permissions on the owning Roblox experience, volume
  settings and music/UI voice mixing.
- [ ] Production save/load and legacy transfer with schema 21.

The full offline verification suite now passes, and all 330 Luau files compile at
O0/O1/O2. Argon responds on localhost:8000, but the Roblox bridge is disconnected.
These checks do not verify live playback, frame rate, visuals or multiplayer.

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

- [ ] Crate and domain kit availability/permissions in the owning Roblox experience.
- [ ] Guild community features end-to-end in Roblox Studio/live servers: multi-user DataStore persistence, TextService filtering, cross-server behavior, and UI moderation flows. Source implementation and Argon build are not runtime verification.
- [ ] Roblox image asset availability/permissions and platform moderation outcome for guild logos; internal leader review is not platform moderation.
- [ ] Live guild chat, announcements, settings, mute/ban and logo review flows.

## Social / guild

- [ ] Multi-server guild chat federation.
- [ ] Guild war / diplomacy systems (not in current scope).
- [ ] Real TextService filter policy updates.

## New replacement features

- [ ] Skill Tree / Ascension Path (Part 4.3).
- [ ] Squad Loadout Planner / Expedition Route System (Part 4.4).

## Reasons these are out of scope

- Missing assets, platform hardware, or live Roblox services.
- Remaining platform/content prerequisites. Casino rebuilding is superseded by
  the earlier user-requested removal; no remaining feature is removed by this pass.
- Malicious actor testing requires a dedicated red-team environment.

These items need runtime evidence before production sign-off. Offline verification
is green; it must not be described as complete Studio or live-server testing.
