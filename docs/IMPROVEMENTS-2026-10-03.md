# Core gameplay improvement pass

Applied to the restarted main Astral Forge Studio, place 135153679037687. All six new or changed game scripts were compared against repository source after the final sync and matched. Studio is left in Edit mode. Changes have not been published.

## Player-facing changes

- Workshop compares the next level's marginal production gain using the server's level/growth formula. New Best level return sorting favors affordable upgrades; Biggest level gain replaces the misleading base-production sort. Ties keep stable tier order. The purchase planner shows a recommendation and the batch's remaining budget. Comparisons exclude global and machine-specific bonuses.
- Research adds name/bonus search and Available, Can afford, Owned, Coming up and All research filters. Available hides locked and maxed entries by default. Empty searches explain how to recover. Search/filter changes reset scroll position. The mobile batch button has enough width for its label.
- Both upgrade pages buy a budgeted batch of their current results, in the displayed order. Batches respect the selected amount and wait for each server response. One click sends at most 24 purchases. Batch Max shares the budget and buys at most 50 levels per upgrade, matching the server's numeric-request ceiling. Individual Max remains unchanged.
- Failed requests stop the remaining batch; timeouts and page unmounts invalidate continuations. A synchronous latch prevents same-frame duplicate batches. The UI shows progress and completion/failure status.
- Overview goals adapt to advanced players, including level-18 players with no rebirths. Ready rewards take priority, followed by Domain expansion, available rebirth rewards and the next forge-level requirement. First-run guidance and full-vault collection priority remain intact. Actions lead to the relevant activity.

## Validation

- Full `lune run scripts/verify_project.luau` passed after the final code changes, including register headroom and syntax checks for the four new modules.
- Behavioral tests cover budget distribution, selected-amount affordability, server quantity ceilings, currencies through `1e2096`, sequential replies, duplicate replies, failures, cancellation, timeouts and adaptive goals.
- Argon project build passed. Whitespace check passed.
- Studio render regression: all 32 page/overlay states passed at 1920×1080. The final Overview, Workshop and Research versions also passed at 390×844, 844×390, 640×320, 768×1024, 1920×1080 and 3440×1440, with soft motion on the shortest and widest sizes. The smoke harness now uses the same sibling Z-index behavior as the game's UI.
- Running Research UI search was exercised by changing its TextBox: one named result produced a one-upgrade batch; an unmatched query produced an empty state and zero-upgrade batch; clearing search restored four available entries and three affordable purchases.
- Render/search checks used copied snapshots and inert dispatch. Successful purchases against live profiles were not performed by the harness. Multiplayer/receipt/physical-device validation and the previously interrupted server soak remain outstanding; see QA-2026-10-03.md.

No save-schema or monetization changes were introduced. The earlier repair pass remains in place.
