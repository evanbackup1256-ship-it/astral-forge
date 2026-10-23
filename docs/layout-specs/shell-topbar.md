# Shell top bar on landscape phones

- Landscape phones put the 44px shell bar inside Roblox's top-bar row: a portal ScreenGui (IgnoreGuiInset, ScreenInsets None, DisplayOrder 81) placed at live `GuiService.TopbarInset` (re-read on its change signal). The bar is centred vertically, height min(44, row height), and as wide as the row minus the edge pad.
- Content starts at the core-safe top (= TopbarInset.Max.Y), so the old 44px row and its 6px pad are gone.
- It falls back to the old bar when the row is narrower than 320, the keyboard is open, or it's a portrait / desktop layout.
- `planMobileLayout({ topbarInRow })` drops the bar from chromeReserve.
- verify_mobile_matrix: touch sizes now feed the core-safe height (screen minus 44), which fixes the Forge UI 2 bug 1 where 640x286 was planned with raw 286. Landscape rows assert in-row placement (row = w - 2*side - 200 >= 320). 640x286: 242 core-safe -> budget 174 >= 160.
