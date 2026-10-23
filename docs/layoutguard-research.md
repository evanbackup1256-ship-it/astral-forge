# LayoutGuard: research notes and sources

This file records the facts each LayoutGuard module depends on and where each fact comes from. Section names match the modules under `src/Client/AstralForge/LayoutGuard/`.

## 1. Geometry: what Roblox reports (geom.ts, constraints.ts, capture.ts)
- `AbsolutePosition` is the top-left corner of the element's unrotated box, and it already includes UIScale. `AbsoluteRotation` is the summed rotation of the element and its ancestors. Rotation does not change AbsoluteSize, so rotated controls get an OBB and use SAT overlap.
  https://create.roblox.com/docs/reference/engine/classes/GuiBase2d
- The Scale+Offset rule is `abs = parent * scale + offset`. AnchorPoint shifts the box by `-anchor * size`. SizeConstraint (RelativeXX / RelativeYY) resolves both axes against one parent axis.
  https://create.roblox.com/docs/reference/engine/classes/GuiObject and https://create.roblox.com/docs/ui/position-and-size
- UIScale multiplies the whole subtree around the AnchorPoint, and nested scales multiply together.
  https://create.roblox.com/docs/reference/engine/classes/UIScale
- UIPadding offsets plus scale relative to the parent's absolute size.
  https://create.roblox.com/docs/reference/engine/classes/UIPadding
- UIAspectRatioConstraint, including DominantAxis and AspectType FitWithinMaxSize / ScaleWithParentSize.
  https://create.roblox.com/docs/reference/engine/classes/UIAspectRatioConstraint
- UISizeConstraint clamps the size. When MinSize is above MaxSize, MinSize wins.
  https://create.roblox.com/docs/reference/engine/classes/UISizeConstraint
- UIListLayout fill, padding, alignment, Wraps and HorizontalFlex/VerticalFlex, and UIFlexItem grow/shrink ratios. These are emulated in layoutSim.ts.
  https://create.roblox.com/docs/reference/engine/classes/UIListLayout , https://create.roblox.com/docs/reference/engine/classes/UIFlexItem , https://create.roblox.com/docs/ui/size-modifiers
- UIGridLayout cell size and padding, FillDirectionMaxCells, and StartCorner.
  https://create.roblox.com/docs/reference/engine/classes/UIGridLayout
- ScrollingFrame `AbsoluteCanvasSize`, `AutomaticCanvasSize` and `ScrollingEnabled`. These back the scroll.ts checks.
  https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame
- `ZIndexBehavior` Sibling vs Global determines paint order, which capture.ts uses to build its paint ranking.
  https://create.roblox.com/docs/reference/engine/enums/ZIndexBehavior
- CanvasGroup `GroupTransparency` multiplies down the subtree.
  https://create.roblox.com/docs/reference/engine/classes/CanvasGroup

## 2. Safe areas, notches and the top bar (touch.ts, capture.ts, matrix.ts)
- `ScreenGui.ScreenInsets` (None / DeviceSafeInsets / CoreUISafeInsets / TopbarSafeInsets) and `GuiService:GetInsetArea`, with `GetGuiInset` as the fallback.
  https://create.roblox.com/docs/reference/engine/classes/ScreenGui , https://create.roblox.com/docs/reference/engine/classes/GuiService
- The 2024 top bar redesign sets the core UI inset height to 58px. This comes from the 2024 top bar announcement on DevForum. It is not hard-coded at runtime: capture.ts reads GetInsetArea / GetGuiInset, and 58 is only the matrix default.
- The phone dimensions in matrix.ts are logical points for the 11 devices that Studio's Device Emulator offers. Roblox reports logical pixels, not physical ones.
  https://create.roblox.com/docs/studio/testing-modes#device-emulation

## 3. Text measurement (measure.ts, rules/text.ts)
- `TextService:GetTextBoundsAsync(GetTextBoundsParams)` is the supported API for Font objects. It yields and can fail, so measure.ts wraps it in pcall and caches results under the key (text, size, font, width).
  https://create.roblox.com/docs/reference/engine/classes/TextService#GetTextBoundsAsync , https://create.roblox.com/docs/reference/engine/datatypes/GetTextBoundsParams
- `TextService:GetTextSize` is the legacy synchronous fallback.
- `TextFits`, `TextTruncate` and `TextScaled` matter here: scaled or truncated text never counts as overflow. `RichText` markup is stripped before measuring.
  https://create.roblox.com/docs/reference/engine/classes/TextLabel , https://create.roblox.com/docs/ui/rich-text
- On DevForum, Roblox staff say GetTextBoundsAsync results are stable per font and size, which justifies an LRU cache.
  https://devforum.roblox.com/t/2149310

## 4. Touch targets and spacing (rules/touch.ts)
- WCAG 2.2 SC 2.5.8 sets a 24×24 CSS px minimum, with a spacing exception: a 24px circle centred on each target must not intersect another target.
  https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG SC 2.5.5 (AAA) sets 44×44.
  https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html
- Apple HIG recommends 44×44 pt.
  https://developer.apple.com/design/human-interface-guidelines/accessibility
- Material Design recommends 48×48 dp with 8dp spacing.
  https://m3.material.io/foundations/designing/structure (touch targets) and https://m2.material.io/develop/web/supporting/touch-target

## 5. Gamepad focus (rules/focus.ts)
- `SelectionOrder`: the lowest value is selected first, and ties go to the top, then the left. `NextSelectionUp/Down/Left/Right`, `Selectable`, `GuiService.SelectedObject` and `SelectionGroup` are also relevant.
  https://create.roblox.com/docs/reference/engine/classes/GuiObject#SelectionOrder , https://create.roblox.com/docs/input/gamepad
- With no explicit link, the engine picks a neighbour in a half-plane cone, weighted by distance on the primary axis plus the cross axis. focus.ts uses primary + 2×cross, which matches the behaviour the community has documented.
  https://devforum.roblox.com/t/1791278

## 6. Spatial indexing and overlap math (spatial.ts, geom.ts)
- Sweep-and-prune: sort intervals on one axis and keep an active set, giving O((n + k) log n). Reference implementations: https://github.com/schteppe/sweep-and-prune and https://github.com/b3gm/prune-juice
- R-tree / STR bulk loading. RBush is the reference for static queries; LayoutGuard uses a lighter treap-ordered interval index instead.
  https://github.com/mourner/rbush
- Interval trees and stabbing queries: de Berg, Cheong, van Kreveld and Overmars, *Computational Geometry: Algorithms and Applications*, 3rd ed., ch. 10. Treaps: Seidel & Aragon, "Randomized Search Trees", Algorithmica 1996.
  Intervals are open: `[a, b]` meets `[c, d]` iff `a < d && c < b`. This means edge-touching siblings in a list layout are not an overlap.
- The Separating Axis Theorem for OBB vs OBB: Ericson, *Real-Time Collision Detection*, §4.4.
- The union area of rectangles uses coordinate compression and a sweep (Klee's measure problem, O(n² log n) at our n). The largest empty rectangle uses histogram stacks over a compressed grid (Naamad, Lee & Hsu 1984, simplified).

## 7. Clustering for alignment and gutters (metrics.ts, rules/alignment.ts)
- Gap clustering of 1D edges: break where a gap exceeds tolerance, then take the mode line. The optimal k-means reference is Wang & Song, "Ckmeans.1d.dp", The R Journal 3(2), 2011.
  https://journal.r-project.org/articles/RJ-2011-015/RJ-2011-015.pdf
- The coefficient of variation is used for gutter consistency, and Kendall tau distance for comparing focus order with visual order.

## 8. Operational design (engine.ts, logger.ts, LayoutGuardController.ts)
- Token-bucket rate limiting (capacity 6, refill 0.2/s) and grouping per (rule, signature) fix the repeated spam: ActionCollision BuffIsland/Inventory/Overview, and "BuffIsland 12px outside parent".
- Event-driven scans with a quiet period, then a budgeted coroutine on Heartbeat. This follows Roblox's guidance against per-frame polling of GUI properties and toward `GetPropertyChangedSignal`.
  https://create.roblox.com/docs/performance-optimization/improve#scripts
- Confirmation over 2 stable scans removes findings caused by tween transients. UI tweens are flagged with `inMotion`.
  https://create.roblox.com/docs/reference/engine/classes/TweenService
