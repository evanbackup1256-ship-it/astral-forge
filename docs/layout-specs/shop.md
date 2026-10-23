# Shop (pages/PagesShop.tsx)
Research: /workspace/research/forge-ui-4.md "Shop" P1 (slim header strip, spacer pattern:
https://create.roblox.com/docs/ui/list-flex-layouts, https://devforum.roblox.com/t/flex-features-for-uilistlayout-client-release/3096190).

Composition per section (Daily, Crates, Skins, Codex, Artifacts): header strip (focal title + wallet) -> section tabs -> primary grid.
- Header strip: no body copy. Desktop 64px = 14 pad + 36 icon/title row + 14 pad; title width = W - 48 - 252, wallet 240 right-aligned.
  Stacked 102px = 14 + 36 + 8 + 30 wallet row + 14.
- Artifacts shows the held count in the title ("Artifact Vault 3/12") instead of a sentence.

| viewport | content W | header | title width | wallet |
|---|---|---|---|---|
| 1920x1080 | 1601 | 64 | 1301 | 240 right |
| 1366x768 | 1047 | 64 | 747 | 240 right |
| 844x390 (stack) | 719 | 102 | 671 | row 2, left |
Savings vs old hero (92/124): 28px desktop, 22px phone above the fold (219px budget).
