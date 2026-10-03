# Stories (UI Labs)

Every page, the shared controls, the crate skins, the prismatic aura and the crate reveal have a
[UI Labs](https://ui-labs.luau.page/) story. They sync to `ServerStorage.AstralForgeStories`, so they
never reach players and nothing in the game runs them.

Open them with the UI Labs plugin in Studio (install it from the Creator Store), pick
**Astral Forge** in the storybook list.

## Controls on every story

| Control | What it does |
| --- | --- |
| Device | Lays the page out at a real screen size (desktop, laptop, tablet, phones in both orientations) and scales it to fit the preview. Phone sizes get the mobile layout and safe-area insets. |
| ReducedMotion | Passes Reduced Motion to the component. |
| Save | New player, mid game or late game state (when no snapshot is captured). |
| Dispatch | Whether actions the page sends succeed or fail. Every dispatch is printed to the output. |

## State

`StoryKit.state()` uses `StorySnapshot` when it exists: a real snapshot captured from a playtest.
Otherwise it builds one from `StoryFixture`, which runs the server's own pure state math
(`ProgressionGate`, `WheelMath`, `Economy`) on a template save. Pages that read deep server state the
fixture doesn't build show the error in the story instead of a blank canvas; capture a snapshot for
those.

### Capturing a snapshot

Start a playtest, then in the **server** command bar:

```lua
local kit = require(game.ServerStorage.AstralForgeStories.StoryKit)
print("return " .. kit.serialize(shared.AstralForgeStudio.snapshot()))
```

(`shared.AstralForgeStudio` only exists in Studio.)

Save the printed table as `src/Stories/StorySnapshot.luau` (`return <table>`).
