// Tooltips: one bubble for the whole game. The system lives in UiCore/tooltip:
//   content.ts    what a tip can say (title, body, hint, stats with deltas, key hints)
//   intent.ts     when it opens and closes (hover intent, gamepad selection, long press)
//   placement.ts  where it goes (flip, shift, arrow, HUD avoidance)
//   hooks.ts      useTooltip / mergeEvents / useTooltipAvoid for targets
//   TooltipLayer  the provider and the bubble itself
// This file keeps the import path every page already uses.
export type { TooltipContent, TooltipData, TooltipKey, TooltipSide, TooltipStat } from "./UiCore/tooltip/content";
export { closeTooltip, registerTooltipAvoid, showTooltipFor, TooltipTiming } from "./UiCore/tooltip/intent";
export { mergeEvents, useTooltip, useTooltipAvoid } from "./UiCore/tooltip/hooks";
export type { TooltipEvents } from "./UiCore/tooltip/hooks";
export { TooltipProvider } from "./UiCore/tooltip/TooltipLayer";
export type { TooltipProviderProps } from "./UiCore/tooltip/TooltipLayer";
export { labelFor } from "./UiCore/tooltip/iconNames";
