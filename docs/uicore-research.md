# UiCore revamp: research notes and what was used

Written 2026-10-22 for the UiCore/tooltip rewrite. Each point says what changed in code.

## Tooltips
- **Placement order: offset, then flip, then shift, then arrow.** Floating UI runs its middleware in this order and puts the arrow last, after shift, so the arrow points at the target's center from wherever the bubble ended up. `UiCore/tooltip/placement.ts` follows the same order. It tries the preferred side, then the opposite side, then the two cross sides. It slides the winner along its own axis only, so the bubble never covers its target, and clamps the arrow away from the rounded corners.
  Sources: https://floating-ui.com/docs/middleware, https://floating-ui.com/docs/flip, https://floating-ui.com/docs/arrow
- **Measure the live AbsoluteSize, and account for the top-bar inset.** DevForum tooltip threads report two bugs: a tip whose size was read once while AutomaticSize was still settling, and a Y clamp that ignored the GuiInset. The layer re-measures every frame while the tip is open. It shows only after two measured frames, adds `GetGuiInset()` to targets inside non-IgnoreGuiInset ScreenGuis, and clamps to a DeviceSafeInsets frame.
  Sources: https://devforum.roblox.com/t/tooltip-sytem-issue/3783533, https://devforum.roblox.com/t/tooltip-module-an-easy-way-to-make-tooltips-for-ui-objects/1266069
- **Gamepad.** `GuiService.SelectedObject` is the source of truth. The intent module listens to its change signal, so a gamepad tip closes when selection leaves its target, even when the target never fired SelectionLost. Tips also close when the Roblox menu opens (`MenuIsOpen`).
  Sources: https://create.roblox.com/docs/reference/engine/classes/GuiService.md, https://devforum.roblox.com/t/how-to-control-xbox-selection-gui/2026798
- **Hover intent.** A pointer that is still sweeping faster than 900 px/s restarts the wait, so dragging across a grid doesn't flash a tip on every cell. The base delays are the existing 0.45 s and 0.08 s warm.
- **One global layer.** The tooltip layer renders through `ReactRoblox.createPortal` into its own ScreenGui (DisplayOrder 9000), not through ZIndex inside pages. Source: https://react.luau.page/api-reference/react-roblox/

## Modals, confirms, toasts (from /workspace/research/forge-ui-1.md and forge-ui-2.md)
- **SelectionGroup with all four SelectionBehaviors set to Stop on the modal card.** This is the documented popup pattern. It was applied to the ConfirmDialog card, the ReleaseNotesModal card, the OfflineRewards card and the new `UiModal`. It is exported as `overlayCore.ModalSelectionScope`. `PanelSelectionScope` (Escape) is provided for page panels.
  Sources: https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278, https://create.roblox.com/docs/reference/engine/enums/SelectionBehavior.md, https://devforum.roblox.com/t/updated-gamepad-ui-highlight-improvements/1582185
- **Autofocus when the open motion settles, not on a fixed timer.** Selection fails while a panel is still rising in. `useGamepadAutofocus(active, presence)` now focuses when presence reaches 0.95. A 0.6 s backstop covers reduced motion. It picks the lowest `SelectionOrder`, matching `GuiService:Select` rules. Callers that pass no binding keep the old 0.16 s behavior.
- **A requestConfirm queue with a merge key.** Requests are now first in, first out instead of "a newer request cancels the open one". A request with the same `key` as the open dialog is dropped, and one matching a queued request replaces it in place. `replace: true` keeps the old behavior.
- **Toast rules.** Notices stay on screen for at least 2.5 s. Reading time is roughly 1 s per 12 words beyond the first second, capped at 6 s or the player's own longer setting (`noticeMath.ReadingHold`). The island already collapses duplicate notices and shows one card per lane. A separate alert lane was **not** built, because it would add a new surface; it's listed as a follow-up.
  Source: /workspace/research/forge-ui-2.md

## Libraries and patterns looked at
- **littensy/pretty-react-hooks** (MIT, 0.6.4). The repo already vendored it for runtime use. It is now a typed dependency, and `useLatest` and `useBindingListener` are used by the tooltip hooks and the autofocus. https://github.com/littensy/pretty-react-hooks, https://www.npmjs.com/package/@rbxts/pretty-react-hooks
- **littensy/slither** (an open-source roblox-ts + React game). Its app root mounts global layers (alerts and the like) once, beside the pages. This is the same shape as TooltipProvider, ConfirmHost and the island. https://github.com/littensy/slither
- **@rbxts/ripple** (maintained, per the forge-ui-3 registry check) was not adopted for UI motion. Every timing must stay identical, so the new `motionScheduler.ts` runs on MotionKit's existing frame driver with the existing `motionTokens` easings.
- **@rbxts/janitor** was checked but not added. The repo already has `@rbxts/maid`, and nothing in this pass needed both.
- **@rbxts/charm** was not adopted, because the client state shape stays as it is.
- **Nevermore (Quenty).** Its UI modules are Luau-first and would need wrappers. They were not added: the rules forbid shims and new .luau.
- roblox-ts docs: https://roblox-ts.com/docs/

## Not verified
- Nothing was run in Studio or tested with a controller. SelectionGroup scoping and settle-based focus need a hands-on check on console and phone.
