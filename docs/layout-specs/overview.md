# Overview, Workshop, Worlds
Research: /workspace/research/forge-ui-2.md P2.4 "Overview" (landscapePhone budget 170-214, the minimum intrinsic height of about 516),
forge-ui-5 "Worlds" (current-world hero plus compact list, locked rows), and the UIFlexItem fill rows from https://create.roblox.com/docs/ui/list-flex-layouts.

## Overview (changed)
Landscape phone (844x390: 719 wide, 219 fold; 640x286: 588 wide):
- The three metric cards (output / banked / permanent) move from a vertical stack to one flex row.
  The cards are fill items with a 160px minimum width; 3 x 160 + 2 x 10 gap = 500, which fits both 588 and 719.
- metricsH goes from 3 x 72 + 16 = 232 down to 72. topBandH = hero 208 + 72 + 10 = 290, was 450.
- Notes now start at y=300 instead of 460: 160px less scrolling to the first secondary zone.
- Desktop and portrait are unchanged (wide: metrics column beside the hero; portrait: the stack stays).

| viewport | hero | metrics | topBand |
|---|---|---|---|
| 1920x1080 (wide) | 258 | column = hero | 258 |
| 1366x768 | 248 | row 104 | 362 |
| 844x390 | 208 | row 72 | 290 (was 450) |

## Workshop, Worlds
- Worlds: two columns on wide screens through SplitColumns; taglines are already tooltips; locked rows use a requirement colour on the button.
  The current-world hero split (forge-ui-5 R1/R2) is a follow-up.
- Workshop: the wide tool column landed in look-prog (2a9b0177). No change in this batch.
