# Astral Forge — 100-item to-do (based on reading master 67a49bfd)

## Architecture / server (1–15)
1. Split `Services/GameService.ts` (7,231 lines, 149 methods): move `_tradeAction` (431 lines) into a Trade domain module first, behind the same remote names.
2. Move `_handleAction` (371-line dispatcher) to a table of typed handlers keyed by action, each with its own payload type.
3. Split `_snapshot` (317 lines) into per-slice builders, and send only the changed slices (diffs) to the client.
4. Merge `GuildService.ts` and `GuildCommunity.ts`. Delete the 238-line `_guildAction` duplicate routing.
5. Replace the hand-written lazy loaders in EconomyMath/ProfileMath/TradeSuite/OpsMath (copied 4 times) with real ES module imports so members are typed.
6. Break `DataService.sanitize` (655 lines) into per-subsystem sanitizers with a unit test each, run against `scripts/fixtures`.
7. Split `RemoteFirewall.validateActionPayload` (676-line if/else over 150 actions) into per-action schema rules. Keep the existing rate limits.
8. Split `Progression.ts`: one 1,041-line function covers forge path, quests, weekly, season and wheel. Make it 5 modules.
9. Merge the duplicated helpers (`count`, `ensure`, `finite`, `num`, `deepCopy`, `utcDay`) into one Shared/util. `finite` and `num` clamp differently, so keep both behaviours.
10. Replace AtomicState deep copies with structural diffs. Profile the per-tick cost first (docs/PERF-ATOMIC-UPDATE.md).
11. Make the boot dependency graph explicit and fail loudly on cycles. verify_boot_graph exists, so extend it to cover controllers.
12. Make every MarketplaceService receipt handler idempotent, keyed by PurchaseId and stored in the profile journal.
13. Add an auditable economy ledger entry for every currency change over a threshold, viewable in Admin.
14. Turn anti-cheat into rule plugins and surface SecurityFlags with counts and last-seen times in the Admin panel.
15. Put admin commands on a permission matrix (role × command), with each use logged to SecurityLedger.

## Data / saves (16–22)
16. Add a save version bump plus a migration test for every new profile field. Gate merges on verify_save_migration.
17. Give relics and inventory items stable GUIDs and add an index by kind, so the inventory doesn't do linear scans.
18. Cap the growth of unbounded profile arrays (mail, history, trade log) and keep the newest N.
19. Write a backup snapshot to a second DataStore key once a day, with an admin restore command.
20. Show a session-lock steal warning in the UI ("loaded on another server") instead of a silent wait.
21. Offline progress: make it pure and tested, and show a breakdown card on rejoin with time away, gains and the cap reached.
22. Add a right-to-erasure handler for the user data stores.

## Gameplay / content (23–40)
23. Rewrite Expeditions (system + UI) and keep it save-compatible (open an06).
24. Add expedition crew synergies (affinity pairs) so team choices matter.
25. Lab orders: one order reroll per reset, with an escalating cost.
26. Echo Forge: chord preset save/load (3 slots).
27. Constellations respec with a refund preview.
28. Worlds: per-stage first-clear rewards and a 3-star mastery track.
29. Add a mid-game "Overdrive" tier between rebirth and ascension to fill the pacing gap in the balance sim.
30. Weekly rotating mutators (×2 relic drops, half-cost research) shown on Overview.
31. A boss every N stages, with a timed DPS check and unique relic drops.
32. Relic set bonuses (2/4-piece) with a set tracker in the inventory.
33. Companion evolution stages with visible model changes.
34. RecipeBench recipes discovered through hints instead of shown all at once.
35. Daily login calendar with a streak-save item.
36. Story chapter 2 with dialogue choices that grant different cosmetics.
37. Wheel: show the odds table and a pity counter.
38. Anomaly events: server-wide progress bar and a shared reward.
39. A sandbox stage where new players can try a build without risk.
40. Specializations: 2 loadouts, switchable outside combat.

## Economy / balance (41–50)
41. Run scripts/_balance_sim on every content patch in CI and fail on a pacing regression over 15%.
42. A late-game currency sink (cosmetic forge, prestige frames) to fight inflation.
43. Bazaar: price floors and ceilings from the 7-day median, plus a wash-trading check.
44. Trade engine: an escrow state machine with a cancel timeout and a two-step confirm that shows the value diff.
45. Crate RNG seeded per player, with roll logs for support replays.
46. A "bonus breakdown" view for each multiplier source (unified multiplier stack).
47. Soft caps instead of hard caps on research multipliers, with the curve shown in the tooltip.
48. compactNumber: keep display precision up to 1e308, then switch to scientific notation.
49. One reset spec for rebirth/ascension (already in verify_reset_spec), with "what you keep" shown in the UI.
50. Limited-event currency converts to a capped amount of the main currency when the event ends.

## UI / UX / layout (51–70)
51. Layout engine: content-aware columns, packing, and filling leftover height (this patch).
52. Whitespace debug overlay (Workspace attribute `LayoutDebug`) that highlights empty bands (this patch).
53. Credits rewrite (this patch).
54. Rewrite the filter chips / segmented control with count badges and use it game-wide (an05).
55. Fix the LayoutGuard log spam and the false ActionCollision reports (BuffIsland, Inventory inspect, Overview) (an04).
56. Use spacing tokens (`Space` in layoutEngine) everywhere instead of literal pixels. pages/views/*.ts has hundreds of literals.
57. Port the auto-converted Luau views (Inventory, Guild, Wheel, Chat, Crew, Story, Mailbox, EchoForge; about 2,000 `luaProp/luaCall` calls) to idiomatic TSX.
58. One Modal primitive with a focus trap and back-layer for every confirm (ui18).
59. Unify empty states: one illustration per domain and a button that jumps to where you can fix it.
60. Icon consistency pass: one stroke weight, one grid (ui24).
61. Gamepad: every page reachable with LB/RB and the D-pad, with button hints in the footer.
62. Phone 11-size matrix check in CI (verify_mobile_matrix plus screenshot stories).
63. Virtualize the inventory list (render only visible rows) for 1,000+ relics.
64. QuickFind: fuzzy search across items, pages and settings, with recent searches.
65. Tooltips: tune the delay, add touch long-press, and never clip off-screen.
66. Notification center with history and "mark all read".
67. Settings: a search box and per-section reset.
68. A reduced-motion preview in Settings.
69. A text-scale setting (90–130%) that the layout engine's measureText respects.
70. Colour-blind palettes for rarity colours.

## Performance (71–78)
71. One shared animation scheduler. RiseIn and StackRiseBlock each connect their own RenderStepped.
72. Memoize page trees. Overview (2,471 lines) re-renders on every snapshot tick.
73. Throttle snapshot pushes to 4 Hz, with a priority lane for currency.
74. Pool particle and JuiceFx instances.
75. Lazy-mount pages in PageRouter and unmount pages hidden for more than 60 s.
76. BuffStrip (2,137 lines): update icons only on change.
77. Replace TextService.GetTextSize calls during render with the cached measureText.
78. Log a per-system ms budget for the server tick, with sampling.

## Retention / social / monetization (79–90)
79. Season pass with free and premium tracks, plus catch-up XP for late joiners.
80. Show the friends bonus on the playerlist, with an invite button.
81. Guild wars: a weekly score race with tiered rewards.
82. Gift gamepasses and products to friends, with receipts.
83. Weekly leaderboards alongside all-time, cached through OrderedDataStore.
84. Show the starter pack once after 10 minutes, never during the first-session tutorial.
85. A clearly labelled Premium perk (+5% xp).
86. A comeback reward after 3 or more days away.
87. Experience notifications for finished expeditions.
88. A shareable profile card (ProfileStylePanel) with frame cosmetics.
89. Chat: quick emotes and guild-channel unread badges.
90. Referral tracking through the invite prompt, with milestone rewards.

## Tooling / tests / ops (91–100)
91. Make the test harness run against the TS sources, with a single `scripts/ci.sh` entry.
92. Run rbxtsc and the full verify_* suite in GitHub Actions on every PR.
93. Story snapshots (StorySnapshot.ts) rendered at the 11 phone sizes plus desktop.
94. Locale key lint in CI (lint_locale.luau) that blocks missing keys.
95. Structured telemetry with levels and sampling, plus a tutorial funnel drop-off report.
96. Remove luauDeps.ts / luauKits.ts shims once the views are ported.
97. A verify script that fails if a webhook URL ever appears in the repo (the webhook stays in the ServerStorage attribute).
98. Automate the release checklist: version bump, changelog from commits, Argon build check.
99. Remote fuzz test: random payloads against RemoteFirewall must never error the server.
100. Per-release client frame-time budget on a low-end phone profile.
