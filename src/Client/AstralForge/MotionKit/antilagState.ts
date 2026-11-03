// The live antilag settings, readable from anywhere without importing the React side (the motion driver, the
// Text component, the layout guard and the avatar viewports all read this; antilag.tsx is the only writer).
// Plain fields, read each frame or each render: nothing here notifies, the readers poll what they need.
import { profileFor, TierProfile } from "../../../Shared/AstralForge/Shared/AntilagGovernor";

export interface LiveAntilag extends TierProfile {
	/** window hidden, UI hidden or backgrounded: decorative work stops entirely */
	suspended: boolean;
}

export const live: LiveAntilag = { ...profileFor(2), suspended: false };

export function setLive(profile: TierProfile, suspended: boolean) {
	// copy field by field so readers holding `live` always see the one object
	for (const [key, value] of pairs(profile as unknown as Record<string, unknown>)) {
		(live as unknown as Record<string, unknown>)[key as string] = value;
	}
	live.suspended = suspended;
}
