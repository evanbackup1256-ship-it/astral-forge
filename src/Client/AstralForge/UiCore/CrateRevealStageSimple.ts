import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette } from "../CoreKit/theme";
import { CrateModel } from "./crateModel";
import { isAscended, PrismAura } from "./prismFx";
import { Button, Text } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold);

function smooth(x: number) {
	x = math.clamp(x, 0, 1);
	return x * x * (3 - 2 * x);
}

interface StageCard {
	key: string;
	accent?: Color3;
	winner?: boolean;
	rarity?: string;
}

interface OrbitNodeProps {
	card: StageCard;
	index: number;
	step: number;
	stride: number;
	reelOffset: React.Binding<number>;
	nodeSize: number;
	cx: number;
	cy: number;
	rx: number;
	ry: number;
	landed: boolean;
	reducedMotion?: boolean;
}

// One relic sigil riding the astrolabe ring. Angle comes from the shared reel offset so
// skip / land / batch logic in the overlay stays untouched; depth fakes perspective.
function OrbitNode(props: OrbitNodeProps) {
	const card = props.card;
	const accent = card.accent ?? Palette.cyan;
	const landedWinner = card.winner && props.landed;
	const geometry = props.reelOffset.map((offset) => {
		const theta = (props.index - 1 - offset / props.stride) * props.step;
		const depth = (math.cos(theta) + 1) / 2;
		return { theta, depth };
	});
	const base = props.nodeSize;
	return h(
		"frame",
		{
			Size: geometry.map((g) => {
				const s = math.round(base * (0.42 + 0.58 * g.depth) * (landedWinner ? 1.1 : 1));
				return UDim2.fromOffset(s, s);
			}),
			Position: geometry.map((g) =>
				UDim2.fromOffset(props.cx + props.rx * math.sin(g.theta), props.cy + props.ry * math.cos(g.theta)),
			),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: geometry.map((g) => 433 + math.round(g.depth * 6)),
		},
		h(
			"frame",
			{
				Size: UDim2.fromScale(0.66, 0.66),
				Position: UDim2.fromScale(0.5, 0.42),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: 45,
				BackgroundColor3: Palette.panelRaised,
				BackgroundTransparency: geometry.map((g) => 0.15 + (1 - g.depth) * 0.6),
				BorderSizePixel: 0,
				ZIndex: geometry.map((g) => 433 + math.round(g.depth * 6)),
			},
			h("uicorner", { CornerRadius: new UDim(0.18, 0) }),
			h("uistroke", {
				Color: accent,
				Thickness: landedWinner ? 2 : 1,
				Transparency: geometry.map((g) => (landedWinner ? 0 : 0.2 + (1 - g.depth) * 0.65)),
			}),
			h(
				"frame",
				{
					Size: UDim2.fromScale(0.42, 0.42),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: accent,
					BackgroundTransparency: geometry.map((g) => (1 - g.depth) * 0.7),
					BorderSizePixel: 0,
					ZIndex: geometry.map((g) => 434 + math.round(g.depth * 6)),
				},
				h("uicorner", { CornerRadius: new UDim(0.2, 0) }),
			),
		),
		isAscended(card.rarity) &&
			landedWinner &&
			h(PrismAura, {
				rarity: card.rarity,
				intensity: 1,
				rays: false,
				sparks: !props.reducedMotion,
				corner: 999,
				zIndex: 440,
			}),
		h("textlabel", {
			Size: new UDim2(2.4, 0, 0, 12),
			Position: new UDim2(0.5, 0, 1, 2),
			AnchorPoint: new Vector2(0.5, 0),
			BackgroundTransparency: 1,
			Text: string.upper(card.rarity ?? "RELIC"),
			TextColor3: accent,
			TextSize: 9,
			FontFace: FONT_BOLD,
			TextTransparency: geometry.map((g) => 1 - smooth((g.depth - 0.78) / 0.2)),
			ZIndex: 441,
		}),
	);
}

export interface CrateRevealStageProps {
	phase: string;
	viewportWidth: number;
	viewportHeight: number;
	sideSafe?: number;
	topInset?: number;
	bottomSafe?: number;
	cardHeight: number;
	winnerRank?: number;
	winnerAccent: Color3;
	climbColor?: Color3;
	sessionAccent: Color3;
	winnerName: string;
	resultDetail: string;
	winnerRarity: string;
	rollIndex: number;
	rollCount: number;
	spinProgress: React.Binding<number>;
	cards: StageCard[];
	stride: number;
	reelOffset: React.Binding<number>;
	reducedMotion?: boolean;
	tickEnergy: React.Binding<number>;
	landPop: React.Binding<number>;
	landFlash: React.Binding<number>;
	climbFlash: React.Binding<number>;
	climbStep?: number;
	ladderColors: Color3[];
	chargePulse: React.Binding<number>;
	sealFlash: React.Binding<number>;
	skin?: unknown;
	visualShow: React.Binding<number>;
	onQuickLand: () => void;
	onClaim: () => void;
	crateName?: string;
	resultTag: string;
	claimSlide: React.Binding<number>;
	claimText: string;
	[key: string]: unknown;
}

export function CrateRevealStage(props: CrateRevealStageProps) {
	const panelRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const panel = panelRef.current;
		if (panel === undefined) {
			return undefined;
		}
		if (props.phase !== "spin" && props.phase !== "done") {
			GamepadNavigationService.ClearSelection();
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (panel.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(panel);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [props.phase]);
	const landed = props.phase === "land" || props.phase === "done" || props.phase === "exit";
	const canClaim = props.phase === "done";
	const safeWidth = math.max(1, props.viewportWidth - (props.sideSafe ?? 0) * 2 - 24);
	const safeHeight = math.max(1, props.viewportHeight - (props.topInset ?? 0) - (props.bottomSafe ?? 0) - 24);
	const panelWidth = math.min(760, safeWidth);
	const panelHeight = math.min(430, safeHeight);
	const compact = panelHeight < 355;
	const padding = panelWidth < 420 ? 14 : 20;
	const headerHeight = compact ? 52 : 62;
	const resultHeight = compact ? 62 : 76;
	const actionHeight = 50;
	const gap = compact ? 7 : 12;
	const trackHeight = math.max(1, panelHeight - padding * 2 - headerHeight - resultHeight - actionHeight - gap * 3);
	const trackWidth = math.max(1, panelWidth - padding * 2);
	const safeCenterY = ((props.topInset ?? 0) + props.viewportHeight - (props.bottomSafe ?? 0)) / 2;
	const climbing = props.phase === "climb";
	const ladderTarget = props.winnerRank ?? 1;
	const showLadder = (climbing || landed) && ladderTarget >= 4;
	const accent = landed ? props.winnerAccent : climbing ? props.climbColor ?? props.sessionAccent : props.sessionAccent;
	const resultTitle = landed
		? props.winnerName
		: climbing
			? "Resonance rising"
			: props.phase === "spin"
				? "Attuning the astrolabe"
				: props.phase === "seal"
					? "Seal breaking"
					: "Unsealing crate";
	const resultSubtitle = landed
		? props.resultDetail
		: climbing
			? "Something rare is coming. Tap to skip."
			: props.phase === "spin"
				? "Tap anywhere to lock the ring"
				: "The forge is waking up";
	let status = props.phase === "spin" ? "ATTUNING" : climbing ? "RESONATING" : landed ? "RELIC BOUND" : "UNSEALING";
	const actionY = panelHeight - padding - actionHeight;
	const resultY = actionY - gap - resultHeight;
	const trackY = padding + headerHeight + gap;
	const ascended = landed && isAscended(props.winnerRarity);
	if (ascended) {
		status = props.winnerRarity === "Astral" ? "ASTRAL RELIC" : "CELESTIAL RELIC";
	}
	const crateSize = headerHeight - 4;
	const nameX = padding + crateSize + 10;
	const introOpen = props.phase === "spin" || landed;
	const intro =
		props.rollIndex === 0 &&
		(props.phase === "enter" || props.phase === "charge" || props.phase === "seal" || props.phase === "spin");
	const introFade = props.spinProgress.map((value) => (props.phase === "spin" ? math.clamp((value - 0.05) / 0.09, 0, 1) : 0));

	const nodeSize = math.clamp(math.round(math.min(trackHeight * 0.3, trackWidth * 0.11)), 26, 62);
	const ringCx = trackWidth / 2;
	const ringCy = trackHeight / 2 - nodeSize * 0.12;
	const ringRx = math.max(nodeSize, trackWidth / 2 - nodeSize * 0.75);
	const ringRy = math.max(8, trackHeight / 2 - nodeSize * 0.62);
	const step = (2 * math.pi) / math.max(1, props.cards.size());
	const nodes: React.Element[] = [];
	for (const [i, card] of ipairs(props.cards)) {
		nodes.push(
			h(OrbitNode, {
				key: card.key,
				card: card,
				index: i,
				step: step,
				stride: props.stride,
				reelOffset: props.reelOffset,
				nodeSize: nodeSize,
				cx: ringCx,
				cy: ringCy,
				rx: ringRx,
				ry: ringRy,
				landed: landed,
				reducedMotion: props.reducedMotion,
			}),
		);
	}
	const coreSize = math.round(math.min(ringRy * 1.5, ringRx * 0.62, trackHeight * 0.62));
	const spinAngle = props.reducedMotion ? undefined : props.spinProgress.map((value) => value * 540);

	const orbitLine = (scale: number, transparency: number, zIndex: number) =>
		h(
			"frame",
			{
				Size: UDim2.fromOffset(ringRx * 2 * scale, ringRy * 2 * scale),
				Position: UDim2.fromOffset(ringCx, ringCy),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: zIndex,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: accent, Thickness: 1, Transparency: transparency }),
		);

	const ladder = () => {
		const pips: Record<string, unknown> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				HorizontalAlignment: Enum.HorizontalAlignment.Center,
				VerticalAlignment: Enum.VerticalAlignment.Center,
				Padding: new UDim(0, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		const litTo = landed ? ladderTarget : props.climbStep ?? 0;
		for (let index = 1; index <= ladderTarget; index++) {
			const lit = index <= litTo;
			const head = index === litTo;
			pips[`pip${index}`] = h(
				"frame",
				{
					LayoutOrder: index,
					Size: UDim2.fromOffset(head ? 10 : 8, head ? 10 : 8),
					Rotation: 45,
					BackgroundColor3: lit ? props.ladderColors[index - 1] : Palette.line,
					BackgroundTransparency: lit ? 0 : 0.4,
					BorderSizePixel: 0,
					ZIndex: 446,
				},
				h("uicorner", { CornerRadius: new UDim(0.2, 0) }),
			);
		}
		return pips;
	};

	const sealBurst = () => {
		// the seal fractures outward: uneven shards on a golden-angle spread so no two runs read as a clean starburst
		const shards: Record<string, unknown> = {};
		const reach = trackHeight * 0.95;
		for (let index = 1; index <= 11; index++) {
			const angle = (index * 137.5 + 9) % 360;
			const length = reach * (0.55 + ((index * 0.618) % 1) * 0.45);
			shards[`shard${index}`] = h(
				"frame",
				{
					Size: props.sealFlash.map((value) => {
						const t = 1 - math.clamp(value, 0, 1);
						return UDim2.fromOffset(math.round(length * (0.15 + 0.85 * smooth(t))), index % 3 === 0 ? 3 : 2);
					}),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0, 0.5),
					Rotation: angle,
					BackgroundColor3: index % 4 === 0 ? new Color3(1, 1, 1) : props.sessionAccent,
					BackgroundTransparency: props.sealFlash.map((value) => 1 - math.clamp(value, 0, 1) * 0.95),
					BorderSizePixel: 0,
					ZIndex: 448,
				},
				h("uigradient", {
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 1),
						new NumberSequenceKeypoint(0.15, 0),
						new NumberSequenceKeypoint(1, 1),
					]),
				}),
			);
		}
		shards.ring = h(
			"frame",
			{
				Size: props.sealFlash.map((value) => {
					const s = math.round(trackHeight * (0.4 + (1 - math.clamp(value, 0, 1)) * 1.2));
					return UDim2.fromOffset(s, s);
				}),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 448,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: new Color3(1, 1, 1),
				Thickness: 2,
				Transparency: props.sealFlash.map((value) => 1 - math.clamp(value, 0, 1) * 0.8),
			}),
		);
		return h("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 448 }, shards);
	};

	const track = h(
		"frame",
		{
			Name: "Astrolabe",
			Size: UDim2.fromOffset(trackWidth, trackHeight),
			Position: UDim2.fromOffset(padding, trackY),
			BackgroundColor3: Palette.void,
			BorderSizePixel: 0,
			ClipsDescendants: true,
			ZIndex: 430,
		},
		h("uicorner", { CornerRadius: new UDim(0, 12) }),
		h("uigradient", {
			Color: new ColorSequence(Palette.panel, Palette.void),
			Transparency: new NumberSequence(0.2, 0),
			Rotation: 90,
		}),
		orbitLine(1, 0.55, 431),
		orbitLine(0.72, 0.82, 431),
		orbitLine(1.18, 0.9, 431),
		// front marker: the sigil that settles under it is the drop
		h("frame", {
			Size: props.tickEnergy.map((value) => UDim2.fromOffset(9 + math.round(value * 3), 9 + math.round(value * 3))),
			Position: UDim2.fromOffset(ringCx, math.min(trackHeight - 8, ringCy + ringRy + nodeSize * 0.62)),
			AnchorPoint: new Vector2(0.5, 0.5),
			Rotation: 45,
			BackgroundColor3: accent,
			BorderSizePixel: 0,
			ZIndex: 442,
		}),
		h(
			"frame",
			{
				Name: "Core",
				Size: UDim2.fromOffset(coreSize, coreSize),
				Position: UDim2.fromOffset(ringCx, ringCy),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: 0.1,
				BorderSizePixel: 0,
				ZIndex: 436,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(
				"uistroke",
				{ Color: accent, Thickness: 2, Transparency: 0.1 },
				h("uigradient", {
					Rotation: spinAngle ?? 0,
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 0),
						new NumberSequenceKeypoint(0.35, 0.85),
						new NumberSequenceKeypoint(0.65, 1),
						new NumberSequenceKeypoint(1, 0.2),
					]),
				}),
			),
			h(
				"frame",
				{
					Size: UDim2.fromScale(0.74, 0.74),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundTransparency: 1,
					Rotation: spinAngle ? props.spinProgress.map((value) => -value * 300) : 0,
					ZIndex: 437,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h(
					"uistroke",
					{ Color: accent, Thickness: 1, Transparency: 0.45 },
					h("uigradient", {
						Transparency: new NumberSequence([
							new NumberSequenceKeypoint(0, 0),
							new NumberSequenceKeypoint(0.5, 1),
							new NumberSequenceKeypoint(1, 0),
						]),
					}),
				),
			),
			// crystallised drop
			h(
				"frame",
				{
					Size: props.landPop.map((value) => {
						const s = landed ? math.round(coreSize * 0.42 * math.clamp(value, 0, 1.15)) : 0;
						return UDim2.fromOffset(s, s);
					}),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: 45,
					BackgroundColor3: props.winnerAccent,
					BorderSizePixel: 0,
					Visible: landed,
					ZIndex: 438,
				},
				h("uicorner", { CornerRadius: new UDim(0.18, 0) }),
				h("uigradient", {
					Color: new ColorSequence(new Color3(1, 1, 1), props.winnerAccent),
					Transparency: new NumberSequence(0.15, 0),
					Rotation: -45,
				}),
			),
			// shockwave when the drop locks in
			landed &&
				h(
					"frame",
					{
						Size: props.landFlash.map((value) => {
							const s = math.round(coreSize * (1 + (1 - math.clamp(value, 0, 1)) * 1.6));
							return UDim2.fromOffset(s, s);
						}),
						Position: UDim2.fromScale(0.5, 0.5),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundTransparency: 1,
						ZIndex: 438,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					h("uistroke", {
						Color: props.winnerAccent,
						Thickness: 2,
						Transparency: props.landFlash.map((value) => 1 - math.clamp(value, 0, 1) * 0.85),
					}),
				),
		),
		climbing &&
			h(
				"frame",
				{
					Name: "Resonance",
					Size: props.climbFlash.map((value) => {
						const reach = math.clamp((props.climbStep ?? 0) / math.max(1, ladderTarget), 0, 1);
						const s = math.round(coreSize * (0.5 + reach * 0.5 + math.clamp(value, 0, 1) * 0.16));
						return UDim2.fromOffset(s, s);
					}),
					Position: UDim2.fromOffset(ringCx, ringCy),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: accent,
					BackgroundTransparency: props.climbFlash.map((value) => 0.55 - math.clamp(value, 0, 1) * 0.3),
					BorderSizePixel: 0,
					ZIndex: 437,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uigradient", {
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 0),
						new NumberSequenceKeypoint(0.7, 0.5),
						new NumberSequenceKeypoint(1, 1),
					]),
				}),
			),
		showLadder &&
			h(
				"frame",
				{
					Name: "RarityLadder",
					Size: UDim2.fromOffset(ladderTarget * 16, 12),
					Position: new UDim2(0.5, 0, 0, 8),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundTransparency: 1,
					ZIndex: 445,
				},
				ladder(),
			),
		h("frame", { Size: UDim2.fromOffset(trackWidth, trackHeight), BackgroundTransparency: 1, ZIndex: 432 }, ...nodes),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 2),
				Position: new UDim2(0, 0, 1, -2),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
				ZIndex: 443,
			},
			h("frame", {
				Size: props.spinProgress.map((value) => new UDim2(math.clamp(value, 0, 1), 0, 1, 0)),
				BackgroundColor3: accent,
				BorderSizePixel: 0,
				ZIndex: 444,
			}),
		),
		intro &&
			h(
				"frame",
				{
					Name: "CrateIntro",
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: Palette.void,
					BackgroundTransparency: introFade,
					BorderSizePixel: 0,
					ZIndex: 444,
				},
				h(
					"frame",
					{
						Size: UDim2.fromOffset(trackHeight * 0.9, trackHeight * 0.9),
						Position: UDim2.fromScale(0.5, 0.5),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundColor3: props.sessionAccent,
						BackgroundTransparency: React.joinBindings([introFade, props.chargePulse]).map(
							(values) => 1 - (1 - values[0]) * (0.1 + values[1] * 0.12),
						),
						BorderSizePixel: 0,
						ZIndex: 445,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
				h(
					"canvasgroup",
					{ Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, GroupTransparency: introFade, ZIndex: 446 },
					h(CrateModel, {
						skin: props.skin,
						size: UDim2.fromOffset(trackHeight * 1.15, trackHeight * 1.15),
						position: UDim2.fromScale(0.5, 0.5),
						anchorPoint: new Vector2(0.5, 0.5),
						open: introOpen ? 1 : props.phase === "seal" ? 0.55 : 0,
						shake: props.phase === "charge" ? 1 : props.phase === "seal" ? 0.5 : props.phase === "enter" ? 0.3 : 0,
						yaw: -0.35,
						zoom: 0.92,
						zIndex: 447,
					}),
				),
				(!props.reducedMotion && sealBurst()) || undefined,
			),
	);

	return h(
		"frame",
		{ Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Active: true, ZIndex: 400 },
		h("imagebutton", {
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: props.visualShow.map((value) => 1 - math.clamp(value, 0, 1) * 0.97),
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Selectable: false,
			Active: props.phase === "spin" || props.phase === "climb",
			ZIndex: 401,
			Event: {
				Activated: () => {
					if (props.phase === "spin" || props.phase === "climb") {
						props.onQuickLand();
					}
				},
			},
		}),
		h(
			"frame",
			{
				ref: panelRef,
				Size: UDim2.fromOffset(panelWidth, panelHeight),
				Position: props.visualShow.map((value) => new UDim2(0.5, 0, 0, safeCenterY + math.round((1 - value) * 16))),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.panel,
				BorderSizePixel: 0,
				Visible: props.visualShow.map((value) => value > 0.015),
				ZIndex: 410,
			},
			h("uicorner", { CornerRadius: new UDim(0, 16) }),
			h("uiscale", {
				Scale: props.reducedMotion ? 1 : props.visualShow.map((value) => 0.96 + 0.04 * math.clamp(value, 0, 1)),
			}),
			h("uistroke", {
				Color: accent,
				Thickness: 1,
				Transparency: props.landFlash.map((value) => math.clamp(0.72 - value * 0.48, 0.18, 0.72)),
			}),
			h("uigradient", { Color: new ColorSequence(Palette.panelRaised, Palette.panel), Rotation: 90 }),
			h(
				"frame",
				{
					Size: new UDim2(1, -32, 0, 3),
					Position: UDim2.fromOffset(16, 0),
					BackgroundColor3: accent,
					BorderSizePixel: 0,
					ZIndex: 419,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
			ascended &&
				h(PrismAura, {
					rarity: props.winnerRarity,
					intensity: props.landPop.map((value) => math.clamp(value, 0, 1)),
					corner: 16,
					thickness: 3,
					clipRays: false,
					zIndex: 411,
				}),
			h(CrateModel, {
				skin: props.skin,
				size: UDim2.fromOffset(crateSize, crateSize),
				position: UDim2.fromOffset(padding - 4, padding - 6),
				open: landed ? 1 : props.phase === "spin" ? 0.4 : 0,
				shake: props.phase === "charge" ? 0.6 : 0,
				zoom: 0.85,
				live: !props.reducedMotion,
				zIndex: 420,
			}),
			h(Text, {
				value: props.crateName,
				size: compact ? 19 : 23,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 13,
				position: UDim2.fromOffset(nameX, padding),
				sizeConstraint: UDim2.fromOffset(math.max(1, panelWidth - nameX - padding - 100), 29),
				zIndex: 420,
			}),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(88, 30),
					Position: new UDim2(1, -padding - 88, 0, padding),
					BackgroundColor3: Palette.panelSoft,
					BackgroundTransparency: 0.35,
					BorderSizePixel: 0,
					ZIndex: 420,
				},
				h("uicorner", { CornerRadius: new UDim(0, 8) }),
				h(Text, {
					value: `${props.rollIndex + 1} / ${props.rollCount}`,
					size: 11,
					color: Palette.creamSoft,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Center,
					sizeConstraint: UDim2.fromScale(1, 1),
					zIndex: 421,
				}),
			),
			h(Text, {
				value: status,
				size: 10,
				color: accent,
				weight: Enum.FontWeight.Bold,
				position: UDim2.fromOffset(nameX, padding + 30),
				sizeConstraint: UDim2.fromOffset(math.max(1, panelWidth - nameX - padding), 18),
				zIndex: 420,
			}),
			track,
			h(
				"frame",
				{
					Size: UDim2.fromOffset(trackWidth, resultHeight),
					Position: props.landPop.map((value) =>
						UDim2.fromOffset(padding, resultY + (landed ? math.round((1 - value) * 8) : 0)),
					),
					BackgroundColor3: landed ? Palette.panelSoft : Palette.panel,
					BackgroundTransparency: landed ? 0.22 : 0.48,
					BorderSizePixel: 0,
					ZIndex: 450,
				},
				h("uicorner", { CornerRadius: new UDim(0, 10) }),
				h(
					"frame",
					{
						Size: UDim2.fromOffset(3, resultHeight - 20),
						Position: UDim2.fromOffset(10, 10),
						BackgroundColor3: accent,
						BorderSizePixel: 0,
						ZIndex: 451,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
				h(Text, {
					value: landed ? `${string.upper(props.winnerRarity)}  ·  ${props.resultTag}` : status,
					size: 10,
					color: accent,
					weight: Enum.FontWeight.Bold,
					position: UDim2.fromOffset(24, compact ? 5 : 8),
					sizeConstraint: new UDim2(1, -36, 0, 15),
					zIndex: 451,
				}),
				h(Text, {
					value: resultTitle,
					size: compact ? 17 : 20,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: true,
					minSize: 11,
					position: UDim2.fromOffset(24, compact ? 19 : 24),
					sizeConstraint: new UDim2(1, -36, 0, compact ? 22 : 26),
					zIndex: 451,
				}),
				h(Text, {
					value: resultSubtitle,
					size: 11,
					color: Palette.creamSoft,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(24, compact ? 41 : 51),
					sizeConstraint: new UDim2(1, -36, 0, 17),
					zIndex: 451,
				}),
			),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(math.min(300, trackWidth), actionHeight),
					Position: props.claimSlide.map(
						(value) => new UDim2(0.5, 0, 0, actionY + (canClaim ? math.round((1 - value) * 10) : 0)),
					),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ZIndex: 455,
				},
				(props.phase === "spin" || canClaim) &&
					h(
						"frame",
						{
							Name: canClaim ? "CrateClaim" : "CrateSkip",
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ClipsDescendants: false,
							ZIndex: 456,
						},
						h(Button, {
							text: canClaim ? props.claimText : "LOCK RING",
							onClick: canClaim ? props.onClaim : props.onQuickLand,
							color: canClaim ? props.sessionAccent : Palette.panelSoft,
							textColor: canClaim ? Palette.ink : Palette.cream,
							outline: !canClaim,
							size: UDim2.fromScale(1, 1),
							reducedMotion: props.reducedMotion,
							highlight: canClaim,
							selectable: true,
							zIndex: 456,
						}),
					),
			),
		),
	);
}
