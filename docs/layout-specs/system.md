# System: Settings, Leaderboards, Command, Admin, Anomaly, Story, Wheel, Inventory, EchoForge
Research: /workspace/research/forge-ui-6.md "Settings" and "Leaderboards". The recommendations are label-left / control-right rows with no
per-row description, and a picker that shows `short` only with flex tabs (https://create.roblox.com/docs/ui/list-flex-layouts).
forge-ui-2 P2.4 gives the Command, Admin and Inventory budgets.

Checked at 1920x1080, 1366x768 and 844x390 (719 wide, 219 fold):
- Settings (changed): rows hold a label and a control only, so the row heights now fit those two.
  - Desktop 56 = 6 + 44 control + 6 (label y=18, h20, centred).
  - Stacked 86 = 10 + 20 label + 10 + 44 control + 2.
  - The old 68/110 left 24px empty per desktop row and a 34px empty band per phone row.
  - 12 rows on a phone: 1320 -> 1032 (288px less scrolling); 2.5 rows above the 219 fold instead of 2.
- Leaderboards: the picker already shows `short` + icon and descriptions are not rendered. No change.
- Command / Admin: two columns at >= 640 already. Sticky 48px footers are a follow-up.
- Anomaly, Story, Wheel, Inventory, EchoForge: the per-page QA sweep covers text and overlap here. Inventory's
  "Relics" label moving into the chip row (P2.4, +34px) is a follow-up.

## Sticky action footers (P2)
- Command (phones): a 48px footer pins the tab's ready action (CLAIM LEVEL n on Overview; COLLECT / SEND AGAIN on Expeditions). No ready action, no footer. Scroll area shrinks by 48 + 8 + bottomSafe.
- Admin (narrow): 48px footer with PREVIEW (34%) and RUN (66%), the same handlers as the execute dock. Pattern: mobile bottom action bars (Material bottom app bar, iOS toolbar).
