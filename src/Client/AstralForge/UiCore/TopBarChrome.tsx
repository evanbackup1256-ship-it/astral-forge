import { useLiveSessionValue } from "./liveSession";
import { countRedraw, redrawCounterEnabled } from "./devRedrawCounter";
import { sameChromeProps, TOPBAR_STATE_KEYS } from "./chromeMemo";
import React from "@rbxts/react";
import { registerRegion } from "../CoreKit/selectionRegions";
import { mergeEvents, useTooltip } from "../Tooltip";
import CompanionRelic = require("../../../Shared/AstralForge/Shared/CompanionRelic");
import { useClientSelector } from "../CoreKit/clientStore";
import * as InventoryMath from "../CoreKit/inventoryMath";
import { GainPop } from "./GainPop";
import { AppHelpers } from "../CoreKit/appNav";
import * as BoostIconKind from "../CoreKit/boostIconKind";
import { Flux, asFlux, clockText, compactNumber } from "../CoreKit/format";
import * as ReleaseClockMath from "../CoreKit/releaseClockMath";
import { Layout, Palette, Radius, TapTarget, darken, ensureContrast, strokeGradient, surfaceGradient } from "../CoreKit/theme";
import { usePerformanceTelemetry } from "../MotionKit/antilag";
import { useEntrance, useFlash, useGlowStroke, usePulse } from "../MotionKit/motion";
import { EVENTS, ServerEvent, accentOf, clockText as eventClockText, openServerEventPanel, useServerEvent } from "./serverEventsUi";
import { Button, ButtonShimmer, IconTile, LogoLockup, LooseComponent, Text, resolvePressMotion, useButtonChrome } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const Workspace = game.GetService("Workspace");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

const Icon = (loadKit("ArtKit")("Icon") as { Icon: LooseComponent }).Icon;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

const NumberSpinnerHost = (loadKit("ReactHosts")("NumberSpinnerHost") as { NumberSpinnerHost: unknown }).NumberSpinnerHost;


interface JuiceFxModule {
	useTarget(this: void, name: string): LuaTuple<[React.MutableRefObject<GuiObject | undefined>, React.Binding<number>]>;
}
const JuiceFx = require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;

const BuffStrip = require(AstralForge.WaitForChild("BuffStrip") as ModuleScript) as { Island: unknown };

const CHIP_TIPS: Record<string, { title: string; body: string } | undefined> = {
	FLUX: {
		title: "Flux",
		body: "What machines, worlds and research cost. Machines fill the vault; collect it to spend.",
	},
	DUST: {
		title: "Stardust",
		body: "Comes from rebirths, missions and rewards. Spent in the Shop and on tuning echoes.",
	},
	CORES: {
		title: "Cores",
		body: "Paid out by each rebirth. Every core raises production for good, and Domain ranks cost them.",
	},
};

const SHELL_CHROME = {
	railGutter: 18,
	topbarControl: 48,
	topbarControlGap: 12,
};

interface StatChipProps {
	label: string;
	value: unknown;
	icon?: unknown;
	accent: Color3;
	reducedMotion?: boolean;
	velocity?: unknown;
	layoutOrder?: number;
	tall?: boolean;
	reactiveFlash?: boolean;
	placeholder?: string;
	showLabel?: boolean;
	animateValue?: boolean;
	narrow?: boolean;
	// read this session field live (B35) instead of `value`, so the chip redraws on its own ticks
	liveKey?: string;
}

export function StatChip(_param: StatChipProps) {
	const label = _param.label;
	const liveValue = useLiveSessionValue(_param.liveKey);
	const value = _param.liveKey !== undefined ? liveValue : _param.value;
	const icon = _param.icon;
	const accent = _param.accent;
	const reducedMotion = _param.reducedMotion;
	const velocity = _param.velocity ?? 0;
	const layoutOrder = _param.layoutOrder ?? 0;
	const tall = _param.tall ?? false;
	const reactiveFlash = _param.reactiveFlash ?? true;
	const placeholder = _param.placeholder;
	const showLabel = _param.showLabel ?? true;
	const animateValue = _param.animateValue ?? true;
	const [gains, setGains] = React.useState(0);
	const previous = React.useRef(value);
	React.useEffect(() => {
		const nextFlux = asFlux(value as Flux);
		const prevFlux = asFlux(previous.current as Flux);
		if (nextFlux === prevFlux) {
			return undefined;
		}
		if (reactiveFlash && nextFlux > prevFlux) {
			setGains((current) => current + 1);
		}
		previous.current = value;
		return undefined;
	}, [value, reactiveFlash]);
	const flash = useFlash(gains, reducedMotion);
	// flying coins land here; the chip bounces each time they do
	const [juiceRef, juiceBump] = JuiceFx.useTarget(label);
	const chipH = tall ? TapTarget : 44;
	const iconSize = tall ? 28 : 24;
	const valueSize = tall ? 15 : 14;
	const tip = CHIP_TIPS[label];
	const tipEvents = useTooltip(
		tip !== undefined
			? {
					title: tip.title,
					body: tip.body,
					hint: asFlux(velocity as Flux) > 0 ? `+${compactNumber(velocity)} a second right now` : undefined,
				}
			: undefined,
	);
	// room for long scale names ("37.3 Googolchime"); FPS/ping only ever show a few digits
	const valueMaxW = _param.narrow ? 40 : tall ? 108 : 116;
	const chipInnerW = iconSize + 6 + valueMaxW + (tall ? 20 : 18);
	const _exp = h("uicorner", {
		CornerRadius: new UDim(0, Radius.md),
	});
	const _exp_1 = h("uigradient", {
		Color: surfaceGradient(Palette.panel),
		Rotation: 90,
	});
	const _exp_2 = h(
		"uistroke",
		{
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			LineJoinMode: Enum.LineJoinMode.Round,
			Color: flash.map((amount) => Palette.lineSoft.Lerp(accent, amount)),
			Thickness: 1,
			Transparency: flash.map((amount) => 0.86 - amount * 0.5),
		},
		h("uigradient", {
			Rotation: 90,
			Color: flash.map((amount) => strokeGradient(Palette.lineSoft.Lerp(accent, amount))),
		}),
	);
	const _exp_3 = h("uipadding", {
		PaddingLeft: new UDim(0, tall ? 10 : 9),
		PaddingRight: new UDim(0, tall ? 12 : 11),
		PaddingTop: new UDim(0, tall ? 6 : 8),
		PaddingBottom: new UDim(0, tall ? 6 : 8),
	});
	const _exp_4 = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		SortOrder: Enum.SortOrder.LayoutOrder,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 6),
	});
	const _exp_5 = h(
		"frame",
		{
			Size: UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: 1,
			ClipsDescendants: true,
		},
		h(IconTile, {
			kind: icon,
			accent: accent,
			size: iconSize,
			radius: 99,
		}),
	);
	const _exp_6 = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Vertical,
		SortOrder: Enum.SortOrder.LayoutOrder,
		HorizontalAlignment: Enum.HorizontalAlignment.Left,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 0),
	});
	const _exp_7 =
		showLabel &&
		h("textlabel", {
			Size: UDim2.fromOffset(valueMaxW, 14),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			Text: label,
			TextColor3: ensureContrast(Palette.panel, accent),
			TextSize: 12,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment: Enum.TextXAlignment.Left,
			TextYAlignment: Enum.TextYAlignment.Center,
			TextScaled: false,
			TextTruncate: Enum.TextTruncate.AtEnd,
			LayoutOrder: 1,
		});
	let _result: unknown;
	if (placeholder !== undefined || !animateValue || typeIs(value, "string")) {
		const _attributes: Record<string, unknown> = {
			Size: UDim2.fromOffset(valueMaxW, 20),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			TextScaled: false,
			TextTruncate: Enum.TextTruncate.AtEnd,
		};
		_attributes.Text = placeholder ?? compactNumber(value);
		_attributes.TextColor3 = ensureContrast(Palette.panel, Palette.cream);
		_attributes.TextSize = valueSize;
		_attributes.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold);
		_attributes.TextXAlignment = Enum.TextXAlignment.Left;
		_attributes.TextYAlignment = Enum.TextYAlignment.Center;
		_attributes.LayoutOrder = 2;
		_result = h(
			"textlabel",
			_attributes,
			h("uitextsizeconstraint", {
				MinTextSize: 10,
				MaxTextSize: valueSize,
			}),
		);
	} else {
		_result = h(NumberSpinnerHost, {
			value: value,
			velocity: asFlux(velocity as Flux),
			reducedMotion: reducedMotion,
			duration: 0.32,
			size: valueSize,
			color: ensureContrast(Palette.panel, Palette.cream),
			autoWidth: false,
			spacedSuffix: true,
			sizeConstraint: UDim2.fromOffset(valueMaxW, 20),
			layoutOrder: 2,
			zIndex: 3,
		});
	}
	const chip = h(
		"frame",
		{
			Size: UDim2.fromOffset(chipInnerW, chipH),
			AutomaticSize: Enum.AutomaticSize.None,
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			ClipsDescendants: true,
		},
		h("uiscale", {
			Scale: juiceBump.map((b) => 1 + math.sin(b * math.pi) * 0.14),
		}),
		_exp,
		_exp_1,
		_exp_2,
		_exp_3,
		_exp_4,
		_exp_5,
		h(
			"frame",
			{
				Size: UDim2.fromOffset(valueMaxW, 34),
				AutomaticSize: Enum.AutomaticSize.None,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: 2,
				ClipsDescendants: true,
			},
			_exp_6,
			_exp_7,
			_result,
		),
	);
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(chipInnerW + 4, chipH + 2),
			AutomaticSize: Enum.AutomaticSize.None,
			LayoutOrder: layoutOrder,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ZIndex: 22,
			ClipsDescendants: false,
			Name: label,
			ref: juiceRef,
			Event: tipEvents,
		},
		h("uipadding", {
			PaddingLeft: new UDim(0, 2),
			PaddingRight: new UDim(0, 2),
			PaddingTop: new UDim(0, 1),
			PaddingBottom: new UDim(0, 1),
		}),
		chip,
		placeholder === undefined && tip !== undefined && h(GainPop, { value: value, rate: velocity, color: accent, zIndex: 24 }),
	);
}

interface TopBarState {
	ServerEvent?: ServerEvent;
	Cores?: Flux;
	Stardust?: Flux;
	Cash?: Flux;
	Visitors?: unknown;
	Production?: unknown;
	Capacity?: Flux;
	Vault?: Flux;
	FeatureUnlocks?: Record<string, { Unlocked?: boolean } | undefined>;
	Settings?: { ShowFps?: unknown; ShowPing?: unknown; ShowResourceLabels?: unknown; MobileCompactHeaders?: unknown };
	[key: string]: unknown;
}

function ServerEventChip(_param: { state: TopBarState; reducedMotion?: boolean; tall?: boolean; layoutOrder?: number }) {
	const event = useServerEvent(_param.state.ServerEvent);
	const [now, setNow] = React.useState(() => Workspace.GetServerTimeNow());
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				const t = Workspace.GetServerTimeNow();
				task.wait(1 - (t % 1) + 0.02);
				if (alive) {
					setNow(Workspace.GetServerTimeNow());
				}
			}
		});
		return () => {
			alive = false;
		};
	}, []);
	if (event === undefined) {
		return undefined;
	}
	const def = EVENTS[event.Id ?? ""];
	const active = def !== undefined && event.Phase !== "Rest";
	const left = eventClockText((event.PhaseEndsAt ?? now) - now);
	const value = !active
		? left
		: event.Phase === "Warning"
			? `in ${left}`
			: event.Phase === "Live"
				? `${left} left`
				: event.Completed === true
					? "Goal hit"
					: "Done";
	return h(
		"textbutton",
		{
			Size: UDim2.fromOffset(0, 0),
			AutomaticSize: Enum.AutomaticSize.XY,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			LayoutOrder: _param.layoutOrder,
			ZIndex: 22,
			Event: {
				Activated: openServerEventPanel,
			},
		},
		h(StatChip, {
			label: active ? string.upper(def.Name) : "NEXT EVENT",
			value: 0,
			placeholder: value,
			icon: active ? def.Icon : "Calendar.5",
			accent: active ? accentOf(def) : Palette.blue,
			reducedMotion: _param.reducedMotion,
			reactiveFlash: false,
			animateValue: false,
			tall: _param.tall,
			showLabel: true,
		}),
	);
}

type CompanionInfo = NonNullable<ReturnType<typeof CompanionRelic.describe>>;

const sameCompanion = (a: CompanionInfo | undefined, b: CompanionInfo | undefined) =>
	a === b ||
	(a !== undefined &&
		b !== undefined &&
		a.Uid === b.Uid &&
		a.Id === b.Id &&
		a.Bonus === b.Bonus &&
		a.Rank === b.Rank &&
		a.Progress === b.Progress &&
		(a.Offer !== undefined) === (b.Offer !== undefined));

const RING = 18;
const RING_EDGE = new NumberSequence([
	new NumberSequenceKeypoint(0, 0),
	new NumberSequenceKeypoint(0.499, 0),
	new NumberSequenceKeypoint(0.5, 1),
	new NumberSequenceKeypoint(1, 1),
]);

// one half of the bond ring: a circle clipped to its half, the arc drawn by a hard-edged gradient
function RingHalf(_param: { right: boolean; rotation: number; color: Color3 }) {
	return h(
		"frame",
		{
			Size: new UDim2(0.5, 0, 1, 0),
			Position: UDim2.fromScale(_param.right ? 0.5 : 0, 0),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: true,
		},
		h(
			"frame",
			{
				Size: new UDim2(2, -4, 1, -4),
				Position: new UDim2(_param.right ? -1 : 0, 2, 0, 2),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: _param.color, Thickness: 2.5 }, h("uigradient", { Transparency: RING_EDGE, Rotation: _param.rotation })),
		),
	);
}

// bond progress inside the current rank, drawn clockwise from the top
function BondRing(_param: { progress: number; color: Color3; ready: boolean }) {
	const angle = math.clamp(_param.progress, 0, 1) * 360;
	return h(
		"frame",
		{ Size: UDim2.fromOffset(RING, RING), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 0 },
		h(
			"frame",
			{ Size: new UDim2(1, -4, 1, -4), Position: UDim2.fromOffset(2, 2), BackgroundTransparency: 1, BorderSizePixel: 0 },
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", { Color: Palette.lineSoft, Thickness: 2.5, Transparency: 0.5 }),
		),
		h(RingHalf, { right: true, rotation: math.clamp(angle, 0, 180), color: _param.color }),
		h(RingHalf, { right: false, rotation: 180 + math.clamp(angle - 180, 0, 180), color: _param.color }),
		_param.ready &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(6, 6),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					BackgroundColor3: Palette.mango,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
	);
}

// read straight from the store so a relic change redraws the chip without widening the TopBar memo keys
function useCompanion(): CompanionInfo | undefined {
	return useClientSelector((store) => CompanionRelic.describe((store.session as { Items?: unknown } | undefined)?.Items), sameCompanion);
}

// the relic riding along in the Companion slot: name in its rarity color, the bonus in the tooltip
function CompanionChip(_param: { companion: CompanionInfo; config?: unknown; tall?: boolean; layoutOrder?: number; reducedMotion?: boolean }) {
	const companion = _param.companion;
	const accent = InventoryMath.RarityColor(_param.config, companion.Rarity, Palette.violet);
	const pct = math.floor(companion.Bonus * 1000 + 0.5) / 10;
	const traitLine = companion.Trait !== undefined ? ` ${companion.Trait.Text}.` : "";
	const tip = useTooltip({
		title: companion.Suffix !== "" ? `${companion.Name}, ${companion.Suffix}` : companion.Name,
		body: `${companion.Rarity} companion, bond rank ${companion.Rank}. Gives +${pct}% ${companion.Kind} on top of your sockets.${traitLine}`,
		hint: companion.Offer !== undefined ? "A trait is waiting in Inventory" : "Swap it from Inventory",
	});
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(0, 0),
			AutomaticSize: Enum.AutomaticSize.XY,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			LayoutOrder: _param.layoutOrder,
			ZIndex: 22,
			Active: false,
			Event: mergeEvents(tip, {}),
		},
		h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			SortOrder: Enum.SortOrder.LayoutOrder,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 6),
		}),
		h(BondRing, { progress: companion.Progress, color: accent, ready: companion.Offer !== undefined }),
		h(StatChip, {
			layoutOrder: 1,
			label: "COMPANION",
			value: 0,
			placeholder: companion.Name,
			icon: "Artifact.6",
			accent: accent,
			reducedMotion: _param.reducedMotion,
			reactiveFlash: false,
			animateValue: false,
			tall: _param.tall,
			showLabel: true,
		}),
	);
}

export function PerformanceStats(_param: { tall?: boolean; reducedMotion?: boolean; showFps?: boolean; showPing?: boolean }) {
	const tall = _param.tall ?? false;
	const reducedMotion = _param.reducedMotion;
	const showFps = _param.showFps ?? true;
	const showPing = _param.showPing ?? true;
	const telemetry = usePerformanceTelemetry();
	const fps = math.max(0, math.floor(telemetry.fps + 0.5));
	const ping = telemetry.pingMs !== undefined ? math.max(0, math.floor(telemetry.pingMs + 0.5)) : undefined;
	const fpsAccent = fps >= 54 ? Palette.mint : fps >= 38 ? Palette.mango : Palette.coral;
	const pingAccent =
		ping === undefined ? Palette.muted : ping <= 85 ? Palette.mint : ping <= 165 ? Palette.mango : Palette.coral;
	const _exp = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		SortOrder: Enum.SortOrder.LayoutOrder,
		HorizontalAlignment: Enum.HorizontalAlignment.Right,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 8),
	});
	const _exp_1 =
		showFps &&
		h(StatChip, {
			label: "FPS",
			value: fps,
			icon: "Timer.8",
			accent: fpsAccent,
			reducedMotion: reducedMotion,
			reactiveFlash: false,
			animateValue: false,
			placeholder: `${fps}`,
			tall: tall,
			narrow: true,
			layoutOrder: 1,
		});
	let _condition: unknown = showPing;
	if (_condition) {
		const _attributes: Record<string, unknown> = {
			label: "PING",
		};
		_attributes.value = ping ?? 0;
		_attributes.icon = "Wave.15";
		_attributes.accent = pingAccent;
		_attributes.reducedMotion = reducedMotion;
		_attributes.reactiveFlash = false;
		_attributes.animateValue = false;
		_attributes.placeholder = ping === undefined ? "—" : `${ping}`;
		_attributes.tall = tall;
		_attributes.narrow = true;
		_attributes.layoutOrder = 2;
		_condition = h(StatChip, _attributes);
	}
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(0, tall ? TapTarget : 50),
			AutomaticSize: Enum.AutomaticSize.X,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: false,
		},
		_exp,
		_exp_1,
		_condition,
	);
}

const boostIconKind = BoostIconKind.of;

interface BoostInfo {
	Id: string;
	Name: string;
	Color: Color3;
	Duration: number;
	Multiplier?: number;
	CapacityMultiplier?: number;
}

export function ActiveBoostIcon(_param: {
	boost: BoostInfo;
	endsAt: number;
	now: React.Binding<number>;
	open: () => void;
	reducedMotion?: boolean;
	compact?: boolean;
}) {
	const boost = _param.boost;
	const endsAt = _param.endsAt;
	const now = _param.now;
	const open = _param.open;
	const reducedMotion = _param.reducedMotion;
	const compact = _param.compact ?? false;
	const remaining = now.map((timestamp) => clockText(math.max(0, endsAt - timestamp)));
	const fraction = now.map((timestamp) => math.clamp((endsAt - timestamp) / math.max(1, boost.Duration), 0, 1));
	const chrome = useButtonChrome(
		open,
		reducedMotion,
		false,
		"boostOpen",
		true,
		false,
		resolvePressMotion(
			compact
				? {
						icon: boost.Id,
						size: UDim2.fromOffset(62, 62),
					}
				: {
						text: boost.Name,
						size: UDim2.fromOffset(220, 56),
					},
		),
	);
	const reveal = useEntrance(reducedMotion);
	const radius = compact ? 11 : 12;
	const visualScale = React.joinBindings({
		press: chrome.touchScale,
		reveal: reveal,
	}).map((values) => {
		const press = values.press;
		const amount = values.reveal;
		return press * (0.94 + math.clamp(amount, 0, 1) * 0.06);
	});
	const visualPosition = React.joinBindings({
		offset: chrome.offsetY,
		reveal: reveal,
	}).map((values) => {
		const offset = values.offset;
		const amount = values.reveal;
		return new UDim2(0.5, 0, 0.5, math.round(offset + (1 - math.clamp(amount, 0, 1)) * 6));
	});
	const hoverFill = chrome.hoverAmount.map((amount) => Palette.panelRaised.Lerp(darken(boost.Color, 0.72), math.clamp(amount, 0, 1) * 0.24));
	const [runningLow, setRunningLow] = React.useState(() => endsAt - Workspace.GetServerTimeNow() <= boost.Duration * 0.15);
	React.useEffect(() => {
		const threshold = boost.Duration * 0.15;
		const remainingSeconds = endsAt - Workspace.GetServerTimeNow();
		const shouldRunLow = remainingSeconds <= threshold;
		setRunningLow(shouldRunLow);
		if (shouldRunLow) {
			return undefined;
		}
		const timer = task.delay(math.max(0, remainingSeconds - threshold), () => setRunningLow(true));
		return () => task.cancel(timer);
	}, [boost.Duration, endsAt]);
	const urgentStroke = useGlowStroke(runningLow, reducedMotion, 0.5, 0.15, 0.65, 2.4);
	const strokeTransparency = React.joinBindings({
		hover: chrome.hoverAmount,
		glow: urgentStroke,
	}).map((values) => {
		const hover = values.hover;
		const glow = values.glow;
		return math.min(0.5 - hover * 0.22, glow);
	});
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: false,
		},
		h(
			"imagebutton",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Active: true,
				Selectable: true,
				Event: chrome.events,
			},
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					Position: visualPosition,
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: chrome.tilt,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				h("uiscale", {
					Scale: visualScale,
				}),
				h(
					"frame",
					{
						Size: new UDim2(1, 0, 1, -3),
						Position: UDim2.fromOffset(0, 4),
						BackgroundColor3: Palette.shadow,
						BackgroundTransparency: 0.18,
						BorderSizePixel: 0,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, radius),
					}),
				),
				h(
					"frame",
					{
						Size: new UDim2(1, 0, 1, -3),
						BackgroundColor3: hoverFill,
						BorderSizePixel: 0,
						ClipsDescendants: true,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, radius),
					}),
					h("uigradient", {
						Color: surfaceGradient(Palette.panelRaised, 0.5),
						Rotation: 90,
					}),
					h(
						"frame",
						{
							Size: UDim2.fromOffset(compact ? 3 : 4, compact ? 34 : 38),
							Position: new UDim2(0, 0, 0.5, 0),
							AnchorPoint: new Vector2(0, 0.5),
							BackgroundColor3: boost.Color,
							BorderSizePixel: 0,
							ZIndex: 2,
						},
						h("uicorner", {
							CornerRadius: new UDim(1, 0),
						}),
					),
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundColor3: Palette.white,
							BackgroundTransparency: chrome.hoverAmount.map((amount) => 1 - amount * 0.1),
							BorderSizePixel: 0,
							ZIndex: 2,
						},
						h("uicorner", {
							CornerRadius: new UDim(0, radius),
						}),
					),
					h(ButtonShimmer, {
						hoverAmount: chrome.hoverAmount,
						shimmer: chrome.shimmer,
						live: chrome.shimmerLive,
						idle: true,
						zIndex: 2,
						radius: radius,
					}),
					h(IconTile, {
						kind: boostIconKind(boost.Id),
						accent: boost.Color,
						size: compact ? 34 : 40,
						radius: compact ? 9 : 10,
						position: compact ? new UDim2(0.5, -17, 0, 4) : UDim2.fromOffset(9, 8),
						spin: chrome.hovered,
						hoverAmount: chrome.hoverAmount,
						reducedMotion: reducedMotion,
						zIndex: 3,
					}),
					compact
						? h(Text, {
								value: remaining,
								size: 10,
								color: Palette.cream,
								weight: Enum.FontWeight.Heavy,
								align: Enum.TextXAlignment.Center,
								fit: true,
								minSize: 8,
								position: new UDim2(0, 5, 1, -19),
								sizeConstraint: new UDim2(1, -10, 0, 13),
								zIndex: 4,
							})
						: h(
								React.Fragment,
								undefined,
								h(Text, {
									value: "ACTIVE BOOST",
									size: 9,
									color: boost.Color,
									weight: Enum.FontWeight.Heavy,
									fit: false,
									position: UDim2.fromOffset(60, 6),
									sizeConstraint: new UDim2(1, -128, 0, 13),
									zIndex: 4,
								}),
								h(Text, {
									value: boost.Name,
									size: 13,
									color: Palette.cream,
									weight: Enum.FontWeight.Heavy,
									fit: true,
									minSize: 10,
									position: UDim2.fromOffset(60, 20),
									sizeConstraint: new UDim2(1, -128, 0, 18),
									zIndex: 4,
								}),
								h(Text, {
									value: remaining,
									size: 13,
									color: Palette.cream,
									weight: Enum.FontWeight.Heavy,
									align: Enum.TextXAlignment.Right,
									fit: true,
									minSize: 10,
									position: new UDim2(1, -64, 0, 18),
									sizeConstraint: UDim2.fromOffset(54, 18),
									zIndex: 4,
								}),
								h(Text, {
									value: AppHelpers.boostEffectText(boost),
									size: 9,
									color: Palette.muted,
									weight: Enum.FontWeight.Bold,
									fit: true,
									minSize: 8,
									position: UDim2.fromOffset(60, 38),
									sizeConstraint: new UDim2(1, -72, 0, 13),
									zIndex: 4,
								}),
							),
					h(
						"frame",
						{
							Size: compact ? new UDim2(1, -12, 0, 3) : new UDim2(1, -69, 0, 3),
							Position: compact ? new UDim2(0, 6, 1, -6) : new UDim2(0, 60, 1, -7),
							BackgroundColor3: Palette.lineSoft,
							BorderSizePixel: 0,
							ZIndex: 4,
						},
						h("uicorner", {
							CornerRadius: new UDim(1, 0),
						}),
						h(
							"frame",
							{
								Size: fraction.map((amount) => new UDim2(amount, 0, 1, 0)),
								BackgroundColor3: boost.Color,
								BorderSizePixel: 0,
							},
							h("uicorner", {
								CornerRadius: new UDim(1, 0),
							}),
						),
					),
				),
				h(
					"frame",
					{
						Size: new UDim2(1, 0, 1, -3),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 4,
					},
					h("uicorner", {
						CornerRadius: new UDim(0, radius),
					}),
					h("uistroke", {
						ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
						LineJoinMode: Enum.LineJoinMode.Round,
						Color: boost.Color,
						Thickness: 1,
						Transparency: strokeTransparency,
					}),
				),
			),
		),
	);
}

export function TopbarReleaseCountdown(_param: { releaseAt: unknown; width: number; reducedMotion?: boolean }) {
	const releaseAt = _param.releaseAt;
	const width = _param.width;
	const reducedMotion = _param.reducedMotion ?? false;
	const syncedNow = () => {
		const [ok, value] = pcall(() => Workspace.GetServerTimeNow());
		if (ok && typeIs(value, "number")) {
			return math.floor(value);
		}
		return os.time();
	};
	const [now, setNow] = React.useState(syncedNow());
	React.useEffect(() => {
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				task.wait(0.5);
				if (alive) {
					const current = syncedNow();
					setNow(current);
					// once it's live nothing on the card reads the clock again; stop waking up
					// (and re-rendering) every second for the rest of the session
					if (ReleaseClockMath.IsLive(releaseAt, current)) {
						break;
					}
				}
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [releaseAt]);
	const remaining = ReleaseClockMath.Remaining(releaseAt, now);
	const live = ReleaseClockMath.IsLive(releaseAt, now);
	const wasLive = React.useRef(live);
	React.useEffect(() => {
		if (live && !wasLive.current) {
			wasLive.current = true;
			if (!reducedMotion) {
				Audio.play("prestige");
				Audio.play("bootFinaleBang");
			}
		}
		if (!live) {
			wasLive.current = false;
		}
	}, [live, reducedMotion]);
	const pulse = usePulse(live, 2.4);
	const days = math.floor(remaining / 86400);
	const hours = math.floor(remaining / 3600) % 24;
	const minutes = math.floor(remaining / 60) % 60;
	const seconds = remaining % 60;
	const pair = (value: number) => (value < 10 ? `0${value}` : tostring(value));
	const values = live
		? [
				{
					value: "LIVE",
					unit: "NOW",
					color: Palette.mint,
				},
			]
		: [
				{
					value: tostring(days),
					unit: "DAYS",
					color: Palette.cyan,
				},
				{
					value: pair(hours),
					unit: "HRS",
					color: Palette.violet,
				},
				{
					value: pair(minutes),
					unit: "MIN",
					color: Palette.pink,
				},
				{
					value: pair(seconds),
					unit: "SEC",
					color: Palette.mango,
				},
			];
	const labelW = live ? (width >= 360 ? 96 : 82) : width >= 360 ? 104 : 88;
	const strokeColor = live ? Palette.mint : Palette.cyan;
	const strokeTransparency = live ? pulse.map((amount) => 0.3 + (1 - amount) * 0.4) : 0.8;
	const fillWash = live ? pulse.map((amount) => 0.82 - amount * 0.28) : 1;
	const _exp = h("uicorner", {
		CornerRadius: new UDim(0, Radius.md),
	});
	const _exp_1 = h("uistroke", {
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
		LineJoinMode: Enum.LineJoinMode.Round,
		Color: strokeColor,
		Thickness: 1,
		Transparency: strokeTransparency,
	});
	const _exp_2 =
		live &&
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.mint,
				BackgroundTransparency: fillWash,
				BorderSizePixel: 0,
				ZIndex: 1,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, Radius.md),
			}),
		);
	const _condition: unknown = undefined;
	const _exp_3 = h(
		"frame",
		{
			Size: UDim2.fromOffset(26, 26),
			Position: UDim2.fromOffset(9, 11),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: true,
		},
		h(Icon, {
			kind: "Calendar.6",
			color: Palette.cream,
			accent: live ? Palette.mint : Palette.cyan,
			size: 26,
			spin: live,
		}),
	);
	const _exp_4 = h(Text, {
		value: live ? "LAUNCH" : "NEXT",
		size: 10,
		color: live ? Palette.mint : Palette.cyan,
		weight: Enum.FontWeight.Heavy,
		fit: false,
		position: UDim2.fromOffset(40, 7),
		sizeConstraint: UDim2.fromOffset(labelW - 42, 14),
		zIndex: 3,
	});
	const _exp_5 = h(Text, {
		value: live ? "LIVE" : "UPDATE",
		size: 10,
		minSize: 8,
		color: live ? Palette.cream : Palette.creamSoft,
		weight: Enum.FontWeight.Bold,
		fit: true,
		position: UDim2.fromOffset(40, 23),
		sizeConstraint: UDim2.fromOffset(labelW - 42, 15),
		zIndex: 3,
	});
	const _exp_6 = h("frame", {
		Size: new UDim2(0, 1, 1, -16),
		Position: UDim2.fromOffset(labelW, 8),
		BackgroundColor3: Palette.lineSoft,
		BackgroundTransparency: 0.36,
		BorderSizePixel: 0,
		ZIndex: 3,
	});
	const _exp_7 = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		SortOrder: Enum.SortOrder.LayoutOrder,
		HorizontalAlignment: Enum.HorizontalAlignment.Center,
		VerticalAlignment: Enum.VerticalAlignment.Center,
	});
	const _newValue = values.map((entry, index) =>
		h(
			"frame",
			{
				key: entry.unit,
				Size: new UDim2(1 / values.size(), 0, 1, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: index,
			},
			index > 0 &&
				h("frame", {
					Size: UDim2.fromOffset(1, 22),
					Position: new UDim2(0, 0, 0.5, -11),
					BackgroundColor3: Palette.lineSoft,
					BackgroundTransparency: 0.5,
					BorderSizePixel: 0,
				}),
			h("textlabel", {
				Size: new UDim2(1, -4, 0, 21),
				Position: UDim2.fromOffset(2, 3),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				Text: entry.value,
				TextColor3: entry.color,
				TextSize: live ? 15 : 14,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextXAlignment: Enum.TextXAlignment.Center,
				TextYAlignment: Enum.TextYAlignment.Center,
				TextTruncate: Enum.TextTruncate.None,
				ZIndex: 4,
			}),
			h(Text, {
				value: entry.unit,
				size: 10,
				minSize: 9,
				color: live ? Palette.mint : Palette.muted,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				align: Enum.TextXAlignment.Center,
				position: UDim2.fromOffset(2, 25),
				sizeConstraint: new UDim2(1, -4, 0, 11),
				zIndex: 3,
			}),
		),
	);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.ink,
			BackgroundTransparency: 0.04,
			BorderSizePixel: 0,
			ClipsDescendants: true,
		},
		_exp,
		_exp_1,
		_exp_2,
		_condition,
		_exp_3,
		_exp_4,
		_exp_5,
		_exp_6,
		h(
			"frame",
			{
				Size: new UDim2(1, -(labelW + 7), 1, -6),
				Position: UDim2.fromOffset(labelW + 5, 3),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: false,
				ZIndex: 3,
			},
			_exp_7,
			_newValue,
		),
	);
}

interface VisitInfo {
	DisplayName: string;
}

interface ChipDef {
	label: string;
	event?: boolean;
	companion?: boolean;
	value?: unknown;
	liveKey?: string;
	icon?: string;
	accent?: Color3;
}

interface TopBarProps {
	state: TopBarState;
	page: string;
	railOpen: boolean;
	toggleRail: () => void;
	hideUI: () => void;
	tight: boolean;
	width: number;
	topPad: number;
	barHeight: number;
	barHeightMotion?: React.Binding<number>;
	edgePad: number;
	reducedMotion?: boolean;
	releaseAt?: unknown;
	visit?: VisitInfo;
	openPlayerlist: () => void;
	openFeedback: () => void;
	navigate?: (page: string) => void;
	config?: unknown;
	// desktop layout editor: island left-to-right letter order, hidden letters, detached spot (screen px) and size
	chipOrder?: string;
	chipHidden?: string;
	islandX?: number;
	islandY?: number;
	islandScale?: number;
}

const CHIP_LETTER: Record<string, string> = { FLUX: "F", CORES: "C", DUST: "D", EVENT: "E", COMPANION: "P" };

function TopBarImpl(_param: TopBarProps) {
	countRedraw("TopBar", redrawCounterEnabled(_param.state as { Admin?: { Access?: boolean } }));
	const state = _param.state;
	const companion = useCompanion();
	const page = _param.page;
	const railOpen = _param.railOpen;
	const toggleRail = _param.toggleRail;
	const hideUI = _param.hideUI;
	const tight = _param.tight;
	const width = _param.width;
	const topPad = _param.topPad;
	const barHeight = _param.barHeight;
	const barHeightMotion = _param.barHeightMotion;
	const edgePad = _param.edgePad;
	const reducedMotion = _param.reducedMotion;
	const releaseAt = _param.releaseAt;
	const visit = _param.visit;
	const openPlayerlist = _param.openPlayerlist;
	const openFeedback = _param.openFeedback;
	const accent = AppHelpers.pageAccent(page);
	const shortRow = barHeight <= 54 && width < 980;
	const micro = barHeight <= 54 && width < 620;
	const stacked = barHeight > Layout.topbarHeight;
	const chipWidthEstimate = stacked ? 172 : micro ? 172 : 170;
	const logoCompact = tight || stacked || barHeight <= Layout.topbarHeight;
	const logoWidth = micro ? 48 : stacked ? 156 : shortRow ? 156 : logoCompact ? 168 : 176;
	const visitorsHere = typeIs(state.Visitors, "table") ? (state.Visitors as unknown[]).size() : 0;
	const visitPill =
		!stacked && visit !== undefined
			? {
					label: `AT ${string.upper(visit.DisplayName)}`,
					accent: Palette.blue,
				}
			: !stacked && visitorsHere > 0
				? {
						label: visitorsHere === 1 ? "1 VISITOR" : `${visitorsHere} VISITORS`,
						accent: Palette.mango,
					}
				: undefined;
	const allChips: ChipDef[] = [];
	if (state.ServerEvent !== undefined) {
		allChips.push({ label: "EVENT", event: true });
	}
	if (companion !== undefined) {
		allChips.push({ label: "COMPANION", companion: true });
	}
	if (AppHelpers.featureUnlocked(state, "Rebirth")) {
		allChips.push({
			label: "CORES",
			value: state.Cores,
			icon: "Core.8",
			accent: Palette.violet,
		});
	}
	if (AppHelpers.featureUnlocked(state, "StarGrid")) {
		allChips.push({
			label: "DUST",
			value: state.Stardust,
			icon: "Dust.13",
			accent: Palette.mango,
		});
	}
	allChips.push({
		label: "FLUX",
		liveKey: "Cash",
		icon: "Flux.21",
		accent: Palette.cyan,
	});
	const chipHidden = _param.chipHidden ?? "";
	if (chipHidden !== "") {
		for (let index = allChips.size() - 1; index >= 0; index--) {
			const [found] = chipHidden.find(CHIP_LETTER[allChips[index].label] ?? "?", 1, true);
			if (found !== undefined) {
				allChips.remove(index);
			}
		}
	}
	const chipOrder = _param.chipOrder;
	if (chipOrder !== undefined && chipOrder !== "") {
		// island lists currencies reversed, so sort descending to read left-to-right in chipOrder
		const rankOf = (chip: ChipDef) => chipOrder.find(CHIP_LETTER[chip.label] ?? "?", 1, true)[0] ?? 99;
		table.sort(allChips, (a, b) => rankOf(a) > rankOf(b));
	}
	const visitPillWidth = visitPill !== undefined ? (tight ? 124 : 156) : 0;
	const countdownW = 0;
	const showFps = (tonumber(state.Settings?.ShowFps) ?? 1) >= 0.5;
	const showPing = (tonumber(state.Settings?.ShowPing) ?? 1) >= 0.5;
	const showLabels = (tonumber(state.Settings?.ShowResourceLabels) ?? 1) >= 0.5;
	const performanceCount = (showFps ? 1 : 0) + (showPing ? 1 : 0);
	const fullPerformanceW =
		micro || performanceCount === 0 ? 0 : performanceCount === 1 ? (stacked ? 96 : 90) : stacked ? 200 : 188;
	const performanceGap = 10;
	const playerControlGap = shortRow ? 6 : 8;
	const playerControlW = micro || stacked || width < 980 ? SHELL_CHROME.topbarControl : 110;
	const feedbackControlGap = shortRow ? 6 : 8;
	const showFeedbackControl = !(stacked && width < 360);
	const feedbackControlW = !showFeedbackControl ? 0 : micro || stacked || width < 1480 ? SHELL_CHROME.topbarControl : 116;
	const searchControlW = width < 340 ? 0 : micro || stacked || width < 1280 ? SHELL_CHROME.topbarControl : 112;
	const controlsBeforeSearch =
		SHELL_CHROME.topbarControl +
		playerControlGap +
		playerControlW +
		(showFeedbackControl ? feedbackControlGap + feedbackControlW : 0);
	const controlsW = controlsBeforeSearch + (searchControlW > 0 ? feedbackControlGap + searchControlW : 0);
	const fixedSingleRow =
		edgePad * 2 +
		(logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) +
		controlsW +
		12 +
		(visitPillWidth > 0 ? visitPillWidth + 6 : 0) +
		(countdownW > 0 ? countdownW + 10 : 0);
	// currencies matter more than FPS/ping: the performance readout only stays when at least two
	// resource chips (or all of them, if fewer) still fit beside it
	const minimumResourceRoom = math.min(allChips.size(), 2) * (chipWidthEstimate + 8);
	const performanceW =
		!stacked && fullPerformanceW > 0 && width - fixedSingleRow - fullPerformanceW - performanceGap < minimumResourceRoom
			? 0
			: fullPerformanceW;
	let chips = allChips;
	const controlsRight = edgePad + 4;
	// Show only the chips that fit whole, most important first (flux, cores, dust, then the event),
	// instead of a scroller whose last chip is sliced by the edge and whose flux chip falls off it.
	if (!stacked) {
		const railRoom = math.max(
			48,
			width -
				edgePad * 2 -
				(controlsW + controlsRight + 12) -
				(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14),
		);
		const room = railRoom - (performanceW > 0 ? performanceW + 8 : 0) - (visitPillWidth > 0 ? visitPillWidth + 8 : 0);
		const chipFitW = micro ? 172 : 170; // a rendered desktop chip is ~166px with the wider value box
		const fits = math.max(0, math.floor((room + 8) / (chipFitW + 8)));
		if (fits < allChips.size()) {
			const rank: Record<string, number> = { FLUX: 1, CORES: 2, DUST: 3, EVENT: 4, COMPANION: 5 };
			const ranked = table.clone(allChips);
			table.sort(ranked, (a, b) => (rank[a.label] ?? 9) < (rank[b.label] ?? 9));
			const keep = new Set<ChipDef>();
			for (let index = 0; index < fits; index++) {
				keep.add(ranked[index]);
			}
			chips = [];
			for (const chip of allChips) {
				if (keep.has(chip)) {
					chips.push(chip);
				}
			}
		}
	}
	const hasRightCluster = !stacked && (chips.size() > 0 || visitPill !== undefined || performanceW > 0);
	const row1H = stacked ? 62 : barHeight;
	const logoMark = micro ? 40 : SHELL_CHROME.topbarControl;
	const logoH = logoMark;
	const controlY = math.floor((row1H - SHELL_CHROME.topbarControl) / 2);
	const logoY = controlY + math.floor((SHELL_CHROME.topbarControl - logoMark) / 2);
	const chipRowH = stacked ? 44 : shortRow ? math.max(28, barHeight - 4) : 44;
	const _exp_1 = h("uicorner", {
		CornerRadius: new UDim(0, Radius.lg),
	});
	const _exp_2 = h("uigradient", {
		Color: surfaceGradient(Palette.panel, 0.58),
		Rotation: 90,
	});
	const _exp_3 = h("uistroke", {
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
		LineJoinMode: Enum.LineJoinMode.Round,
		Color: Palette.lineSoft,
		Thickness: 1,
		Transparency: 0.85,
	});
	const _exp_4: unknown = undefined;
	const _exp_5: unknown = undefined;
	const _exp_6 = h(
		"frame",
		{
			Size: UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
			Position: UDim2.fromOffset(12, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
			BackgroundTransparency: 1,
			ZIndex: 22,
		},
		h(Button, {
			text: "",
			icon: railOpen ? "Close.11" : "Menu.1",
			onClick: toggleRail,
			color: Palette.panelSoft,
			textColor: Palette.cream,
			size: UDim2.fromScale(1, 1),
			reducedMotion: reducedMotion,
			motion: resolvePressMotion({
				text: "",
				icon: railOpen ? "Close.12" : "Menu.2",
				size: UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
			}),
		}),
	);
	const _exp_7 = h(
		"frame",
		{
			Size: UDim2.fromOffset(logoWidth, logoH),
			Position: UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap, logoY),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: false,
		},
		h(LogoLockup, {
			compact: logoCompact,
			micro: micro,
			accent: accent,
			reducedMotion: reducedMotion,
		}),
	);
	const _exp_8 =
		countdownW > 0 &&
		h(
			"frame",
			{
				Size: UDim2.fromOffset(countdownW, 48),
				Position: UDim2.fromOffset(
					12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14,
					math.floor((row1H - 48) / 2),
				),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: true,
				ZIndex: 22,
			},
			h(TopbarReleaseCountdown, {
				releaseAt: releaseAt,
				width: countdownW,
				reducedMotion: reducedMotion,
			}),
		);
	// desktop: currencies, FPS/ping and buffs live in the island, centred between the logo and controls
	const islandLeft =
		12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14 + (countdownW > 0 ? countdownW + 10 : 0);
	const islandRight = controlsW + controlsRight + 12 + (visitPillWidth > 0 ? visitPillWidth + 8 : 0);
	const islandRoom = math.max(160, width - edgePad * 2 - islandLeft - islandRight);
	const islandCurrencies: { target: string; name: string; value: unknown; liveKey?: string; icon?: string; color?: Color3; rate?: unknown }[] = [];
	for (const chip of allChips) {
		if (chip.event !== true) {
			islandCurrencies.unshift({
				target: chip.label,
				name: chip.label === "FLUX" ? "Flux" : chip.label === "DUST" ? "Stardust" : "Cores",
				value: chip.value,
				liveKey: chip.liveKey,
				icon: chip.icon,
				color: chip.accent,
				rate: chip.label === "FLUX" ? state.Production : undefined,
			});
		}
	}
	const islandScale = math.clamp(_param.islandScale ?? 1, 0.8, 1.25);
	const islandDetached = (_param.islandX ?? -1) >= 0 && (_param.islandY ?? -1) >= 0;
	const islandWrap = (child: React.Element) =>
		!islandDetached && islandScale === 1
			? child
			: h(
					"frame",
					{
						Size: UDim2.fromOffset(0, 0),
						Position: islandDetached
							? UDim2.fromOffset(_param.islandX! - edgePad, _param.islandY! - topPad)
							: new UDim2(0, islandLeft + islandRoom / 2, 0, math.floor((row1H - 44) / 2)),
						BackgroundTransparency: 1,
						ZIndex: 24,
					},
					h("uiscale", { Scale: islandScale }),
					child,
				);
	const islandElement =
		!stacked &&
		h(
			React.Fragment,
			undefined,
			islandWrap(h(BuffStrip.Island, {
				state: state,
				config: _param.config,
				currencies: islandCurrencies,
				perf: {
					showFps: showFps,
					showPing: showPing,
				},
				rate: state.Production,
				liveVaultFull: true,
				navigate: _param.navigate,
				maxWidth: islandDetached ? math.max(islandRoom, 420) : islandRoom,
				position: islandDetached || islandScale !== 1 ? new UDim2() : new UDim2(0, islandLeft + islandRoom / 2, 0, math.floor((row1H - 44) / 2)),
				anchorPoint: new Vector2(0.5, 0),
				reducedMotion: reducedMotion,
			})),
			visitPill !== undefined &&
				h(
					"frame",
					{
						Size: UDim2.fromOffset(visitPillWidth, TapTarget),
						Position: new UDim2(1, -(controlsW + controlsRight + 12), 0.5, 0),
						AnchorPoint: new Vector2(1, 0.5),
						BackgroundTransparency: 1,
						ZIndex: 22,
					},
					h(Button, {
						text: visitPill.label,
						icon: "Crew.13",
						onClick: openPlayerlist,
						color: Palette.panelSoft,
						textColor: visitPill.accent,
						outline: true,
						size: UDim2.fromScale(1, 1),
						reducedMotion: reducedMotion,
					}),
				),
		);
	let _condition_3: unknown = hasRightCluster && stacked;
	if (_condition_3) {
		const _exp_9 = h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			SortOrder: Enum.SortOrder.LayoutOrder,
			HorizontalAlignment: Enum.HorizontalAlignment.Left,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 8),
		});
		let _condition_4: unknown = performanceW > 0;
		if (_condition_4) {
			const _attributes: Record<string, unknown> = {
				tall: false,
				reducedMotion: reducedMotion,
			};
			_attributes.showFps = showFps;
			_attributes.showPing = showPing;
			_condition_4 = h(PerformanceStats, _attributes);
		}
		const _exp_10 =
			visitPill !== undefined &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(visitPillWidth, TapTarget),
					LayoutOrder: 10,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				h(Button, {
					text: visitPill.label,
					icon: "Crew.14",
					onClick: openPlayerlist,
					color: Palette.panelSoft,
					textColor: visitPill.accent,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
				}),
			);
		const _newValue = chips.map((chip, index) => {
			if (chip.event === true) {
				return h(ServerEventChip, {
					key: chip.label,
					layoutOrder: 20 + index,
					state: state,
					reducedMotion: reducedMotion,
				});
			}
			if (chip.companion === true) {
				return companion !== undefined
					? h(CompanionChip, { key: chip.label, layoutOrder: 20 + index, companion: companion, config: _param.config, reducedMotion: reducedMotion })
					: undefined;
			}
			const _attributes: Record<string, unknown> = {
				key: chip.label,
				layoutOrder: 20 + index,
				label: chip.label,
				value: chip.value,
				liveKey: chip.liveKey,
				icon: chip.icon,
				accent: chip.accent,
				reducedMotion: reducedMotion,
				velocity: chip.label === "FLUX" ? state.Production : 0,
			};
			_attributes.showLabel = showLabels;
			return h(StatChip, _attributes);
		});
		_condition_3 = h(
			"scrollingframe",
			{
				Name: "TopbarResourceRail",
				Size: UDim2.fromOffset(
					math.max(
						48,
						width -
							edgePad * 2 -
							(controlsW + controlsRight + 12) -
							(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14),
					),
					chipRowH + 4,
				),
				AutomaticCanvasSize: Enum.AutomaticSize.X,
				CanvasSize: new UDim2(),
				ScrollingDirection: Enum.ScrollingDirection.X,
				ScrollBarThickness: 2,
				ScrollBarImageColor3: accent,
				AnchorPoint: new Vector2(1, 0.5),
				Position: new UDim2(1, -(controlsW + controlsRight + 12), 0.5, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 22,
				ClipsDescendants: true,
			},
			_exp_9,
			_condition_4,
			_exp_10,
			_newValue,
		);
	}
	let _condition_4: unknown = stacked;
	if (_condition_4) {
		const _exp_9 = h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			SortOrder: Enum.SortOrder.LayoutOrder,
			HorizontalAlignment: Enum.HorizontalAlignment.Left,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 10),
		});
		const _newValue = chips.map((chip, index) => {
			if (chip.event === true) {
				return h(ServerEventChip, {
					key: chip.label,
					layoutOrder: index + 1,
					state: state,
					reducedMotion: reducedMotion,
					tall: true,
				});
			}
			if (chip.companion === true) {
				return companion !== undefined
					? h(CompanionChip, {
							key: chip.label,
							layoutOrder: index + 1,
							companion: companion,
							config: _param.config,
							reducedMotion: reducedMotion,
							tall: true,
						})
					: undefined;
			}
			const _attributes: Record<string, unknown> = {
				key: chip.label,
				layoutOrder: index + 1,
				label: chip.label,
				value: chip.value,
				liveKey: chip.liveKey,
				icon: chip.icon,
				accent: chip.accent,
				reducedMotion: reducedMotion,
				velocity: chip.label === "FLUX" ? state.Production : 0,
				tall: true,
			};
			_attributes.showLabel = showLabels;
			return h(StatChip, _attributes);
		});
		_condition_4 = h(
			"scrollingframe",
			{
				Name: "TopbarResourceRail",
				AutomaticCanvasSize: Enum.AutomaticSize.X,
				CanvasSize: new UDim2(),
				ScrollingDirection: Enum.ScrollingDirection.X,
				ScrollBarThickness: 2,
				ScrollBarImageColor3: accent,
				Size: new UDim2(1, -(24 + (performanceW > 0 ? performanceW + performanceGap : 0)), 0, TapTarget + 6),
				Position: UDim2.fromOffset(12, row1H + 2),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 22,
				ClipsDescendants: true,
			},
			_exp_9,
			_newValue,
		);
	}
	let _condition_5: unknown = stacked && performanceW > 0;
	if (_condition_5) {
		const _attributes: Record<string, unknown> = {
			tall: true,
			reducedMotion: reducedMotion,
		};
		_attributes.showFps = showFps;
		_attributes.showPing = showPing;
		_condition_5 = h(
			"frame",
			{
				Size: UDim2.fromOffset(performanceW, TapTarget),
				Position: new UDim2(1, -(performanceW + 12), 0, row1H + 2),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ZIndex: 23,
				ClipsDescendants: true,
			},
			h(PerformanceStats, _attributes),
		);
	}
	const regionRef = React.useRef<Frame>();
	React.useEffect(() => {
		const root = regionRef.current;
		return root !== undefined ? registerRegion("top", root) : undefined;
	}, []);
	return h(
		"frame",
		{
			Size:
				barHeightMotion !== undefined
					? barHeightMotion.map((height) => new UDim2(1, -edgePad * 2, 0, height))
					: new UDim2(1, -edgePad * 2, 0, barHeight),
			Position: UDim2.fromOffset(edgePad, topPad),
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			ZIndex: 20,
			ClipsDescendants: false,
			ref: regionRef,
		},
		_exp_1,
		_exp_2,
		_exp_3,
		_exp_4,
		_exp_5,
		_exp_6,
		_exp_7,
		_exp_8,
		_condition_3,
		islandElement,
		_condition_4,
		_condition_5,
		h(
			"frame",
			{
				Size: UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
				Position: new UDim2(
					1,
					-(SHELL_CHROME.topbarControl + controlsRight),
					0,
					math.floor((row1H - SHELL_CHROME.topbarControl) / 2),
				),
				BackgroundTransparency: 1,
				ZIndex: 22,
			},
			h(Button, {
				text: "",
				icon: "Hide.3",
				onClick: hideUI,
				color: Palette.panelSoft,
				textColor: accent,
				size: UDim2.fromScale(1, 1),
				reducedMotion: reducedMotion,
				motion: resolvePressMotion({
					text: "",
					icon: "Hide.4",
					size: UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
				}),
			}),
		),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
				Position: new UDim2(
					1,
					-(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW),
					0,
					math.floor((row1H - SHELL_CHROME.topbarControl) / 2),
				),
				BackgroundTransparency: 1,
				ZIndex: 22,
			},
			h(Button, {
				text: playerControlW > SHELL_CHROME.topbarControl ? "PLAYERS" : "",
				icon: "Pilot.3",
				onClick: openPlayerlist,
				tooltip: {
					title: "Players",
					body: "Everyone in this server: trade, visit, wave or add a friend.",
					hint: "Tab",
				},
				color: Palette.panelSoft,
				textColor: Palette.cyan,
				size: UDim2.fromScale(1, 1),
				reducedMotion: reducedMotion,
				motion: resolvePressMotion({
					text: playerControlW > SHELL_CHROME.topbarControl ? "PLAYERS" : "",
					icon: "Pilot.4",
					size: UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
				}),
			}),
		),
		showFeedbackControl &&
			h(
				"frame",
				{
					Size: UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
					Position: new UDim2(
						1,
						-(
							SHELL_CHROME.topbarControl +
							controlsRight +
							playerControlGap +
							playerControlW +
							feedbackControlGap +
							feedbackControlW
						),
						0,
						math.floor((row1H - SHELL_CHROME.topbarControl) / 2),
					),
					BackgroundTransparency: 1,
					ZIndex: 22,
				},
				h(Button, {
					text: feedbackControlW > SHELL_CHROME.topbarControl ? "FEEDBACK" : "",
					icon: "Chat.5",
					onClick: openFeedback,
					tooltip: { title: "Feedback", body: "Tell us about a bug or an idea. It goes straight to the team." },
					color: Palette.panelSoft,
					textColor: Palette.mint,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
					motion: resolvePressMotion({
						text: feedbackControlW > SHELL_CHROME.topbarControl ? "FEEDBACK" : "",
						icon: "Chat.6",
						size: UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
					}),
				}),
			),
		searchControlW > 0 &&
			h(
				"frame",
				{
					Name: "QuickFindButton",
					Size: UDim2.fromOffset(searchControlW, SHELL_CHROME.topbarControl),
					Position: new UDim2(1, -(controlsRight + controlsW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
					BackgroundTransparency: 1,
					ZIndex: 22,
				},
				h(Button, {
					text: searchControlW > SHELL_CHROME.topbarControl ? "FIND" : "",
					icon: "Search.12",
					tooltip: {
						title: "Find",
						body: "Jump to any page, machine, setting or command by typing its name.",
						hint: "Ctrl+K",
					},
					onClick: () => {
						(require(AstralForge.WaitForChild("QuickFind") as ModuleScript) as { open(this: void): void }).open();
					},
					color: Palette.panelSoft,
					textColor: Palette.cream,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
					motion: resolvePressMotion({
						text: searchControlW > SHELL_CHROME.topbarControl ? "FIND" : "",
						icon: "Search.13",
						size: UDim2.fromOffset(searchControlW, SHELL_CHROME.topbarControl),
					}),
				}),
			),
	);
}

export const TopBar = React.memo(TopBarImpl, sameChromeProps(TOPBAR_STATE_KEYS));
