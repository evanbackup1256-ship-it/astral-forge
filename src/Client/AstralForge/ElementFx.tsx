// Purpose: an animated elemental companion (any of the 57 in Shared/ElementSprites) as a React
// element, driven by the shared visibility-budgeted companion clock. Each companion's elemental
// light is lit into its own frames, so this is one image layer with nothing played behind it.
// Reduced motion shows a still frame.
import React from "@rbxts/react";
import Playback = require("./CompanionPlayback");
import { useFlash } from "./MotionKit/motion";
import { named } from "./lua";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface Sheet {
	Image: string;
}
interface Animation {
	Columns: number;
	SpriteCount: number;
	SpriteSize: Vector2;
	Framerate: number;
}
interface ElementSpritesModule {
	FRAME: number;
	FRAMERATE: number;
	sheet(this: void, element?: string): Sheet | undefined;
	animation(this: void, element: string, framerate?: number): Animation;
}

const astral = ReplicatedStorage.WaitForChild("AstralForge");
const ElementSprites = require(astral.WaitForChild("Shared").WaitForChild("ElementSprites") as ModuleScript) as ElementSpritesModule;

interface Reaction {
	duration: number;
	scale: (t: number) => number;
	rotation: (t: number) => number;
}

// Reactions: a short spring on the companion itself. `t` runs 1 -> 0 as the reaction settles.
const REACTIONS: Record<string, Reaction | undefined> = {
	select: { duration: 0.45, scale: (t) => 1 + 0.14 * t, rotation: () => 0 },
	reveal: { duration: 0.9, scale: (t) => 1 - 0.4 * t, rotation: (t) => -14 * t },
	equip: { duration: 0.6, scale: (t) => 1 + 0.2 * t, rotation: (t) => 7 * t },
	mastery: { duration: 1.2, scale: (t) => 1 + 0.12 * t, rotation: (t) => 360 * t },
};

// Plays `reaction` each time `reactionKey` changes after mount (never on first render).
function useReaction(reactionKey: unknown, reducedMotion: boolean) {
	const [nonce, setNonce] = React.useState(0);
	const seen = React.useRef(reactionKey);
	React.useEffect(() => {
		if (seen.current !== reactionKey) {
			seen.current = reactionKey;
			if (!reducedMotion) {
				setNonce((value) => value + 1);
			}
		}
	}, [reactionKey, reducedMotion]);
	return nonce;
}

interface ElementFxProps {
	element: string;
	size?: UDim2;
	position?: UDim2;
	anchorPoint?: Vector2;
	transparency?: number;
	tint?: Color3;
	zIndex?: number;
	framerate?: number;
	reducedMotion?: boolean;
	still?: boolean;
	reaction?: string;
	reactionKey?: unknown;
	scaleType?: Enum.ScaleType;
}

// props: element, size, position, anchorPoint, transparency, tint, zIndex, framerate, reducedMotion, still,
// reaction ("select" | "reveal" | "equip" | "mastery") with reactionKey (a change plays it),
// scaleType (Fit by default; Stretch lets a caller squash the sheet, e.g. a sigil lying on the ground)
function ElementFx(props: ElementFxProps) {
	const ref = React.useRef<ImageLabel>();
	const trackRef = React.useRef<ReturnType<typeof Playback.register>>();
	const sheet = ElementSprites.sheet(props.element);
	const animate = sheet !== undefined && !props.reducedMotion && !props.still;
	const reaction = REACTIONS[props.reaction ?? ""];
	const nonce = useReaction(props.reactionKey, props.reducedMotion === true);
	const pulse = useFlash(nonce, props.reducedMotion === true, reaction ? reaction.duration : 0.45);
	React.useEffect(() => {
		const label = ref.current;
		if (label === undefined || !animate) {
			return undefined;
		}
		const animation = ElementSprites.animation(props.element, props.framerate);
		const track = Playback.register(label, animation.Columns, animation.SpriteCount, animation.SpriteSize, animation.Framerate);
		trackRef.current = track;
		return () => {
			trackRef.current = undefined;
			track.release();
		};
	}, [props.element, animate]);
	// hover and focus speed the loop up without restarting it
	React.useEffect(() => {
		const track = trackRef.current;
		if (track !== undefined) {
			track.setRate(props.framerate ?? ElementSprites.FRAMERATE);
		}
	}, [props.framerate]);
	if (sheet === undefined) {
		return undefined;
	}
	const frame = ElementSprites.FRAME;
	const reacting = reaction !== undefined && !props.reducedMotion;
	return (
		<imagelabel
			ref={ref}
			{...named("ElementFx")}
			Size={props.size ?? UDim2.fromScale(1, 1)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={props.anchorPoint ?? new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Image={sheet.Image}
			ImageRectSize={new Vector2(frame, frame)}
			// the first loop frame: the reduced-motion still, and what shows before playback starts
			ImageRectOffset={new Vector2(0, 0)}
			ImageColor3={props.tint ?? new Color3(1, 1, 1)}
			ImageTransparency={props.transparency ?? 0}
			ScaleType={props.scaleType ?? Enum.ScaleType.Fit}
			ZIndex={props.zIndex}
			Rotation={reacting ? pulse.map(reaction!.rotation) : 0}
		>
			{reacting ? <uiscale Scale={pulse.map(reaction!.scale)} /> : undefined}
		</imagelabel>
	);
}

export = {
	ElementFx,
	sheet: ElementSprites.sheet,
};
