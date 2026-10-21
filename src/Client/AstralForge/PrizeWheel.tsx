// The prize wheel, built from UI primitives only (frames, gradients, strokes; no image face).
// useWheelController (PagesShop) owns the motion and the server result; this only draws it.
//
// The face is painted once, unrotated, inside a CanvasGroup, and the CanvasGroup turns. Rotated
// frames cannot clip, but a CanvasGroup renders its (unrotated, clipped) children to one texture
// and then rotates that texture, so a spin costs a single Rotation write per frame.
//
// Around it: a ring of bulbs that chase while it spins and blink in the prize colour when it
// lands, a speed veil that smears the face at full speed, a fixed gloss, a hub that breathes
// when a spin is ready, and a pointer that flicks off every peg.
import React from "@rbxts/react";
import * as theme from "./CoreKit/theme";
import { useClock, useFlash } from "./MotionKit/motion";
import { joinTuple } from "./lua";

const UiCore = require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as CallableFunction;
const Ui = UiCore("ui") as { Text: unknown };

const ArtKit = require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction;
const Art = ArtKit("Icon") as { Icon: unknown; rewardIconKind(this: void, reward: unknown): string };

import Geometry = require("./WheelGeometry");

const Palette = theme.Palette;
const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const BRASS = Color3.fromRGB(214, 176, 104);
const BRASS_DEEP = Color3.fromRGB(120, 92, 48);
const FACE_SCALE = 0.86;
const BULBS = 24;
// hard step: the half past the gradient midpoint is visible, so Rotation = a shows [a, a + 180)
const HALF_MASK = new NumberSequence([
	new NumberSequenceKeypoint(0, 1),
	new NumberSequenceKeypoint(0.4985, 1),
	new NumberSequenceKeypoint(0.5015, 0),
	new NumberSequenceKeypoint(1, 0),
]);

interface Layer {
	angle: number;
	segment: number;
}

interface Reward {
	Reward: unknown;
	Color?: Color3;
}

interface WheelController {
	rotation: React.Binding<number>;
	spinEnergy: React.Binding<number>;
	pointerKick: React.Binding<number>;
	impactNonce?: number;
	winner?: unknown;
	spinning: boolean;
	spin?: () => void;
}

interface PrizeWheelProps {
	controller: WheelController;
	rewards: Reward[];
	diameter: number;
	reducedMotion?: boolean;
	canSpin: boolean;
}

function wedgeColor(reward: Reward, index: number, won: boolean): Color3 {
	const base = reward.Color ?? Palette.violet;
	if (won) {
		return base;
	}
	// neighbours of the same rarity still read as separate wedges
	return theme.darken(base, index % 2 === 0 ? 0.34 : 0.5);
}

// one half of the face at rest: stacked half-disks inside an unrotated clip (see WheelGeometry)
interface FaceHalfProps {
	side: "right" | "left";
	layers: Layer[];
	colors: Record<number, Color3>;
}

function FaceHalf(props: FaceHalfProps): React.Element {
	const layers: Record<string, React.Element> = {};
	for (let slot = 0; slot < props.layers.size(); slot++) {
		const layer = props.layers[slot];
		layers[`layer${slot}`] = h("frame", {
			Size: new UDim2(2, -2, 1, 0),
			Position: props.side === "right" ? new UDim2(-1, 2, 0, 0) : new UDim2(0, 0, 0, 0),
			BackgroundColor3: props.colors[layer.segment + 1],
			BorderSizePixel: 0,
			ZIndex: slot,
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uigradient", {
			Transparency: HALF_MASK,
			Rotation: layer.angle,
		}));
	}
	return h("frame", {
		Name: props.side === "right" ? "RightHalf" : "LeftHalf",
		Size: new UDim2(0.5, 1, 1, 0),
		Position: props.side === "right" ? new UDim2(0.5, -1, 0, 0) : new UDim2(0, 0, 0, 0),
		BackgroundTransparency: 1,
		ClipsDescendants: true,
	}, layers);
}

interface BulbsProps {
	controller: WheelController;
	clock: React.Binding<number>;
	flash: React.Binding<number>;
	landed: boolean;
	winColor: Color3;
}

function Bulbs(props: BulbsProps): React.Element {
	const controller = props.controller;
	const clock = props.clock;
	const flash = props.flash;
	const bulbs: Record<string, React.Element> = {};
	for (let index = 0; index < BULBS; index++) {
		const angle = (index / BULBS) * 360;
		const radians = math.rad(angle);
		const idx = index + 1; // captured for binding closures
		bulbs[`bulb${index + 1}`] = h("frame", {
			Size: UDim2.fromScale(0.036, 0.036),
			Position: UDim2.fromScale(0.5 + math.sin(radians) * 0.465, 0.5 - math.cos(radians) * 0.465),
			AnchorPoint: new Vector2(0.5, 0.5),
			BorderSizePixel: 0,
			ZIndex: 4,
			BackgroundColor3: joinTuple(clock, flash).map(([t, flashValue]) => {
				return flashValue > 0.02 ? props.winColor.Lerp(Palette.white, flashValue * 0.4) : BRASS.Lerp(Palette.white, 0.35);
			}),
			BackgroundTransparency: joinTuple(clock, controller.rotation, controller.spinEnergy).map(([t, rotation, energy]) => {
				if (props.landed && props.winColor !== BRASS) {
					// landed: every other bulb blinks, swapping a few times a second
					return (idx + math.floor(t * 6)) % 2 === 0 ? 0 : 0.75;
				}
				if (energy > 0.02) {
					// spinning: a chase that runs with the wheel, a lit bulb every third place
					const lead = math.floor(rotation / (360 / BULBS));
					return (idx + lead) % 3 === 0 ? 0 : 0.8 - energy * 0.2;
				}
				// resting: a slow wave round the rim
				return 0.35 + (math.sin(t * 2.2 - idx * 0.55) + 1) * 0.28;
			}),
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }));
	}
	return h("frame", { Name: "Bulbs", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 4 }, bulbs);
}

function PrizeWheel(props: PrizeWheelProps): React.Element {
	const controller = props.controller;
	const rewards = props.rewards;
	const count = math.max(1, rewards.size());
	const size = Geometry.segmentSize(count);
	const diameter = props.diameter;
	const quiet = props.reducedMotion;
	const wonIndex = typeIs(controller.winner, "number") ? controller.winner : -1;
	const winningReward = wonIndex >= 0 && wonIndex < rewards.size() ? rewards[wonIndex] : undefined;
	const winColor = winningReward?.Color ?? BRASS;
	const landed = winningReward !== undefined && !controller.spinning;
	const clock = useClock(!quiet, 1, 3600, true);
	// the landing thump: the whole wheel bumps and the bulbs flare
	const flash = useFlash(controller.impactNonce ?? 0, quiet, 0.9);
	const ready = props.canSpin && !controller.spinning;

	// the face at rotation 0, painted once per prize set / winner
	const colors: Record<number, Color3> = {};
	for (let index = 0; index < rewards.size(); index++) {
		const reward = rewards[index];
		colors[index + 1] = wedgeColor(reward, index + 1, wonIndex === index);
	}
	const rest = Geometry.plan(count, 0);

	const marks: Record<string, React.Element> = {};
	const divider = math.max(1, math.floor(diameter * 0.008));
	const roomy = diameter >= 240;
	for (let index = 0; index < rewards.size(); index++) {
		const reward = rewards[index];
		const won = wonIndex === index;
		const centre = index * size;
		const start = centre - size / 2;
		marks[`edge${index + 1}`] = h("frame", {
			Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Rotation: start, ZIndex: 20,
		}, h("frame", {
			Name: "Divider", Size: new UDim2(0, divider, 0.5, 0),
			Position: UDim2.fromScale(0.5, 0.5), AnchorPoint: new Vector2(0.5, 1),
			BackgroundColor3: Palette.ink, BackgroundTransparency: 0.25, BorderSizePixel: 0, ZIndex: 20,
		}), h("frame", {
			Name: "Peg", Size: UDim2.fromScale(0.04, 0.04), Position: UDim2.fromScale(0.5, 0.025),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: BRASS, BorderSizePixel: 0, ZIndex: 22,
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uistroke", { Color: BRASS_DEEP, Thickness: 1 })));
		const iconSize = math.floor(diameter * FACE_SCALE * (roomy ? 0.1 : 0.11));
		marks[`prize${index + 1}`] = h("frame", {
			Name: `Prize${index + 1}`, Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Rotation: centre, ZIndex: 21,
		}, h("frame", {
			Name: "RewardGlyph", Size: UDim2.fromOffset(iconSize, iconSize),
			Position: UDim2.fromScale(0.5, 0.17), AnchorPoint: new Vector2(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 21,
		}, h(Art.Icon, {
			kind: Art.rewardIconKind(reward.Reward), color: won ? Palette.white : Palette.cream,
			size: iconSize, reducedMotion: true, clipSafe: true,
		})), h(Ui.Text, {
			value: tostring(index + 1),
			size: math.max(11, math.floor(diameter * 0.038)),
			color: won ? Palette.white : Palette.creamSoft,
			weight: Enum.FontWeight.Heavy, align: Enum.TextXAlignment.Center, shadow: false,
			position: UDim2.fromScale(0.42, roomy ? 0.27 : 0.29),
			sizeConstraint: UDim2.fromScale(0.16, 0.06), zIndex: 22,
		}));
	}

	return h("frame", { Name: "PrizeWheel", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1 },
		h("uiscale", {
			Scale: quiet ? 1 : flash.map((v) => 1 + math.sin(math.clamp(v, 0, 1) * math.pi) * 0.035),
		}),
		// glow behind the wheel: warm while it spins, the prize colour once it lands
		!quiet && h("frame", {
			Name: "Halo", Size: UDim2.fromScale(1.12, 1.12), Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: landed ? winColor : Palette.mango,
			BorderSizePixel: 0, ZIndex: 0,
			BackgroundTransparency: joinTuple(controller.spinEnergy, flash, clock).map(([energy, flashValue, t]) => {
				const resting = landed ? 0.8 + math.sin(t * 3) * 0.05 : ready ? 0.88 + math.sin(t * 2) * 0.04 : 0.95;
				return math.clamp(resting - energy * 0.18 - flashValue * 0.35, 0.35, 1);
			}),
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uigradient", {
			Transparency: new NumberSequence([
				new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.35, 0.2),
				new NumberSequenceKeypoint(0.65, 0.2), new NumberSequenceKeypoint(1, 1),
			]),
			Rotation: clock.map((t) => (t * 40) % 360),
		})),
		// the rim: dark ring with a brass edge whose light slides round as the wheel turns
		h("frame", {
			Name: "Rim", Size: UDim2.fromScale(1, 1), BackgroundColor3: Palette.ink, BorderSizePixel: 0, ZIndex: 1,
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: BRASS, Thickness: math.max(2, math.floor(diameter * 0.014)) },
				h("uigradient", {
					Color: new ColorSequence([
						new ColorSequenceKeypoint(0, BRASS_DEEP), new ColorSequenceKeypoint(0.5, Color3.fromRGB(255, 232, 170)),
						new ColorSequenceKeypoint(1, BRASS_DEEP),
					]),
					Rotation: quiet ? 45 : controller.rotation.map((r) => (r * 0.25 + 45) % 360),
				}))),
		!quiet && h(Bulbs, { controller, clock, flash, landed, winColor }),
		// the face: painted once, turned as one texture
		h("canvasgroup", {
			Name: "Face", Size: UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 5,
			Rotation: controller.rotation,
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(FaceHalf, { side: "right", layers: rest.right, colors }),
			h(FaceHalf, { side: "left", layers: rest.left, colors }),
			h("frame", { Name: "Rotor", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 20 }, marks),
			h("frame", {
				// inner bevel ring for depth
				Name: "Bevel", Size: UDim2.fromScale(0.56, 0.56), Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5), BackgroundTransparency: 1, ZIndex: 23,
			}, h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uistroke", { Color: Palette.ink, Thickness: 1, Transparency: 0.5 }))),
		// at speed the wedges smear: a veil that thickens with spin energy
		!quiet && h("frame", {
			Name: "SpeedVeil", Size: UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: Palette.ink, BorderSizePixel: 0, ZIndex: 6,
			BackgroundTransparency: controller.spinEnergy.map((energy) => 1 - math.clamp(energy, 0, 1) * 0.45),
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uigradient", {
			Transparency: new NumberSequence([
				new NumberSequenceKeypoint(0, 0.2), new NumberSequenceKeypoint(0.25, 0.85), new NumberSequenceKeypoint(0.5, 0.2),
				new NumberSequenceKeypoint(0.75, 0.85), new NumberSequenceKeypoint(1, 0.2),
			]),
			Rotation: controller.rotation.map((r) => (r * 1.5) % 360),
		})),
		// a fixed sheen across the top of the face, so it reads as glass over the wedges
		h("frame", {
			Name: "Gloss", Size: UDim2.fromScale(FACE_SCALE, FACE_SCALE), Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: Palette.white, BackgroundTransparency: 0.86,
			BorderSizePixel: 0, ZIndex: 7,
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uigradient", {
			Rotation: 90,
			Transparency: new NumberSequence([
				new NumberSequenceKeypoint(0, 0.1), new NumberSequenceKeypoint(0.45, 1), new NumberSequenceKeypoint(1, 1),
			]),
		})),
		// the hub: press to spin; breathes when a spin is ready, its ring turns against the wheel
		h("textbutton", {
			Name: "Hub", Size: UDim2.fromScale(0.24, 0.24), Position: UDim2.fromScale(0.5, 0.5),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: Palette.panelRaised, BorderSizePixel: 0,
			AutoButtonColor: false, Text: "", Active: ready, ZIndex: 10, Selectable: false,
			Event: {
				Activated: () => {
					if (props.canSpin && !controller.spinning && controller.spin !== undefined) {
						controller.spin();
					}
				},
			},
		}, h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uigradient", { Color: new ColorSequence(Palette.panelRaised.Lerp(Palette.white, 0.08), Palette.panel), Rotation: 90 }),
			h("uistroke", { Color: BRASS, Thickness: math.max(2, math.floor(diameter * 0.012)) }),
			h("uiscale", {
				Scale: quiet ? 1 : joinTuple(controller.spinEnergy, clock).map(([energy, t]) => {
					const breathe = ready ? math.sin(t * 3.4) * 0.04 : 0;
					return 1 - energy * 0.04 + breathe;
				}),
			}),
			h("frame", {
				Size: UDim2.fromScale(0.78, 0.78), Position: UDim2.fromScale(0.5, 0.5), AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1, ZIndex: 10,
				Rotation: quiet ? 0 : controller.rotation.map((r) => -r * 0.5),
			}, h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uistroke", { Color: BRASS, Thickness: 1.5, Transparency: 0.3 }, h("uigradient", {
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(0.5, 0.85), new NumberSequenceKeypoint(1, 0),
					]),
				}))),
			h(Ui.Text, {
				value: ready ? "Spin" : "", size: math.max(12, math.floor(diameter * 0.055)), color: BRASS,
				weight: Enum.FontWeight.Heavy, align: Enum.TextXAlignment.Center,
				sizeConstraint: UDim2.fromScale(1, 1), zIndex: 11, shadow: false,
			})),
		// the pointer: flicks back off each peg and springs home
		h("frame", {
			Name: "Pointer", Size: UDim2.fromScale(0.09, 0.13), Position: UDim2.fromScale(0.5, -0.045),
			AnchorPoint: new Vector2(0.5, 0), BackgroundTransparency: 1, ZIndex: 12,
			Rotation: quiet ? 0 : controller.pointerKick.map((kick) => -kick * 16),
		}, h("frame", {
			// a square with a diagonal hard mask, turned 45°: a downward triangle tip
			Name: "Tip", Size: UDim2.fromScale(0.72, 0.51), Position: UDim2.fromScale(0.5, 0.64),
			AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: Palette.cream, BorderSizePixel: 0,
			Rotation: 45, ZIndex: 12,
		}, h("uiaspectratioconstraint", { AspectRatio: 1 }),
			h("uigradient", { Transparency: HALF_MASK, Rotation: 45 })),
			h("frame", {
				Name: "Cap", Size: UDim2.fromScale(1, 0.7), Position: UDim2.fromScale(0.5, 0),
				AnchorPoint: new Vector2(0.5, 0), BackgroundColor3: Palette.cream, BorderSizePixel: 0, ZIndex: 13,
			}, h("uiaspectratioconstraint", { AspectRatio: 1 }), h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uistroke", { Color: BRASS, Thickness: 2 }),
				h("frame", {
					Size: UDim2.fromScale(0.34, 0.34), Position: UDim2.fromScale(0.5, 0.5), AnchorPoint: new Vector2(0.5, 0.5),
					BorderSizePixel: 0, ZIndex: 14,
					BackgroundColor3: landed ? winColor : BRASS,
				}, h("uicorner", { CornerRadius: new UDim(1, 0) })))));
}

export = PrizeWheel;
