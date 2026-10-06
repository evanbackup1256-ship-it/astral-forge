# Astral Forge v2 — Explicitly Not Tested

> Transparency list. If it is not listed here and not signed off in `SIGNOFF.md`, it is not considered verified.
> Last updated: 2026-10-05

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
- [ ] Guild logo upload/moderation pipeline.

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

These items must each be moved from `NOT_TESTED.md` to a verified row in `SIGNOFF.md` before release.
