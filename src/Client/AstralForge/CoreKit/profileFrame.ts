import * as ProfileStyle from "../../../Shared/AstralForge/Shared/ProfileStyle";
import { Palette } from "./theme";

// How a player's chosen profile frame draws on a ring or card stroke. Same treatment the player
// list uses: the frame's thickness, and the gradient frames run accent -> violet -> mango.
export interface FrameStroke {
	framed: boolean;
	thickness: number;
	color: Color3;
	gradient?: ColorSequence;
}

export function frameStroke(frame: ProfileStyle.FrameOption | string | undefined, accent: Color3, baseThickness = 1): FrameStroke {
	const option = typeIs(frame, "string") ? (frame !== ProfileStyle.DEFAULT_FRAME ? ProfileStyle.findFrame(frame) : undefined) : frame;
	if (option === undefined) {
		return { framed: false, thickness: baseThickness, color: accent };
	}
	return {
		framed: true,
		thickness: math.max(baseThickness, option.Thickness),
		color: option.Gradient ? new Color3(1, 1, 1) : accent,
		gradient: option.Gradient
			? new ColorSequence([
					new ColorSequenceKeypoint(0, accent),
					new ColorSequenceKeypoint(0.5, Palette.violet),
					new ColorSequenceKeypoint(1, Palette.mango),
				])
			: undefined,
	};
}
