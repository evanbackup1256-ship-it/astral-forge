# Boosts: "Reactor bay"

- **Focal zone:** the reactor hero (the active boost countdown, or the idle bay's best pick), full width at the top.
- **Zones, in reading order:**
  1. Hero: reactor (182 px wide / 260 px portrait stack)
  2. Hero strip: 4 stat tiles in one row (60 px)
  3. Primary: the browse bar, full width
  4. Primary: the card wall. It has 4 columns at 1500 px and wider, 3 columns at 1000 px and wider, 2 columns on phone landscape, and 1 in portrait. Cards are 196 px tall with 10 px gutters.
- **What changed:** the old rail (reactor, stats and filters at 34% width) ran beside a card wall several screens tall. Under the filters it stretched into an empty column. Now each zone uses the full width, and the card wall gains a 4th column on 1920.
- **Verified (layout-verify.py):**
  - 1920: total height 1010, the cards start at y=392, 4 columns.
  - 1366: 3 columns.
  - 844 (width 730, ~219 px fold): 2 columns. The reactor (182) sits above the fold, the stat strip straddles it, and the cards follow.
  - No overlap, overflow, ragged edges or uneven gutters.
- **Kept:** all cards, filters and the reactor, plus their animations. The zones rise in order using the shared 0.055 s stagger.
