# Astral Forge design system

Web versions of the game's UI building blocks, for designing in Claude Design.
The game itself is Luau/React-Roblox; these files mirror it and are not used in game.

## Where each value comes from

| Here | In the game |
| --- | --- |
| `--af-*` colours in `tokens.css` | `src/Shared/AstralForge/Shared/ForgeTheme.luau` (`base`, `rarity`, `feature`) |
| Spacing, radii, shell sizes | `src/Client/AstralForge/CoreKit.luau`, `theme` → `Layout` |
| Shadow / stroke strengths | `CoreKit.luau`, `theme` → `Chrome` (CSS alpha = 1 − Roblox transparency) |
| `.af-button` | `UiCore.luau` `Button` |
| `.af-panel` | `UiCore.luau` `Panel` |
| `.af-badge`, `.af-count` | `UiCore.luau` `Badge`, `CountBadge` |
| `.af-chip` | `UiCore.luau` `Chip` (mobile header currencies) |
| `.af-meter` | `UiCore.luau` `Meter` |
| `.af-divider` | `UiCore.luau` `Divider` |

## Rules carried over from the game

- Font is Builder Sans (Medium 500, Bold 700, ExtraBold 800). Figtree stands in on the web.
- Smallest text is 11px. Button labels are 15px bold.
- Every tap target is at least 44px.
- Text colour is picked for contrast against its fill (4.5:1). Light fills like mango, cyan
  and mint take dark `ink` text.
- Surfaces use a soft top-light gradient, never a hard band at the top edge.
- Icons are real icon art from the game's atlas, never shapes built from boxes.
- Layouts get real gaps (`--af-panel-gap` 18px). No cramped grids of big buttons.

## Keeping it in sync

When `ForgeTheme.luau` or `CoreKit` `Layout` changes, update `tokens.css` to match and
re-run `/design-sync`.
