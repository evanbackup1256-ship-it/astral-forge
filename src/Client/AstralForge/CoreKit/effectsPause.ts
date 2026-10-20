import React from "@rbxts/react";

// True while the page shell can't be seen (UI hidden, or a full-screen reveal covering it).
// Looping decoration under it (shimmer, glow strokes, icon light layers, stars, aurora) holds its
// current frame instead of animating for nobody. Overlays mounted outside the shell are unaffected.
export const UiEffectsPausedContext = React.createContext(false);
