# Astral Forge: planning, audio, layouts, admin, and VR

Applied to the confirmed main Studio place, Astral Forge (135153679037687).

## Changes

- Next Plan now shows exact Flux/Stardust shortfalls using Omega arithmetic, upgrade readiness, configured milestone intervals, before/after permanent multipliers, and routes to Shift Plan and Workshop. Desktop budget/benefit cards share a row; narrow screens stack them.
- Shift Plan prioritizes a completed shift or earned reward, displays charge/combo/core information, and separates daily directives, loadout, milestones, and protocols into a workbench. Its default view mounts roughly half as many UI descendants as the initial rewrite. Equipping a channel retains other selected channels, respects available slots, and keeps at least one channel equipped. Protocol costs use the server's rounding rule; maximum levels cannot be purchased.
- Replaced four failed soundtrack assets with 24 Creator Store tracks verified to load in the Studio client. Each deck now preloads its actual Sound instance: warming ID strings alone did not initialize the stopped decoder in a fresh session. Late callbacks cannot fail a replacement track. Fisher–Yates shuffle bags avoid immediate repeats, preloaded spare decks retain equal-power crossfades, failed tracks have a cooldown, and complete loading failures back off. Recovery tests cover the case where only the current track remains available. Saved music/mute settings remain effective.
- Wheel sectors show numbers instead of colliding reward names. The numbered prize legend shares the page scroll, reserves space for every row, and has room for wrapped titles and rarity text. The wheel no longer shrinks to squeeze an artificial nested prize viewport above the fold.
- Mobile supports both orientations. Controller focus excludes disabled layers and fully clipped controls. Connecting a controller no longer forces controller mode while the player continues using a keyboard/mouse. TV safe margins follow the ten-foot interface, and hints map to Xbox/PlayStation button names.
- All 97 admin commands receive consistent input metadata and previews. The 64 existing profile commands now have individual executors under the existing transaction/audit/save wrapper. Added SetFlux, SetVault, SetContinuumRank, SetFreeSpins, ResetAnomalyCharge, and ClearAnomalyCombo. Zero-value setters work, count commands reject fractions, temporary-effect durations match the executor's bounds, moderation rejects non-finite amounts, and repeated clicks are latched. Setter commands require the existing arm/confirm flow. Selection values persist through snapshot refreshes.
- VR uses an interactive SurfaceGui in PlayerGui with a queryable world panel, native laser/controller settings, comfortable motion, recenter/show-hide controls, canvas-aware layout, and VR destinations for dropdowns, domain overlays, and shutdown UI. The panel follows base-camera translation while staying stable during head turns. Recenter uses the actual gaze direction, including pitch. HUD rotation/scale pranks do not transform the VR interface. Switching modes restores the camera and PlayerModule state.

## Verification

- `lune run scripts/verify_project.luau`: passed, including meaningful fixtures for loadouts, large-number budgets, configured milestones, shuffle/failure recovery, all 97 admin executor routes, zero setters, vault caps, and reset/grant behavior.
- `argon build default.project.json -x -o .argon-validation.rbxlx`: passed.
- 224 initial page renders: all 32 pages across desktop, phone portrait, phone landscape, tablet, Xbox, PlayStation, and Quest canvas sizes; no page crashes or visible text overflow.
- Final desktop sweep: 32 pages sampled at top, middle, and bottom of scrolling regions; no page crashes or visible text overflow.
- Final affected-page sweep: Next Plan, Shift Plan, Wheel, and Admin on phone portrait/landscape, Xbox, and PlayStation, also sampled at three scroll positions; no page crashes or visible text overflow.
- Actual mouse clicks selected the Loadout, Protocols, and Milestones workbench tabs. Snapshot and render tests do not execute gameplay/admin requests.
- 31 pages were mounted in a VR SurfaceGui separately from flat page sizes. A second 31-page pass ran from a native LocalScript with emulated VR detected. Both reported no page crashes. The final gaze-based recenter projected the panel center inside the camera viewport. A downward-facing initial camera exposed a recenter bug and led to that fix. This establishes mount/geometry behavior, not physical headset comfort or laser-input certification.
- All 24 music assets passed a native LocalScript decoder probe with zero failures. A clean game session loaded both real soundtrack decks and played the active deck. Seeking near the end triggered the actual four-second crossfade, stopped the outgoing deck, and left the new shuffled track playing at its normal volume.

## Verification limits

Device simulation checks geometry, rendering, and emulated input presentation. Physical Xbox/PlayStation controllers, headset comfort, controller lasers, and headset keyboard entry still require hardware testing. These checks do not certify every possible layout state, multiplayer interaction, or persistent-data failure. No long server soak was run because the earlier release-audit runner stalled Studio. Changes are synchronized into Studio; this pass does not publish the experience.

Studio was returned to Edit mode and its device simulator was stopped, restoring the default viewport. Temporary runtime test objects are discarded with the Play session.

The final source fingerprint comparison matched all 28 changed/new game scripts and retained repair scripts between the workspace and the main Studio instance, including the large merged UI suite. The final automated suite, project build, and whitespace check passed.

## Music sources

These free Creator Store audio assets were returned under the creator name DistrokidOfficial and successfully loaded in this place during testing. Asset IDs and source pages are recorded for replacement/attribution review.

| Track | Creator Store asset |
| --- | --- |
| Space Ambient | [140533822783920](https://create.roblox.com/store/asset/140533822783920) |
| Galactic Market | [85922328966318](https://create.roblox.com/store/asset/85922328966318) |
| Slow Breathing Aurora (Space Ambient) | [140041908508788](https://create.roblox.com/store/asset/140041908508788) |
| Return Signal Hopeful Future Ambient Music | [134433077845062](https://create.roblox.com/store/asset/134433077845062) |
| Cosmic Cafe | [136898642923218](https://create.roblox.com/store/asset/136898642923218) |
| Zero Gravity | [102039057339088](https://create.roblox.com/store/asset/102039057339088) |
| Twilight’s Soothing Cascade | [139804134367647](https://create.roblox.com/store/asset/139804134367647) |
| Nebula Dream Theta Waves | [139793680497894](https://create.roblox.com/store/asset/139793680497894) |
| Deep Space Ocean | [136827064604146](https://create.roblox.com/store/asset/136827064604146) |
| Liminal Space Ambient (Lost in the Halls) | [133670858533628](https://create.roblox.com/store/asset/133670858533628) |
| Space Station '98 | [128285716110465](https://create.roblox.com/store/asset/128285716110465) |
| Hello in There Space Ambient | [111560725873026](https://create.roblox.com/store/asset/111560725873026) |
| Adrenaline Arcade Synthwave | [138551890276730](https://create.roblox.com/store/asset/138551890276730) |
| Feedback | [122703970718439](https://create.roblox.com/store/asset/122703970718439) |
| Desperation | [81466105858478](https://create.roblox.com/store/asset/81466105858478) |
| Resistance | [99903926483608](https://create.roblox.com/store/asset/99903926483608) |
| Automated | [93964414292507](https://create.roblox.com/store/asset/93964414292507) |
| Aloha Sunset (Hawaiian Synth) | [118508726012870](https://create.roblox.com/store/asset/118508726012870) |
| Celestial String Awakening 2 | [101244629093073](https://create.roblox.com/store/asset/101244629093073) |
| Calm Cinematic Space | [137911990035159](https://create.roblox.com/store/asset/137911990035159) |
| Soft Intro Reflections | [87900257498941](https://create.roblox.com/store/asset/87900257498941) |
| Temple of Silent Light 2 | [86497547233756](https://create.roblox.com/store/asset/86497547233756) |
| River of Soft Gold 2 | [114636840398015](https://create.roblox.com/store/asset/114636840398015) |
| Silent Cinematic Prelude | [85227514374326](https://create.roblox.com/store/asset/85227514374326) |
