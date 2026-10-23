# Research: "Tech tree lane"

- **Focal zone:** the hero band (overall progress and the Buy-all action), full width.
- **Zones:**
  1. Hero band: 128 px, one row
  2. Controls toolbar: 96 px, one row
  3. Primary: the chain, a full-width vertical tree of nodes (116 px plus a 22 px connector), virtualised
- **Reading order:** top to bottom, following the tree. A two-column chain was rejected because the connectors run vertically, so a row-major grid would misrepresent the order.
- **What changed:** the old 30% rail put the hero and controls beside a chain about 3,300 px tall. The controls panel stretched into a tall empty block. On 844x390 the stacked hero and controls (372 px) used to hide the chain entirely. Phones in landscape now keep the one-row hero and toolbar (234 px), so the first chain node shows on the first screen.
- **Verified:**
  - 1920 and 1366: the chain starts at y=260.
  - 844 (width 730): the chain starts at y=244. That is 25 px below the ~219 px core-safe fold, so the hero and Buy-all show and the first node peeks in after a short scroll. The old stacked layout put the chain at y=392.
  - Follow-up: move the app top bar into GuiService.TopbarInset on landscape phones (pass 2, P2.4). That gains 44 px and puts the first node above the fold.
  - No overlap or ragged edges.
