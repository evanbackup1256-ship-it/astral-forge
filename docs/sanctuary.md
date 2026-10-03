# The sanctuary: how it fits together

## Client (`src/Client/AstralForge/SanctuaryKit.luau`)

One merged module; every member lives in its own closure (its own 200-local budget) and loads lazily.

| Member | Job |
| --- | --- |
| `sanctuaryPresence` | Enter/leave. Applies the sanctuary lighting (sky, haze, bloom, grade, rays) and region moods, starts/stops `sanctuaryAtmos`. |
| `sanctuaryAtmos` | Per-region air: motes, embers, snow, smoke, storm sparks, three aurora ribbons, a faint far blur. Low graphics quality gets fewer particles and no aurora/blur. |
| `sanctuaryWorld` | The walkable world and every boss visual: bodies, telegraphs, VFX, cutscenes, screen effects. Also owns `ScreenFx.arena` (below). |
| `sanctuaryHud` | Region banner, ore chips, boss bar (boss colours, phase count, phase notches, low-health pulse), strike/recall, ultimate warning, hit numbers. |
| `sanctuaryHudPlan` | Every HUD rectangle, computed once per viewport so nothing overlaps at any screen size. |
| `sanctuaryControls` | Avatar movement and the follow camera. |
| `sanctuaryAmbience` | Region beds and the boss fight layer. |
| `sanctuarySignals` | The event bus between the server's effect messages and the client systems. |

`ScreenFx.arena` (in `sanctuaryWorld`) is the boss arena as a place: a rune floor, a wall of energy that rises
when the fight starts, sparks, phase tint, white flare at a phase change, red burn at enrage. It has no
collision and never blocks the camera. It is a table on `ScreenFx` because the world closure is at Luau's
200-local limit; add helpers to a table, not as new `local`s.

## Server (`src/Server/AstralForge/Services/WorldServices.luau`)

* `RiftBossService` runs one boss at a time on a fixed rotation. `_forced` / `_chainNext` / the `BossAdminCommand`
  remote let an admin (`ServerConfig.AdminUserIds`) summon a boss or chain all seven; the client shows an
  owner-only "Bosses" button.
* A pattern's slams go out as one batched message per player (`_send` / `_flush`), not one per slam.
* Terrain: `island` cuts the rough shape; `dress` adds surface patches, stalactites, outcrops, rim bumps and swells.
* Rules live in `RiftBossMath` (pure; `EconomyMath.luau`). Boss data lives in `SharedData.luau` (`SanctuaryConfig`).

## Guards (`scripts/`)

`verify_rift_boss_roster.luau` checks every boss: shape, cues, dialogue, attack params, fairness (telegraphs,
patterns that fit the arena) and balance (a lone fighter's health is unchanged; 5/20/60 level-1 fighters take
30-90% of the active window). `verify_sanctuary_world.luau` checks the world, the bus and the solo/small-group
time to kill. `verify_register_headroom.luau` keeps every long function 8 locals under Luau's limit.

## Playtesting a boss

`tools/playtest/boss_playtest.server.luau` runs every boss's demo (every attack and ultimate) in a Studio play
session and records moves, warnings/errors, the slowest frame and instance leaks. See the file's header.
Studio's own `screen_capture` returns only the 2D layer; to see the 3D scene the Studio window has to be on
screen (a real screenshot).
