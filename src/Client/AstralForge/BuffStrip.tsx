// The buff strip: every multiplier working for you right now, as a row of small icons with the value
// underneath (boost and surge timers count down). Chips pop in when a buff starts, bob gently out of
// step with each other, and the timed ones pulse.
import React from "@rbxts/react";
import ArtKit = require("./ArtKit");
import Juice = require("./JuiceFx");
import Rainbow = require("./Rainbow");
import { useTooltip } from "./Tooltip";
import { GainPop } from "./UiCore/GainPop";
import { useLiveSessionValue, useLiveVaultFull } from "./UiCore/liveSession";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import * as motion from "./MotionKit/motion";
import { isReducedMotion } from "./MotionPreference";
import { usePerformanceTelemetry } from "./MotionKit/antilag";

const Workspace = game.GetService("Workspace");
const RunService = game.GetService("RunService");
const TextService = game.GetService("TextService");

const Icon = (ArtKit("Icon") as {
	Icon: React.FunctionComponent<{
		kind?: string;
		color?: Color3;
		accent?: Color3;
		size?: number;
		position?: UDim2 | React.Binding<UDim2>;
		anchorPoint?: Vector2;
		spin?: boolean;
	}>;
}).Icon;

const P = theme.Palette;
const h = React.createElement as unknown as (
	component: unknown,
	props?: Record<string, unknown> | undefined,
	...children: unknown[]
) => React.Element;

interface BuffInfo {
	key: string;
	icon: string;
	value: string;
	endsAt?: unknown;
	duration?: number;
	color: Color3;
	name: string;
	note?: string;
}

interface CurrencyEntry {
	target: string;
	name?: string;
	value: unknown;
	// read this session field live instead of `value` (B35)
	liveKey?: string;
	icon?: string;
	color?: Color3;
	rate?: unknown;
}

interface PerfFlags {
	showFps?: boolean;
	showPing?: boolean;
}

interface StripProps {
	state?: unknown;
	config?: unknown;
	width?: number;
	size?: UDim2;
	position?: UDim2;
	anchorPoint?: Vector2;
	align?: Enum.HorizontalAlignment;
	reducedMotion?: boolean;
}

interface CompactPlan {
	width: number;
	perf: boolean;
	buffs: BuffInfo[];
}

interface IslandProps {
	state?: unknown;
	config?: unknown;
	currencies?: CurrencyEntry[];
	perf?: PerfFlags;
	rate?: unknown;
	vaultFull?: boolean;
	// compute vaultFull from the live session (B35) instead of the prop
	liveVaultFull?: boolean;
	navigate?: (destination: string) => void;
	maxWidth?: number;
	position?: UDim2;
	anchorPoint?: Vector2;
	restHidden?: boolean;
	reducedMotion?: boolean;
}

const BuffStrip = {} as {
	list(this: void, state: unknown, config: unknown, now: number): BuffInfo[];
	Strip(this: void, props: StripProps): React.Element;
	Island(this: void, props: IslandProps): React.Element;
};

const CHIP_W = 58;

function clockText(seconds: number): string {
	const s = math.max(0, math.floor(seconds));
	if (s >= 3600) {
		return string.format("%dh%02d", math.floor(s / 3600), math.floor((s % 3600) / 60));
	}
	return string.format("%d:%02d", math.floor(s / 60), s % 60);
}

// what is boosting the player right now, most urgent first
BuffStrip.list = function (state: unknown, config: unknown, now: number): BuffInfo[] {
	const list: BuffInfo[] = [];
	if (!typeIs(state, "table")) {
		return list;
	}
	const bag = state as Record<string, unknown>;
	const configBag = typeIs(config, "table") ? (config as Record<string, unknown>) : undefined;
	const boost = bag.ActiveBoost;
	if (
		typeIs(boost, "table") &&
		typeIs((boost as Record<string, unknown>).Id, "string") &&
		(boost as Record<string, unknown>).Id !== "" &&
		(tonumber((boost as Record<string, unknown>).EndsAt) ?? 0) > now
	) {
		const boostTable = boost as Record<string, unknown>;
		const boosts = configBag !== undefined ? (configBag.Boosts as Record<string, unknown> | undefined) : undefined;
		const def =
			boosts !== undefined ? (boosts[boostTable.Id as string] as Record<string, unknown> | undefined) : undefined;
		const mult = def !== undefined ? tonumber(def.Multiplier) ?? tonumber(def.ProductionMultiplier) : undefined;
		list.push({
			key: "boost",
			icon: "Boost.1",
			value: mult !== undefined ? `x${mult}` : "On",
			endsAt: boostTable.EndsAt,
			duration: def !== undefined ? (def.Duration as number | undefined) : undefined,
			color: P.pink,
			name: def !== undefined && def.Name !== undefined ? (def.Name as string) : "Boost",
			note: def !== undefined && def.Description !== undefined ? (def.Description as string) : "A boost you used from your inventory.",
		});
	}
	const surge = bag.FluxSurge;
	if (typeIs(surge, "table") && (surge as Record<string, unknown>).Active === true) {
		const surgeTable = surge as Record<string, unknown>;
		const multiplier = (surgeTable.Multiplier as number | undefined) ?? 2;
		list.push({
			key: "surge",
			icon: "Flux.2",
			value: `x${multiplier}`,
			endsAt: surgeTable.EndsAt,
			duration: surgeTable.DurationSeconds as number | undefined,
			color: P.cyan,
			name: "Flux surge",
			note: `Everyone in this server makes ${multiplier}x flux until it ends.`,
		});
	}
	const level = bag.Level;
	const forgeSurge =
		typeIs(level, "table") && typeIs((level as Record<string, unknown>).Progression, "table")
			? ((level as Record<string, unknown>).Progression as Record<string, unknown>).Surge
			: undefined;
	if (
		typeIs(forgeSurge, "table") &&
		(tonumber((forgeSurge as Record<string, unknown>).EndsAt) ?? 0) > now &&
		(tonumber((forgeSurge as Record<string, unknown>).Multiplier) ?? 1) > 1
	) {
		const surgeTable = forgeSurge as Record<string, unknown>;
		list.push({
			key: "forgeSurge",
			icon: "Boost.4",
			value: string.format("x%.2f", surgeTable.Multiplier as number),
			endsAt: surgeTable.EndsAt,
			duration: surgeTable.DurationSeconds as number | undefined,
			color: P.pink,
			name: "Forge surge",
			note: "From your last Forge Level. Production is multiplied until the timer runs out.",
		});
	}
	const event = bag.ServerEvent;
	if (typeIs(event, "table") && (event as Record<string, unknown>).Phase === "Live" && typeIs((event as Record<string, unknown>).Id, "string")) {
		const eventTable = event as Record<string, unknown>;
		list.push({
			key: "event",
			icon: "Calendar.1",
			value: "Live",
			endsAt: eventTable.PhaseEndsAt,
			color: P.mango,
			name: (eventTable.Id as string).gsub("(%l)(%u)", "%1 %2")[0],
			note: "A server event is live. Open the island to see it.",
		});
	}
	const ascension = bag.Ascension;
	if (typeIs(ascension, "table") && (tonumber((ascension as Record<string, unknown>).Rank) ?? 0) > 0) {
		const ascensionTable = ascension as Record<string, unknown>;
		list.push({
			key: "ascension",
			icon: "Rebirth.2",
			value: `x${format.compactNumber(ascensionTable.Production ?? 1)}`,
			color: P.mango,
			name: "Ascension",
			note: `Ascension rank ${ascensionTable.Rank}. Permanent.`,
		});
	}
	const continuum = bag.Continuum;
	if (
		typeIs(continuum, "table") &&
		format.asFlux(((continuum as Record<string, unknown>).ProductionMultiplier as number | string | undefined) ?? 1) > 1
	) {
		const continuumTable = continuum as Record<string, unknown>;
		list.push({
			key: "continuum",
			icon: "Continuum.1",
			value: `x${format.compactNumber(continuumTable.ProductionMultiplier)}`,
			color: P.cyan,
			name: "Star Foundry",
			note: "From the Star Foundry. Permanent.",
		});
	}
	if (format.asFlux((bag.PermanentMultiplier as number | string | undefined) ?? 1) > 1) {
		list.push({
			key: "rebirth",
			icon: "Core.2",
			value: `x${format.compactNumber(bag.PermanentMultiplier)}`,
			color: P.violet,
			name: "Cores and rebirths",
			note: "Your cores and rebirths together. Permanent; every rebirth raises it.",
		});
	}
	const guild = bag.GuildBonuses;
	if (typeIs(guild, "table") && (tonumber((guild as Record<string, unknown>).Production) ?? 0) > 0) {
		const guildTable = guild as Record<string, unknown>;
		list.push({
			key: "guild",
			icon: "Crew.1",
			value: `+${math.floor((tonumber(guildTable.Production) ?? 0) * 100 + 0.5)}%`,
			color: P.mint,
			name: "Guild",
			note: "Your guild's production perk, while you're a member.",
		});
	}
	return list;
};

interface ChipProps {
	buff: BuffInfo;
	order?: number;
	clock?: React.Binding<number>;
	reducedMotion?: boolean;
}

function Chip(props: ChipProps): React.Element {
	const buff = props.buff;
	const appear = motion.useFlipperSpring(1, props.reducedMotion, 300, 16);
	const timed = buff.endsAt !== undefined;
	const pulse = motion.usePulse(timed, 2.2);
	const tip = useTooltip({
		title: `${buff.name} · ${buff.value}`,
		body: buff.note,
		hint: timed ? "Runs out when the ring empties." : "Stays on while its source is active.",
		accent: buff.color,
	});
	return h(
		"frame",
		{
			Event: tip,
			Size: UDim2.fromOffset(CHIP_W, 52),
			LayoutOrder: props.order,
			BackgroundTransparency: 1,
			ZIndex: 20,
		},
		h("uiscale", {
			Scale: appear.map((v) => math.max(0.01, v)),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(34, 34),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundColor3: theme.darken(buff.color, 0.62),
				BorderSizePixel: 0,
				ZIndex: 21,
				Position: new UDim2(0.5, 0, 0, 1), // icons hold still (ICON_MOTION)
			},
			h("uicorner", { CornerRadius: new UDim(0, 10) }),
			h("uistroke", {
				Color: buff.color,
				Thickness: 1.5,
				Transparency: timed ? pulse.map((v) => 0.05 + v * 0.45) : 0.35,
			}),
			h(Icon, {
				kind: buff.icon,
				color: P.cream,
				accent: buff.color,
				size: 22,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, 8, 0, 14),
				Position: new UDim2(0.5, 0, 0, 37),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				Text: timed
					? props.clock!.map(() => {
							return clockText((tonumber(buff.endsAt) ?? 0) - Workspace.GetServerTimeNow());
						})
					: buff.value,
				TextColor3: P.cream,
				TextSize: 12,
				TextScaled: true,
				TextWrapped: false,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 22,
			},
			h("uistroke", { Color: P.void, Thickness: 1.5, Transparency: 0.2 }),
			h("uitextsizeconstraint", { MaxTextSize: 12, MinTextSize: 11 }),
		),
		timed &&
			h(
				"textlabel",
				{
					// the multiplier sits on the icon's corner when the label shows the timer
					Size: UDim2.fromOffset(30, 14),
					Position: new UDim2(0.5, 14, 0, -4),
					AnchorPoint: new Vector2(0.5, 0),
					BackgroundColor3: buff.color,
					BorderSizePixel: 0,
					Text: buff.value,
					TextColor3: P.ink,
					TextSize: 11,
					TextScaled: true,
					TextWrapped: false,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
					ZIndex: 24,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uitextsizeconstraint", { MaxTextSize: 11, MinTextSize: 11 }),
			),
	);
}

// `width` caps how many chips show; the rest are dropped from the end
BuffStrip.Strip = function (props: StripProps): React.Element {
	const clock = motion.useClock(true, 1, 3600, true);
	const hostRef = React.useRef<GuiObject>(undefined);
	const [width, setWidth] = React.useState(props.width ?? 0);
	React.useEffect(() => {
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const measure = () => {
			setWidth(host.AbsoluteSize.X);
		};
		measure();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		return () => {
			connection.Disconnect();
		};
	}, []);
	const now = Workspace.GetServerTimeNow();
	const buffs = BuffStrip.list(props.state, props.config, now);
	const room = math.max(0, math.floor((width + 4) / (CHIP_W + 4)));
	const children: Record<string, React.Element> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			HorizontalAlignment: props.align ?? Enum.HorizontalAlignment.Center,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 4),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
	};
	for (const [index, buff] of pairs(buffs)) {
		if (index > room) {
			break;
		}
		children[buff.key] = h(Chip, { buff, order: index, clock, reducedMotion: props.reducedMotion });
	}
	return h(
		"frame",
		{
			Name: "BuffStrip",
			ref: hostRef,
			Size: props.size,
			Position: props.position,
			AnchorPoint: props.anchorPoint,
			BackgroundTransparency: 1,
			ZIndex: 20,
		},
		children,
	);
};

// The island: one black capsule that morphs. Compact, it shows each buff as an icon and its value.
// Hover (or tap) and it grows into a list with names and live timers. When something happens
// (a rebirth, a boost starting, an unlock, a rare drop) it widens into an announcement, then
// settles back. Size, corners and contents all spring between shapes.

const COMPACT_H = 44;
const EVENT_H = 62;
const ROW_H = 44;

function easeOutBack(x: number): number {
	const c1 = 1.5;
	const c3 = 2.5;
	return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
}

// contents fade and rise in each time the island changes shape
function useArrive(key: unknown): React.Binding<number> {
	const [amount, setAmount] = React.useBinding(0);
	React.useEffect(() => {
		setAmount(0);
		const start = os.clock() + 0.06;
		let connection: RBXScriptConnection | undefined;
		connection = RunService.RenderStepped.Connect(() => {
			const t = math.clamp((os.clock() - start) / 0.32, 0, 1);
			setAmount(t);
			if (t >= 1 && connection !== undefined) {
				connection.Disconnect();
			}
		});
		return () => {
			if (connection !== undefined && connection.Connected) {
				connection.Disconnect();
			}
		};
	}, [key]);
	return amount;
}

// FPS/ping are part of the strip's own plan; the telemetry source may move around the codebase
const telemetryHook = usePerformanceTelemetry;

const PERF_W = 104;
const CURRENCY_W = 104;
const BUFF_W = 58;
const SEP_W = 21;
const VAULT_W = 92;

function fpsColor(fps: number): Color3 {
	return fps >= 54 ? P.mint : fps >= 38 ? P.mango : P.coral;
}
function pingColor(ping: number | undefined): Color3 {
	return ping === undefined ? P.muted : ping <= 85 ? P.mint : ping <= 165 ? P.mango : P.coral;
}

interface PerfSegmentProps {
	order: number;
	clock: React.Binding<number>;
	showFps?: boolean;
	showPing?: boolean;
}

// frame rate and ping: a status dot and two short numbers; only this re-renders on each sample
function PerfSegment(props: PerfSegmentProps): React.Element {
	const telemetry = telemetryHook();
	const fps = math.max(0, math.floor(telemetry.fps + 0.5));
	const ping = telemetry.pingMs !== undefined ? math.max(0, math.floor(telemetry.pingMs + 0.5)) : undefined;
	const parts: string[] = [];
	if (props.showFps === true) {
		parts.push(`${fps} fps`);
	}
	if (props.showPing === true) {
		parts.push(ping !== undefined ? `${ping} ms` : "-- ms");
	}
	const worst =
		props.showFps === true && fps < 38 ? fpsColor(fps) : props.showPing === true ? pingColor(ping) : fpsColor(fps);
	const perfTip = useTooltip({
		title: "Frame rate and ping",
		body: "Frames per second on your device, and the round trip to the server.",
		hint: "Hide either one in Settings > Interface.",
	});
	return h(
		"frame",
		{
			Event: perfTip,
			Size: UDim2.fromOffset(PERF_W, COMPACT_H),
			LayoutOrder: props.order,
			BackgroundTransparency: 1,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(8, 8),
				Position: new UDim2(0, 4, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: worst,
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: worst,
				Thickness: 2,
				Transparency: props.clock.map((t) => 0.55 + (math.sin(t * 3) + 1) * 0.2),
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -18, 1, 0),
				Position: UDim2.fromOffset(18, 0),
				BackgroundTransparency: 1,
				Text: parts.join(" · "),
				TextColor3: P.creamSoft,
				TextSize: 12,
				TextScaled: true,
				TextWrapped: false,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			},
			h("uitextsizeconstraint", { MaxTextSize: 12, MinTextSize: 11 }),
		),
	);
}

// one currency: flying coins land here and the value hops when they do
const CURRENCY_TIPS: Record<string, string> = {
	FLUX: "What machines, worlds and research cost. Machines fill the vault; collect it to spend.",
	DUST: "Comes from rebirths, missions and rewards. Spent in the Shop and on tuning echoes.",
	CORES: "Paid out by each rebirth. Every core raises production for good, and Domain ranks cost them.",
};

interface CurrencySegmentProps {
	currency: CurrencyEntry;
	order: number;
	reducedMotion?: boolean;
}

// a claim-sized jump rolls up over a moment; normal ticking and reduced motion just set the number
function useRollingValue(target: number, rate: number, reducedMotion?: boolean) {
	const [shown, setShown] = React.useBinding(target);
	const from = React.useRef(target);
	React.useEffect(() => {
		const start = from.current;
		from.current = target;
		const jump = target - start;
		if (reducedMotion === true || isReducedMotion() || jump <= 0 || jump <= math.max(rate, 0) * 3) {
			setShown(target);
			return undefined;
		}
		const began = os.clock();
		const DURATION = 0.6;
		const conn = RunService.Heartbeat.Connect(() => {
			const t = math.clamp((os.clock() - began) / DURATION, 0, 1);
			const eased = 1 - (1 - t) * (1 - t) * (1 - t);
			setShown(t >= 1 ? target : math.floor(start + jump * eased));
			if (t >= 1) conn.Disconnect();
		});
		return () => {
			conn.Disconnect();
			setShown(target);
		};
	}, [target]);
	return shown;
}

function CurrencySegment(props: CurrencySegmentProps): React.Element {
	const currency = props.currency;
	const [ref, bump] = Juice.useTarget(currency.target);
	const rate = format.asFlux((currency.rate as number | string | undefined) ?? 0);
	const tip = useTooltip({
		title: `${format.compactNumber(currency.value)} ${currency.name ?? currency.target}`,
		body: CURRENCY_TIPS[currency.target],
		hint: rate > 0 ? `+${format.compactNumber(rate)} a second right now` : undefined,
		accent: currency.color,
	});
	const flash = motion.useFlash(format.asFlux(currency.value as number | string), props.reducedMotion, 0.45);
	const rolling = useRollingValue(format.asFlux(currency.value as number | string), rate, props.reducedMotion);
	return h(
		"frame",
		{
			ref,
			Event: tip,
			Size: UDim2.fromOffset(CURRENCY_W, COMPACT_H),
			LayoutOrder: props.order,
			BackgroundTransparency: 1,
		},
		h("uiscale", {
			Scale: bump.map((b) => 1 + math.sin(b * math.pi) * 0.16),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(24, 24),
				Position: new UDim2(0, 0, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: theme.darken(currency.color ?? P.mango, 0.6),
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: currency.color,
				Thickness: 1,
				Transparency: flash.map((v) => 0.55 - v * 0.5),
			}),
			h(Icon, {
				kind: currency.icon,
				color: P.cream,
				accent: currency.color,
				size: 16,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -30, 1, 0),
				Position: UDim2.fromOffset(30, 0),
				BackgroundTransparency: 1,
				Text: rolling.map((v) => format.compactNumber(v)),
				TextColor3: flash.map((v) => P.cream.Lerp(theme.lighten(currency.color ?? P.mango, 0.4), v)),
				TextSize: 15,
				TextScaled: true,
				TextWrapped: false,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			},
			h("uitextsizeconstraint", { MaxTextSize: 15, MinTextSize: 11 }),
		),
		h(GainPop, { value: currency.value, rate: currency.rate, color: currency.color ?? P.mango }),
	);
}

function Separator(order: number): React.Element {
	return h("frame", {
		Size: UDim2.fromOffset(1, 20),
		LayoutOrder: order,
		BackgroundColor3: P.line,
		BackgroundTransparency: 0.3,
		BorderSizePixel: 0,
	});
}

// what fits in the compact capsule: performance and currencies first, then as many buffs as fit
function planCompact(props: IslandProps, buffs: BuffInfo[]): CompactPlan {
	const currencies = props.currencies ?? [];
	const perfOn = props.perf !== undefined && (props.perf.showFps === true || props.perf.showPing === true);
	let width = 32 + currencies.size() * (CURRENCY_W + 10);
	const showPerf = perfOn && width + PERF_W + SEP_W <= (props.maxWidth ?? 9999);
	if (showPerf) {
		width += PERF_W + SEP_W;
	}
	const shownBuffs: BuffInfo[] = [];
	let room =
		(props.maxWidth ?? 9999) -
		width -
		(buffs.size() > 0 ? SEP_W : 0) -
		(props.vaultFull === true ? SEP_W + VAULT_W + 10 : 0);
	for (const buff of buffs) {
		if (room >= BUFF_W + 10) {
			shownBuffs.push(buff);
			room -= BUFF_W + 10;
		}
	}
	if (shownBuffs.size() > 0) {
		width += SEP_W + shownBuffs.size() * (BUFF_W + 10);
	}
	if (props.vaultFull === true) {
		width += SEP_W + VAULT_W + 10;
	}
	if (currencies.size() === 0 && !showPerf) {
		width = 28 + shownBuffs.size() * (BUFF_W + 10);
	}
	return { width, perf: showPerf, buffs: shownBuffs };
}

interface BuffCellProps {
	buff: BuffInfo;
	Size?: UDim2;
	LayoutOrder?: number;
	children?: React.Element[];
}

// one buff in the capsule; hovering says what it is and how long it has left
function BuffCell(props: BuffCellProps): React.Element {
	const buff = props.buff;
	const left = buff.endsAt !== undefined ? (tonumber(buff.endsAt) ?? 0) - Workspace.GetServerTimeNow() : undefined;
	const tip = useTooltip({
		title: `${buff.name} ${buff.value}`,
		body: buff.note,
		hint: left !== undefined && left > 0 ? `${clockText(left)} left` : undefined,
		accent: buff.color,
	});
	return h(
		"frame",
		{
			Event: tip,
			Size: props.Size,
			LayoutOrder: props.LayoutOrder,
			BackgroundTransparency: 1,
		},
		props.children,
	);
}

interface CompactRowProps {
	plan: CompactPlan;
	currencies?: CurrencyEntry[];
	perf?: PerfFlags;
	vaultFull?: boolean;
	clock: React.Binding<number>;
	reducedMotion?: boolean;
}

// the resting look: a slim bar with coins, counters and whatever is running
function CompactRow(props: CompactRowProps): React.Element {
	const arrive = useArrive("compact");
	const plan = props.plan;
	const items: Record<string, React.Element> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			HorizontalAlignment: Enum.HorizontalAlignment.Center,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			Padding: new UDim(0, 10),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
	};
	let order = 0;
	const nextOrder = () => {
		order += 1;
		return order;
	};
	if (plan.perf) {
		items.perf = h(PerfSegment, {
			order: nextOrder(),
			clock: props.clock,
			showFps: props.perf !== undefined ? props.perf.showFps : undefined,
			showPing: props.perf !== undefined ? props.perf.showPing : undefined,
		});
		items.sep1 = Separator(nextOrder());
	}
	for (const currency of props.currencies ?? []) {
		items[`c${currency.target}`] = h(CurrencySegment, {
			order: nextOrder(),
			currency,
			reducedMotion: props.reducedMotion,
		});
	}
	if (props.vaultFull === true) {
		items.sepVault = Separator(nextOrder());
		items.vault = h(
			"frame",
			{
				Size: UDim2.fromOffset(VAULT_W, COMPACT_H),
				LayoutOrder: nextOrder(),
				BackgroundTransparency: 1,
			},
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 26),
					Position: UDim2.fromScale(0, 0.5),
					AnchorPoint: new Vector2(0, 0.5),
					BackgroundColor3: theme.darken(P.mango, 0.55),
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uiscale", {
					Scale: props.clock.map((t) => 1 + math.max(0, math.sin(t * 5)) * 0.06),
				}),
				h("textlabel", {
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					Text: "VAULT FULL",
					TextColor3: P.mango,
					TextSize: 12,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				}),
			),
		);
	}
	if (plan.buffs.size() > 0) {
		items.sep2 = Separator(nextOrder());
	}
	for (const [index, buff] of pairs(plan.buffs)) {
		items[buff.key] = h(
			BuffCell,
			{
				buff,
				Size: UDim2.fromOffset(BUFF_W, COMPACT_H),
				LayoutOrder: nextOrder(),
				BackgroundTransparency: 1,
			},
			h(Icon, {
				kind: buff.icon,
				color: P.cream,
				accent: buff.color,
				size: 18,
				anchorPoint: new Vector2(0, 0.5),
				position: new UDim2(0, 0, 0.5, 0), // icons hold still (ICON_MOTION)
				spin: false,
			}),
			h(
				"textlabel",
				{
					Size: new UDim2(1, -22, 1, 0),
					Position: UDim2.fromOffset(22, 0),
					BackgroundTransparency: 1,
					Text: buff.value,
					TextColor3: theme.lighten(buff.color, 0.35),
					TextSize: 12,
					TextScaled: true,
					TextWrapped: false,
					TextXAlignment: Enum.TextXAlignment.Left,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				},
				h("uitextsizeconstraint", { MaxTextSize: 12, MinTextSize: 11 }),
			),
			buff.endsAt !== undefined &&
				buff.duration !== undefined &&
				h(
					"frame",
					{
						// time left on a running buff
						Size: new UDim2(1, -4, 0, 2),
						Position: new UDim2(0, 0, 1, -7),
						BackgroundColor3: P.line,
						BorderSizePixel: 0,
					},
					h("frame", {
						Size: props.clock.map(() => {
							const left = (tonumber(buff.endsAt) ?? 0) - Workspace.GetServerTimeNow();
							return UDim2.fromScale(math.clamp(left / math.max(1, buff.duration!), 0, 1), 1);
						}),
						BackgroundColor3: buff.color,
						BorderSizePixel: 0,
					}),
				),
		);
	}
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, COMPACT_H),
			BackgroundTransparency: 1,
			Position: arrive.map((t) => UDim2.fromOffset(0, (1 - t) * 6)),
			ZIndex: 62,
		},
		items,
	);
}

const SECTION_HEAD = 24;

function sectionHeight(rows: number): number {
	return SECTION_HEAD + rows * ROW_H + 6;
}

function expandedHeight(props: IslandProps, buffs: BuffInfo[]): number {
	let height = 10 + COMPACT_H;
	if (props.currencies !== undefined && props.currencies.size() > 0) {
		height += sectionHeight(props.currencies.size());
	}
	if (props.perf !== undefined && (props.perf.showFps === true || props.perf.showPing === true)) {
		height += sectionHeight(1);
	}
	if (buffs.size() > 0) {
		height += sectionHeight(buffs.size());
	}
	return height + 8;
}

function Row(
	order: number,
	color: Color3,
	icon: string,
	name: string,
	value: string | React.Binding<string>,
	valueColor: Color3,
	extra?: React.Element | false,
	onClick?: () => void,
): React.Element {
	return h(
		onClick !== undefined ? "textbutton" : "frame",
		{
			Size: new UDim2(1, 0, 0, ROW_H),
			LayoutOrder: order,
			BackgroundTransparency: 1,
			Text: onClick !== undefined ? "" : undefined,
			AutoButtonColor: onClick !== undefined ? false : undefined,
			Event: onClick !== undefined ? { Activated: onClick } : undefined,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(28, 28),
				Position: new UDim2(0, 0, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: theme.darken(color, 0.62),
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(0, 9) }),
			h("uistroke", { Color: color, Thickness: 1, Transparency: 0.6, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
			h(Icon, {
				kind: icon,
				color: P.cream,
				accent: color,
				size: 18,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h("textlabel", {
			Size: new UDim2(1, -174, 0, 18),
			Position: new UDim2(0, 40, 0, extra !== undefined && extra !== false ? 3 : 11),
			BackgroundTransparency: 1,
			Text: name,
			TextColor3: P.cream,
			TextSize: 14,
			TextXAlignment: Enum.TextXAlignment.Left,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
		}),
		h(
			"textlabel",
			{
				Size: UDim2.fromOffset(130, 18),
				Position: new UDim2(1, -130, 0, extra !== undefined && extra !== false ? 3 : 11),
				BackgroundTransparency: 1,
				Text: value,
				TextColor3: valueColor,
				TextSize: 13,
				TextScaled: true,
				TextWrapped: false,
				TextXAlignment: Enum.TextXAlignment.Right,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			},
			h("uitextsizeconstraint", { MaxTextSize: 13, MinTextSize: 11 }),
		),
		extra !== undefined && extra !== false ? extra : undefined,
	);
}

function SectionTitle(order: number, text: string): React.Element {
	return h("textlabel", {
		Size: new UDim2(1, 0, 0, SECTION_HEAD),
		LayoutOrder: order,
		BackgroundTransparency: 1,
		Text: text,
		TextColor3: P.muted,
		TextSize: 11,
		TextXAlignment: Enum.TextXAlignment.Left,
		TextYAlignment: Enum.TextYAlignment.Bottom,
		FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
	});
}

interface PerfRowsProps {
	order: number;
	showFps?: boolean;
	showPing?: boolean;
}

function PerfRows(props: PerfRowsProps): React.Element {
	const telemetry = telemetryHook();
	const fps = math.max(0, math.floor(telemetry.fps + 0.5));
	const ping = telemetry.pingMs !== undefined ? math.max(0, math.floor(telemetry.pingMs + 0.5)) : undefined;
	const label: string[] = [];
	if (props.showFps === true) {
		label.push(`${fps} fps`);
	}
	if (props.showPing === true) {
		label.push(ping !== undefined ? `${ping} ms ping` : "measuring ping");
	}
	const smooth = fps >= 54 && (ping === undefined || ping <= 85);
	return Row(
		props.order,
		fpsColor(fps),
		"Timer",
		smooth ? "Smooth" : "A bit slow",
		label.join("  ·  "),
		smooth ? P.mint : P.mango,
	);
}

interface ExpandedListProps {
	buffs: BuffInfo[];
	currencies?: CurrencyEntry[];
	perf?: PerfFlags;
	rate?: unknown;
	navigate?: (destination: string) => void;
	clock: React.Binding<number>;
}

// an expanded panel under the capsule: one row per thing, stacked and calm
function ExpandedList(props: ExpandedListProps): React.Element {
	const arrive = useArrive("expanded");
	const rows: Record<string, React.Element> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			Padding: new UDim(0, 0),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
		pad: h("uipadding", {
			PaddingLeft: new UDim(0, 16),
			PaddingRight: new UDim(0, 16),
			PaddingTop: new UDim(0, 2),
		}),
	};
	let order = 0;
	const nextOrder = () => {
		order += 1;
		return order;
	};
	if (props.currencies !== undefined && props.currencies.size() > 0) {
		rows.balanceTitle = SectionTitle(nextOrder(), "Your balance");
		for (const currency of props.currencies) {
			const rate =
				currency.target === "FLUX" && props.rate !== undefined ? `  +${format.compactNumber(props.rate)}/s` : "";
			const destination =
				currency.target === "FLUX" ? "Workshop" : currency.target === "DUST" ? "StarGrid" : "Overview";
			rows[`c${currency.target}`] = Row(
				nextOrder(),
				currency.color ?? P.mango,
				currency.icon ?? "Flux.1",
				currency.name ?? currency.target,
				format.compactNumber(currency.value) + rate,
				theme.lighten(currency.color ?? P.mango, 0.3),
				undefined,
				props.navigate !== undefined ? () => props.navigate!(destination) : undefined,
			);
		}
	}
	if (props.perf !== undefined && (props.perf.showFps === true || props.perf.showPing === true)) {
		rows.perfTitle = SectionTitle(nextOrder(), "Connection");
		rows.perf = h(PerfRows, { order: nextOrder(), showFps: props.perf.showFps, showPing: props.perf.showPing });
	}
	if (props.buffs.size() > 0) {
		rows.buffTitle = SectionTitle(nextOrder(), "Active boosts");
		for (const buff of props.buffs) {
			const timed = buff.endsAt !== undefined;
			rows[buff.key] = Row(
				nextOrder(),
				buff.color,
				buff.icon,
				buff.name,
				timed
					? props.clock.map(() => {
							return `${buff.value}  ·  ${clockText((tonumber(buff.endsAt) ?? 0) - Workspace.GetServerTimeNow())}`;
						})
					: buff.value,
				theme.lighten(buff.color, 0.35),
				timed && buff.duration !== undefined
					? h(
							"frame",
							{
								Size: new UDim2(1, -36, 0, 3),
								Position: new UDim2(0, 36, 0, 25),
								BackgroundColor3: P.line,
								BorderSizePixel: 0,
							},
							h("uicorner", { CornerRadius: new UDim(1, 0) }),
							h(
								"frame",
								{
									Size: props.clock.map(() => {
										const left = (tonumber(buff.endsAt) ?? 0) - Workspace.GetServerTimeNow();
										return UDim2.fromScale(math.clamp(left / math.max(1, buff.duration!), 0, 1), 1);
									}),
									BackgroundColor3: buff.color,
									BorderSizePixel: 0,
								},
								h("uicorner", { CornerRadius: new UDim(1, 0) }),
							),
						)
					: undefined,
				buff.key === "event"
					? () => {
							// the live event row opens the event's own panel
							const [ok, events] = pcall(() => {
								return (
									require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as (
										name: string,
									) => unknown
								)("serverEventsUi") as { openServerEventPanel?: () => void } | undefined;
							});
							if (ok && events !== undefined && events.openServerEventPanel !== undefined) {
								events.openServerEventPanel();
							}
						}
					: props.navigate !== undefined
						? () => props.navigate!("Boosts")
						: undefined,
			);
		}
	}
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 1, -(COMPACT_H + 6)),
			Position: arrive.map((t) => UDim2.fromOffset(0, COMPACT_H + 6 + (1 - t) * 8)),
			BackgroundTransparency: 1,
			ZIndex: 62,
		},
		h("frame", {
			Size: new UDim2(1, -32, 0, 1),
			Position: UDim2.fromOffset(16, 0),
			BackgroundColor3: P.line,
			BackgroundTransparency: 0.4,
			BorderSizePixel: 0,
		}),
		h("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1 }, rows),
	);
}
interface IslandNotice {
	title: string;
	subtitle?: string;
	color: Color3;
	icon?: string;
	duration?: number;
	tone?: string;
	style: string;
	count: number;
	token?: number;
	hold?: number;
	startedAt?: number;
	width?: number;
	lines?: number;
	height?: number;
}

// how an announcement moves depends on what it says: errors shake, good news pops, milestones glow
function toneMotion(
	info: IslandNotice,
	arrive: React.Binding<number>,
	clock: React.Binding<number>,
): UDim2 | React.Binding<UDim2> {
	const tone = info.tone;
	if (tone === "error" || tone === "Error" || tone === "Warning") {
		return arrive.map((t) => {
			const fade = 1 - math.clamp(t, 0, 1);
			return UDim2.fromOffset(math.sin(t * 38) * 7 * fade, 0);
		});
	}
	return UDim2.fromOffset(0, 0);
}

// toast spacing (uirevamp): one edge inset shared by Announcement and LiveActivity, text starts
// a clear gap after the icon. measureEvent sizes the island from the same numbers.
const TOAST_INSET = 16;
const TOAST_TEXT_X = { moment: 88, notice: 68, pill: 52 } as const;
const LIVE_ICON = 32;
const LIVE_TEXT_X = 12 + LIVE_ICON + 12;

interface AnnouncementProps {
	info: IslandNotice;
	token?: unknown;
	clock: React.Binding<number>;
	queued?: number;
}

function Announcement(props: AnnouncementProps): React.Element {
	const info = props.info;
	const arrive = useArrive(props.token);
	const clock = props.clock;
	const style = info.style || "notice";
	const moment = style === "moment";
	const pill = style === "pill";
	const iconBox = moment ? 52 : pill ? 28 : 38;
	const textX = moment ? TOAST_TEXT_X.moment : pill ? TOAST_TEXT_X.pill : TOAST_TEXT_X.notice;
	const startedAt = info.startedAt ?? os.clock();
	const hold = math.max(0.5, info.hold ?? 2.6);
	const titleColor = moment ? undefined : new ColorSequence(theme.lighten(info.color, 0.45), info.color);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			Position: toneMotion(info, arrive, clock),
			BackgroundTransparency: 1,
			ZIndex: 62,
		},
		moment &&
			h(
				"frame",
				{
					// a wash of colour that breathes behind a milestone
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: P.white,
					BackgroundTransparency: clock.map((t) => 0.9 + math.sin(t * 2.4) * 0.03),
					BorderSizePixel: 0,
					ZIndex: 61,
				},
				h("uigradient", {
					Color: Rainbow.SOFT,
					Rotation: clock.map((t) => Rainbow.spin(t, 6)),
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 0.2),
						new NumberSequenceKeypoint(0.5, 0.75),
						new NumberSequenceKeypoint(1, 0.2),
					]),
				}),
			),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(iconBox, iconBox),
				Position: new UDim2(0, pill ? 12 : TOAST_INSET, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: theme.darken(info.color, 0.55),
				BorderSizePixel: 0,
				ZIndex: 63,
				Rotation: 0, // icons hold still (ICON_MOTION)
			},
			// the icon plate holds still (no pop-in); the toast's slide and fade carry the arrival
			h("uicorner", { CornerRadius: new UDim(pill ? 1 : 0, pill ? 0 : moment ? 16 : 12) }),
			h(
				"uistroke",
				{
					Color: moment ? P.white : theme.lighten(info.color, 0.25),
					Thickness: moment ? 2 : 1.5,
					Transparency: 0.15,
				},
				moment &&
					h("uigradient", {
						Color: Rainbow.LOOP,
						Rotation: clock.map((t) => Rainbow.spin(t, 1.6)),
					}),
			),
			h(Icon, {
				kind: info.icon ?? "Boost.5",
				color: P.white,
				accent: info.color,
				size: math.floor(iconBox * 0.58),
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -(textX + TOAST_INSET), 0, moment ? 30 : pill ? 20 : 22),
				Position: arrive.map((t) => {
					const y = pill ? 12 : moment ? (info.subtitle !== undefined ? 16 : 33) : info.subtitle !== undefined ? 10 : 20;
					return new UDim2(0, textX + (1 - t) * 12, 0, y);
				}),
				BackgroundTransparency: 1,
				Text: (info.count ?? 1) > 1 ? `${info.title}  ×${info.count}` : info.title,
				TextColor3: P.white,
				TextTransparency: arrive.map((t) => 1 - t),
				TextSize: moment ? 26 : pill ? 15 : 16,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 63,
				TextScaled: true,
				TextWrapped: false,
				TextTruncate: Enum.TextTruncate.AtEnd,
			},
			h("uigradient", {
				Color: moment ? clock.map((t) => Rainbow.at(t * 0.35, 0.45, 1)) : titleColor,
				Rotation: moment ? 0 : 90,
			}),
			h("uitextsizeconstraint", { MaxTextSize: moment ? 26 : pill ? 15 : 16, MinTextSize: 11 }),
		),
		info.subtitle !== undefined &&
			!pill &&
			h("textlabel", {
				Size: new UDim2(1, -(textX + TOAST_INSET), 0, 16 * (info.lines ?? 1)),
				Position: arrive.map((t) => new UDim2(0, textX + (1 - t) * 18, 0, moment ? 50 : 33)),
				BackgroundTransparency: 1,
				Text: info.subtitle,
				TextColor3: P.creamSoft,
				TextTransparency: arrive.map((t) => 1 - t),
				TextSize: moment ? 14 : 13,
				TextXAlignment: Enum.TextXAlignment.Left,
				TextYAlignment: Enum.TextYAlignment.Top,
				TextWrapped: (info.lines ?? 1) > 1,
				TextTruncate: Enum.TextTruncate.AtEnd,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				ZIndex: 63,
			}),
		!pill &&
			h(
				"frame",
				{
					// how long this stays up: a thin line that drains along the bottom edge
					Size: new UDim2(1, -TOAST_INSET * 2 - 16, 0, 2),
					Position: new UDim2(0, TOAST_INSET + 8, 1, -6),
					BackgroundColor3: P.white,
					BackgroundTransparency: 0.88,
					BorderSizePixel: 0,
					ZIndex: 63,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h(
					"frame",
					{
						Size: clock.map(() => {
							return UDim2.fromScale(1 - math.clamp((os.clock() - startedAt) / hold, 0, 1), 1);
						}),
						BackgroundColor3: moment ? P.white : info.color,
						BackgroundTransparency: 0.15,
						BorderSizePixel: 0,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					moment && h("uigradient", { Color: Rainbow.LOOP }),
				),
			),
		(props.queued ?? 0) > 0 &&
			h(
				"textlabel",
				{
					// more waiting behind this one
					Size: UDim2.fromOffset(28, 18),
					Position: new UDim2(1, -10, 0, 8),
					AnchorPoint: new Vector2(1, 0),
					BackgroundColor3: P.white,
					BackgroundTransparency: 0.86,
					Text: `+${props.queued}`,
					TextColor3: P.creamSoft,
					TextSize: 11,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
					ZIndex: 64,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
	);
}

interface ComboInfo {
	count: number;
	multiplier?: number;
	max?: number;
	window: number;
	at: number;
}

interface ComboActivityProps {
	combo: ComboInfo;
	clock: React.Binding<number>;
}

// a live combo: the island widens into a meter that drains until the combo window runs out
function ComboActivity(props: ComboActivityProps): React.Element {
	const combo = props.combo;
	const arrive = useArrive(`combo${tostring(combo.count)}`);
	const hot = combo.count >= (combo.max ?? 12);
	const color = hot ? P.coral : P.mango;
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			ZIndex: 62,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(30, 30),
				Position: new UDim2(0, 10, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: theme.darken(color, 0.55),
				BorderSizePixel: 0,
				ZIndex: 63,
				Rotation: 0, // icons hold still (ICON_MOTION)
			},
			// the icon plate holds still (no pop-in)
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(Icon, {
				kind: "Overcharge.1",
				color: P.white,
				accent: color,
				size: 20,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h(
			"textlabel",
			{
				Size: UDim2.fromOffset(150, 20),
				Position: UDim2.fromOffset(48, 4),
				BackgroundTransparency: 1,
				Text: hot ? `MAX COMBO x${combo.count}` : `COMBO x${combo.count}`,
				TextColor3: theme.lighten(color, 0.35),
				TextSize: 16,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 63,
			},
			h("uiscale", { Scale: arrive.map((t) => 0.8 + easeOutBack(t) * 0.2) }),
		),
		h("textlabel", {
			Size: UDim2.fromOffset(120, 18),
			Position: new UDim2(1, -132, 0, 5),
			BackgroundTransparency: 1,
			Text: `${string.format("%.2f", combo.multiplier ?? 1)}x taps`,
			TextColor3: P.creamSoft,
			TextSize: 13,
			TextXAlignment: Enum.TextXAlignment.Right,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
			ZIndex: 63,
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, -60, 0, 5),
				Position: new UDim2(0, 48, 1, -12),
				BackgroundColor3: P.line,
				BorderSizePixel: 0,
				ZIndex: 63,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(
				"frame",
				{
					Size: props.clock.map(() => {
						const left = combo.at + (combo.window ?? 1.8) - os.clock();
						return UDim2.fromScale(math.clamp(left / (combo.window ?? 1.8), 0, 1), 1);
					}),
					BackgroundColor3: color,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uigradient", { Color: new ColorSequence(theme.lighten(color, 0.4), color) }),
			),
		),
	);
}

// an announcement is only as wide as its words; a long line wraps onto a second row

interface LiveInfo {
	key?: string;
	title?: string;
	icon?: string;
	color?: Color3;
	value?: unknown;
	endsAt?: number;
	serverEndsAt?: number;
	span?: number;
	progress?: number;
	priority?: number;
	updatedAt?: number;
	ttl?: number;
	left?: number;
}

interface LiveActivityProps {
	live: LiveInfo;
	clock: React.Binding<number>;
}

// a pinned live readout (Juice.live): icon, what is happening, its value and a draining/filling bar
function LiveActivity(props: LiveActivityProps): React.Element {
	const live = props.live;
	const arrive = useArrive(`${live.key ?? ""}${tostring(live.updatedAt)}`);
	const color = live.color ?? P.mango;
	const remaining = (): number | undefined => {
		if (live.serverEndsAt !== undefined) {
			return live.serverEndsAt - Workspace.GetServerTimeNow();
		} else if (live.endsAt !== undefined) {
			return live.endsAt - os.clock();
		}
		return undefined;
	};
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			ZIndex: 62,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(LIVE_ICON, LIVE_ICON),
				Position: new UDim2(0, 12, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: theme.darken(color, 0.55),
				BorderSizePixel: 0,
				ZIndex: 63,
			},
			// the icon plate holds still (no pop-in)
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: color,
				Thickness: 1.5,
				Transparency: props.clock.map((t) => 0.2 + (math.sin(t * 5) + 1) * 0.2),
			}),
			h(Icon, {
				kind: live.icon ?? "Boost.6",
				color: P.white,
				accent: color,
				size: 19,
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
				spin: false,
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -(LIVE_TEXT_X + 104), 0, 18),
				Position: arrive.map((t) => UDim2.fromOffset(LIVE_TEXT_X + (1 - t) * 10, 6)),
				BackgroundTransparency: 1,
				Text: live.title ?? "",
				TextColor3: theme.lighten(color, 0.35),
				TextTransparency: arrive.map((t) => 1 - t),
				TextScaled: true,
				TextXAlignment: Enum.TextXAlignment.Left,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 63,
			},
			h("uitextsizeconstraint", { MaxTextSize: 15, MinTextSize: 11 }),
		),
		h(
			"textlabel",
			{
				Size: UDim2.fromOffset(88, 18),
				Position: new UDim2(1, -(88 + TOAST_INSET), 0, 6),
				BackgroundTransparency: 1,
				Text: props.clock.map(() => {
					const left = remaining();
					if (live.value !== undefined) {
						return tostring(live.value);
					}
					return left !== undefined ? clockText(math.max(0, left)) : "";
				}),
				TextColor3: P.cream,
				TextScaled: true,
				TextXAlignment: Enum.TextXAlignment.Right,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				ZIndex: 63,
			},
			h("uitextsizeconstraint", { MaxTextSize: 14, MinTextSize: 11 }),
		),
		h(
			"frame",
			{
				Size: new UDim2(1, -(LIVE_TEXT_X + TOAST_INSET), 0, 4),
				Position: new UDim2(0, LIVE_TEXT_X, 1, -12),
				BackgroundColor3: P.line,
				BorderSizePixel: 0,
				ZIndex: 63,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(
				"frame",
				{
					Size: props.clock.map(() => {
						let fill = live.progress;
						if (fill === undefined) {
							const left = remaining();
							fill = left !== undefined && live.span !== undefined ? left / live.span : 1;
						}
						return UDim2.fromScale(math.clamp(fill, 0, 1), 1);
					}),
					BackgroundColor3: color,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uigradient", { Color: new ColorSequence(theme.lighten(color, 0.45), color) }),
			),
		),
	);
}

function textWidth(text: string, size: number, font: Enum.Font): number {
	const [ok, bounds] = pcall(() => TextService.GetTextSize(text, size, font, new Vector2(4000, 100)));
	return ok && bounds !== undefined ? bounds.X : text.size() * size * 0.55;
}

function measureEvent(info: IslandNotice, maxWidth?: number) {
	const cap = math.min(maxWidth ?? 560, 560);
	const style = info.style || "notice";
	if (style === "pill") {
		const titleW = textWidth(info.title ?? "", 15, Enum.Font.BuilderSansExtraBold);
		info.width = math.clamp(math.ceil(TOAST_TEXT_X.pill + TOAST_INSET + titleW), 150, cap);
		info.lines = 1;
		info.height = COMPACT_H;
		return;
	}
	const moment = style === "moment";
	const textX = moment ? TOAST_TEXT_X.moment : TOAST_TEXT_X.notice;
	const titleW = textWidth(info.title ?? "", moment ? 26 : 16, Enum.Font.BuilderSansExtraBold);
	const subtitleW =
		info.subtitle !== undefined ? textWidth(info.subtitle, moment ? 14 : 13, Enum.Font.BuilderSansBold) : 0;
	const width = math.clamp(math.ceil(textX + TOAST_INSET + 8 + math.max(titleW, math.min(subtitleW, 400))), moment ? 320 : 240, cap);
	const room = math.max(80, width - textX - TOAST_INSET - 8);
	info.width = width;
	info.lines = subtitleW > room ? 2 : 1;
	info.height = (moment ? 92 : EVENT_H) + 16 * (info.lines - 1);
}

// props: state, config, currencies { {target, name, value, icon, color} }, perf { showFps, showPing },
// rate (flux per second), vaultFull, navigate, maxWidth, position, anchorPoint, restHidden, reducedMotion
function lastInputIsMouse(): boolean {
	const inputType = game.GetService("UserInputService").GetLastInputType();
	return (
		inputType === Enum.UserInputType.MouseMovement ||
		inputType === Enum.UserInputType.MouseButton1 ||
		inputType === Enum.UserInputType.MouseButton2 ||
		inputType === Enum.UserInputType.MouseWheel
	);
}

BuffStrip.Island = function (islandProps: IslandProps): React.Element {
	// live currency values and vault-full flag (B35): this island redraws on a cash tick, the top bar doesn't
	let liveKey: string | undefined;
	for (const currency of islandProps.currencies ?? []) {
		if (currency.liveKey !== undefined) liveKey = currency.liveKey;
	}
	const liveValue = useLiveSessionValue(liveKey);
	const liveVaultFull = useLiveVaultFull(islandProps.liveVaultFull === true);
	const props: IslandProps =
		liveKey === undefined && islandProps.liveVaultFull !== true
			? islandProps
			: {
					...islandProps,
					currencies: islandProps.currencies?.map((currency) =>
						currency.liveKey !== undefined ? { ...currency, value: liveValue } : currency,
					),
					vaultFull: islandProps.liveVaultFull === true ? liveVaultFull : islandProps.vaultFull,
				};
	const clock = motion.useClock(true, 1, 3600, true);
	const now = Workspace.GetServerTimeNow();
	const buffs = BuffStrip.list(props.state, props.config, now);
	const maxWidth = props.maxWidth ?? 640;
	const plan = planCompact(props, buffs);
	const [hovered, setHovered] = React.useState(false);
	const [pinned, setPinned] = React.useState(false);
	// what the shared player (JuiceFx) is showing; the queue and its clock live there, so this
	// island can remount, or sit beside another island, and never lose or repeat a message
	const [live, setLive] = React.useState<IslandNotice | undefined>(undefined);
	const [queued, setQueued] = React.useState(0);
	const islandRef = React.useRef<GuiObject>(undefined);
	// the island docks in the top bar but opens over the page: it is its own floating layer
	React.useEffect(() => {
		islandRef.current?.SetAttribute("LayoutFloating", true);
	}, []);
	React.useEffect(() => {
		return Juice.subscribeIsland((current, waiting) => {
			setLive(current !== undefined ? (table.clone(current) as IslandNotice) : undefined);
			setQueued(waiting);
		});
	}, []);
	// sized for this island's room (a copy: other islands may have a different width)
	const event = React.useMemo(() => {
		if (live === undefined) {
			return undefined;
		}
		const shown = table.clone(live);
		const [ok] = pcall(() => measureEvent(shown, maxWidth));
		if (!ok) {
			shown.width = math.min(maxWidth, 420);
			shown.lines = 1;
			shown.height = EVENT_H;
		}
		return shown;
	}, [live, maxWidth]);
	// every new message sheds a few embers off the bottom edge
	React.useEffect(() => {
		if (live === undefined) {
			return undefined;
		}
		const job = task.delay(0.08, () => {
			const island = islandRef.current;
			if (island !== undefined && island.Parent !== undefined && island.AbsoluteSize.X > 40 && !props.reducedMotion) {
				const p = island.AbsolutePosition;
				const sz = island.AbsoluteSize;
				for (let index = 1; index <= 3; index++) {
					const x = p.X + sz.X * (0.2 + 0.3 * (index - 1) + math.random() * 0.1);
					Juice.spark(new Vector2(x, p.Y + sz.Y + 2), theme.lighten(live.color ?? P.mango, 0.4), 12 + math.random() * 8);
				}
			}
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [live !== undefined ? live.token : undefined]);
	// a milestone throws sparks out of the island as it opens
	React.useEffect(() => {
		if (live === undefined || live.style !== "moment") {
			return undefined;
		}
		const job = task.delay(0.12, () => {
			const island = islandRef.current;
			if (island !== undefined && island.Parent !== undefined && island.AbsoluteSize.X > 4) {
				Juice.burst(island.AbsolutePosition.add(island.AbsoluteSize.div(2)), live.color, 0.9);
			}
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [live !== undefined ? live.token : undefined]);
	// hover is read from the pointer itself: enter/leave events go stale when the capsule
	// changes size under the cursor, and touch never sends a leave
	React.useEffect(() => {
		const UserInputService = game.GetService("UserInputService");
		const GuiService = game.GetService("GuiService");
		let wait = 0;
		let last = false;
		const connection = game.GetService("RunService").Heartbeat.Connect((dt) => {
			wait += dt;
			if (wait < 0.1) {
				return;
			}
			wait = 0;
			const island = islandRef.current;
			let over = false;
			if (island !== undefined && island.Parent !== undefined && lastInputIsMouse()) {
				const screenGui = island.FindFirstAncestorOfClass("ScreenGui");
				const [guiInset] = GuiService.GetGuiInset();
				const inset =
					screenGui !== undefined && screenGui.IgnoreGuiInset ? Vector2.zero : guiInset;
				const mouse = UserInputService.GetMouseLocation().sub(inset);
				const topLeft = island.AbsolutePosition;
				const size = island.AbsoluteSize;
				// a little slack once inside so the edge doesn't flicker
				const slack = last ? 10 : 0;
				over =
					size.X > 4 &&
					mouse.X >= topLeft.X - slack &&
					mouse.X <= topLeft.X + size.X + slack &&
					mouse.Y >= topLeft.Y - slack &&
					mouse.Y <= topLeft.Y + size.Y + slack;
			}
			if (over !== last) {
				last = over;
				setHovered(over);
			}
		});
		// a tap anywhere else lets go of a pinned island
		const began = UserInputService.InputBegan.Connect((input) => {
			if (input.UserInputType !== Enum.UserInputType.MouseButton1 && input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			const island = islandRef.current;
			if (island === undefined) {
				return;
			}
			const p = input.Position;
			const topLeft = island.AbsolutePosition;
			const size = island.AbsoluteSize;
			const inside =
				p.X >= topLeft.X && p.X <= topLeft.X + size.X && p.Y >= topLeft.Y && p.Y <= topLeft.Y + size.Y;
			if (!inside) {
				setPinned(false);
				// touch has no hover: a tap elsewhere also drops the hover that a tap on the island
				// raised through MouseEnter (the poll above only tracks a real mouse)
				if (input.UserInputType === Enum.UserInputType.Touch) {
					last = false;
					setHovered(false);
				}
			}
		});
		return () => {
			connection.Disconnect();
			began.Disconnect();
		};
	}, []);
	// live activity: the overcharge combo
	const [combo, setCombo] = React.useState<ComboInfo | undefined>(undefined);
	React.useEffect(() => {
		let expiry: thread | undefined;
		const stop = Juice.onActivity((kind, data) => {
			if (kind === "combo" && typeIs(data, "table")) {
				const bag = data as Record<string, unknown>;
				const entry: ComboInfo = {
					count: (bag.combo as number | undefined) ?? 0,
					multiplier: bag.multiplier as number | undefined,
					max: bag.max as number | undefined,
					window: (bag.window as number | undefined) ?? 1.8,
					at: os.clock(),
				};
				setCombo(entry);
				if (expiry !== undefined) {
					pcall(task.cancel, expiry);
				}
				expiry = task.delay(entry.window + 0.15, () => {
					expiry = undefined;
					setCombo((current) => (current === entry ? undefined : current));
				});
			}
		});
		return () => {
			stop();
			if (expiry !== undefined) {
				pcall(task.cancel, expiry);
				expiry = undefined;
			}
		};
	}, []);
	// arrivals and departures pass through the island; a friend gets their own colour
	React.useEffect(() => {
		const Players = game.GetService("Players");
		const announce = (player: Player, arriving: boolean) => {
			if (player === Players.LocalPlayer || player.UserId === 771133001) {
				// 771133001: the Studio test bot
				return;
			}
			task.spawn(() => {
				const [okFriend, friend] = pcall(() => {
					return Players.LocalPlayer.IsFriendsWith(player.UserId as unknown as User);
				});
				const isFriend = okFriend && friend === true;
				const name = player.DisplayName;
				if (arriving) {
					Juice.banner(
						isFriend ? `Your friend ${name} is here` : `${name} joined`,
						undefined,
						isFriend ? P.mint : P.cyan,
						"Wave.1",
						1.6,
						"Info",
						"pill",
					);
				} else {
					Juice.banner(`${name} left`, undefined, P.muted, "Wave.2", 1.3, "Info", "pill");
				}
			});
		};
		const joined = Players.PlayerAdded.Connect((player) => {
			announce(player, true);
		});
		const left = Players.PlayerRemoving.Connect((player) => {
			announce(player, false);
		});
		return () => {
			joined.Disconnect();
			left.Disconnect();
		};
	}, []);
	// pinned live readouts (Juice.live)
	const [liveEntry, setLiveEntry] = React.useState<LiveInfo | undefined>(undefined);
	React.useEffect(() => {
		return Juice.subscribeLive((top) => setLiveEntry(top as unknown as LiveInfo | undefined));
	}, []);
	// a timed buff in its last fifteen seconds counts down in the island on its own
	let ending: LiveInfo | undefined;
	for (const buff of buffs) {
		if (buff.endsAt !== undefined && buff.duration !== undefined) {
			const left = (tonumber(buff.endsAt) ?? 0) - now;
			if (left > 0 && left <= 15 && (ending === undefined || left < (ending.left ?? math.huge))) {
				ending = {
					key: `ending:${buff.key}`,
					title: `${string.upper(buff.name)} ENDING`,
					icon: buff.icon,
					color: buff.color,
					serverEndsAt: tonumber(buff.endsAt),
					span: 15,
					priority: 1,
					updatedAt: tonumber(buff.endsAt),
					left,
				};
			}
		}
	}
	const activity = liveEntry ?? ending;
	// a buff that just started announces itself
	const signature: string[] = [];
	for (const buff of buffs) {
		signature.push(buff.key);
	}
	const signatureText = signature.join(",");
	const seen = React.useRef<Record<string, BuffInfo> | undefined>(undefined);
	React.useEffect(() => {
		const current: Record<string, BuffInfo> = {};
		for (const buff of buffs) {
			current[buff.key] = buff;
		}
		if (seen.current !== undefined) {
			for (const [key, buff] of pairs(current)) {
				if (
					seen.current![key] === undefined &&
					(key === "boost" || key === "surge" || key === "event" || key === "forgeSurge")
				) {
					Juice.banner(`${string.upper(buff.name)} ON`, `${buff.value} production while it lasts`, buff.color, buff.icon);
				}
			}
		}
		seen.current = current;
	}, [signatureText]);

	const hasContent =
		plan.width > 30 &&
		((props.currencies !== undefined && props.currencies.size() > 0) || plan.buffs.size() > 0 || plan.perf);
	const comboLive = combo !== undefined && combo.count >= 2;
	const mode =
		event !== undefined
			? "event"
			: comboLive && !(hovered || pinned)
				? "combo"
				: activity !== undefined && !(hovered || pinned)
					? "live"
					: props.restHidden === true
						? "hidden"
						: hovered || pinned
							? "expanded"
							: hasContent
								? "compact"
								: "hidden";
	const compactW = math.min(maxWidth, plan.width);
	const targetW =
		mode === "event"
			? math.min(maxWidth, event!.width ?? 520)
			: mode === "combo"
				? math.min(maxWidth, 360)
				: mode === "live"
					? math.min(maxWidth, 380)
					: mode === "expanded"
						? math.min(maxWidth, math.max(420, compactW))
						: mode === "compact"
							? compactW
							: 0;
	const targetH =
		mode === "event"
			? event!.height ?? EVENT_H
			: mode === "combo" || mode === "live"
				? COMPACT_H + 4
				: mode === "expanded"
					? expandedHeight(props, buffs)
					: mode === "compact"
						? COMPACT_H
						: 0;
	// messages land with a liquid wobble; settling back to the compact bar is calmer
	const wobbly = mode === "event";
	const width = motion.useFlipperSpring(targetW, props.reducedMotion, wobbly ? 260 : 300, wobbly ? 17 : 24);
	const height = motion.useFlipperSpring(targetH, props.reducedMotion, wobbly ? 280 : 300, wobbly ? 16 : 24);
	// a combo that is still running when a message arrives splits off into a bubble beside it
	const satelliteOn = mode === "event" && comboLive;
	const satellite = motion.useFlipperSpring(satelliteOn ? 1 : 0, props.reducedMotion, 340, 20);
	// jelly: each change of shape lands with a small squash and settles
	const modeKey =
		mode + (event !== undefined ? tostring(event.token) : "") + (combo !== undefined ? tostring(combo.count) : "");
	const jelly = motion.useFlash(modeKey as unknown as number, props.reducedMotion, 0.5);
	const glow = motion.usePulse(true, props.vaultFull === true ? 3.2 : 1.6);
	const accent =
		event !== undefined
			? event.color
			: mode === "combo"
				? P.mango
				: mode === "live"
					? activity!.color ?? P.mango
					: props.vaultFull === true
						? P.mango
						: Color3.fromRGB(150, 92, 52);
	const content =
		mode === "event"
			? h(Announcement, {
					key: `event${tostring(event!.token)}`,
					info: event!,
					token: event!.token,
					clock,
					queued,
				})
			: mode === "combo"
				? h(ComboActivity, { key: "combo", combo: combo!, clock })
				: mode === "live"
					? h(LiveActivity, { key: `live${activity!.key ?? ""}`, live: activity!, clock })
					: mode === "expanded"
						? h(
								React.Fragment,
								undefined,
								h(CompactRow, {
									key: "top",
									plan,
									currencies: props.currencies,
									perf: props.perf,
									vaultFull: props.vaultFull,
									clock,
									reducedMotion: props.reducedMotion,
								}),
								h(ExpandedList, {
									key: "list",
									buffs,
									currencies: props.currencies,
									perf: props.perf,
									rate: props.perf !== undefined ? props.rate : props.rate,
									navigate: props.navigate,
									clock,
								}),
							)
						: mode === "compact"
							? h(CompactRow, {
									key: "top",
									plan,
									currencies: props.currencies,
									perf: props.perf,
									vaultFull: props.vaultFull,
									clock,
									reducedMotion: props.reducedMotion,
								})
							: undefined;
	const momentRim = event !== undefined && event.style === "moment";
	const capsule = h(
		"imagebutton",
		{
			Name: "BuffIsland",
			ref: islandRef,
			Size: React.joinBindings([width, height]).map((values) => {
				return UDim2.fromOffset(math.max(0, values[0]), math.max(0, values[1]));
			}),
			Position: props.position,
			AnchorPoint: props.anchorPoint ?? new Vector2(0.5, 0),
			BackgroundColor3: Color3.fromRGB(6, 6, 10),
			BackgroundTransparency: 0.02,
			AutoButtonColor: false,
			Image: "",
			ClipsDescendants: true,
			Visible: width.map((v) => v > 4),
			ZIndex: 60,
			Event: {
				MouseEnter: () => {
					// touch fires MouseEnter on a tap; that's handled by pinning, not hover
					if (lastInputIsMouse()) {
						setHovered(true);
					}
				},
				Activated: () => {
					// tapping an announcement moves on to the next one
					if (event !== undefined) {
						Juice.skipIsland();
						return;
					}
					setPinned(!pinned);
				},
			},
		},
		h("uiscale", {
			Scale: jelly.map((v) => 1 + math.sin(v * math.pi) * 0.045),
		}),
		h("uicorner", {
			CornerRadius: new UDim(0, mode === "expanded" || mode === "event" ? 18 : 22),
		}),
		h(
			"uistroke",
			{
				Color: momentRim ? P.white : accent,
				Thickness: momentRim ? 2.5 : event !== undefined || props.vaultFull === true || mode === "combo" ? 2 : 1,
				Transparency: glow.map((v) =>
					event !== undefined || props.vaultFull === true || mode === "combo" || mode === "live"
						? 0.05 + v * 0.3
						: 0.3 + v * 0.2,
				),
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
			},
			momentRim
				? h("uigradient", {
						// a milestone's rim: the whole rainbow chasing round the capsule
						Color: Rainbow.LOOP,
						Rotation: clock.map((t) => Rainbow.spin(t, 1.4)),
					})
				: h("uigradient", {
						// molten rim: a band of heat travelling round the edge, quick when something is happening
						Color: new ColorSequence([
							new ColorSequenceKeypoint(0, theme.darken(accent, 0.35)),
							new ColorSequenceKeypoint(0.42, accent),
							new ColorSequenceKeypoint(0.5, theme.lighten(accent, 0.7)),
							new ColorSequenceKeypoint(0.58, accent),
							new ColorSequenceKeypoint(1, theme.darken(accent, 0.35)),
						]),
						Rotation: clock.map((t) => {
							const busy = event !== undefined || mode === "combo" || mode === "live";
							return (t * (busy ? 260 : 40)) % 360;
						}),
					}),
		),
		content,
	);
	const anchor = props.anchorPoint ?? new Vector2(0.5, 0);
	const base = props.position ?? new UDim2();
	const bubble = h(
		"frame",
		{
			Name: "IslandSatellite",
			Size: satellite.map((v) => {
				const d = math.max(0, v) * 40;
				return UDim2.fromOffset(d, d);
			}),
			// sits just off the capsule's right edge, sliding out of it as it splits
			Position: React.joinBindings([width, satellite]).map((values) => {
				const rightEdge = values[0] * (1 - anchor.X);
				return base.add(UDim2.fromOffset(rightEdge - 18 + values[1] * 28, 22));
			}),
			AnchorPoint: new Vector2(0, 0.5),
			BackgroundColor3: Color3.fromRGB(6, 6, 10),
			BorderSizePixel: 0,
			Visible: satellite.map((v) => v > 0.04),
			ZIndex: 60,
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h("uistroke", {
			Color: P.mango,
			Thickness: 2,
			Transparency: glow.map((v) => 0.1 + v * 0.3),
		}),
		h(
			"textlabel",
			{
				Size: UDim2.fromScale(0.8, 0.8),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				Text: combo !== undefined ? `x${combo.count}` : "",
				TextColor3: theme.lighten(P.mango, 0.35),
				TextScaled: true,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				ZIndex: 61,
			},
			h("uitextsizeconstraint", { MaxTextSize: 15, MinTextSize: 11 }),
		),
	);
	return h(React.Fragment, undefined, capsule, bubble);
};

export = BuffStrip;

