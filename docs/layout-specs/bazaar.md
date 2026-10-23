# Bazaar (pages/PagesBazaar/BazaarView.tsx)
Research: /workspace/research/forge-ui-4.md "Bazaar" P1/P3 (calm inspect pane, smaller merchant on phones;
https://create.roblox.com/docs/ui/size-modifiers, PS99 booths https://pet-simulator.fandom.com/wiki/Booths_(Pet_Simulator_99)).

Focal: the shelf (primary); inspect + merchant are the secondary column (shelf-split, side on right).
- Market header: one row wide = 72 (title | countdown | Refresh 112x40), narrow (<560) = 116 (title row, then countdown + Refresh). Rules paragraph removed.
- Merchant card 148 (was 212): portrait 64x72, name/title/standing to its right at x=78 (y 0/26/48), meter y=82, request status y=94 h18. Quote and long standing sentence removed.
- Empty states: "Nothing saved" / "No matches".

| viewport | header | merchant | saved above fold |
|---|---|---|---|
| 1920x1080 | 72 | 148 | 104 |
| 1366x768 | 72 | 148 | 104 |
| 844x390 (narrow) | 116 | 148 | 116 of the 219 fold |
Cards stay 346 tall, columns floor((shelfW+12)/300) clamped 1..3; inner math unchanged.
