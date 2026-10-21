// Server events on screen: the island carries the live readout, the screen gets each event's own
// weather, Falling Stars and Supply Drop put things to grab on screen, and a panel explains the
// event in full with its live standings.
import React from "@rbxts/react";
import { compactNumber } from "../CoreKit/format";
import { darken, Palette, TapTarget } from "../CoreKit/theme";
import { Button } from "./ui";
import { useAntilag } from "../MotionKit/antilag";
import { revealOffset, usePresence, useViewport, useWallClock } from "../MotionKit/motion";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const RunService = game.GetService("RunService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;
const Icon = (loadKit("ArtKit")("Icon") as { Icon: unknown }).Icon;

interface JuiceFxModule {
	burst(this: void, at: Vector2, color: Color3, scale: number): void;
	number(this: void, text: string, color: Color3, opts: object): void;
	status(this: void, text: string, kind: string): void;
	moment(this: void, title: string, detail: unknown, color: Color3, icon: unknown): void;
	live: (this: void, key: string, value: object | undefined) => void;
}
const juice = () => require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;

export interface EventDef {
	Kind?: string;
	Accent?: string;
	Name: string;
	How: string;
	Icon?: string;
	MaxStars?: number;
	RewardFluxSeconds: number;
	RewardStardust: number;
	Drops?: { Dust?: number };
}

interface Standing {
	Name: string;
	Points?: unknown;
}

interface Drop {
	Id: number;
	At: number;
	EndsAt: number;
	Left: number;
	Mine?: boolean;
}

export interface ServerEvent {
	Id?: string;
	Phase?: string;
	PhaseEndsAt?: number;
	Progress?: number;
	Goal?: number;
	Completed?: boolean;
	Yours?: number;
	YourRank?: number;
	Tickets?: number;
	Pool?: number;
	Caught?: number;
	MaxStars?: number;
	Top?: Standing[];
	Winners?: Array<{ Name: string }>;
	Drops?: Drop[];
}

interface ServerEventsModule {
	EVENTS: Record<string, EventDef | undefined>;
	LIVE_SECONDS: number;
}

const ServerEvents = (
	require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript) as (
		name: string,
	) => unknown
)("ServerEvents") as ServerEventsModule;
const WHITE_HOT = Color3.fromRGB(255, 244, 222);

let latest: ServerEvent | undefined = undefined;
const listeners = new Set<(event: ServerEvent) => void>();
export function pushServerEvent(effect: unknown) {
	if (!typeIs(effect, "table") || !typeIs((effect as { Event?: unknown }).Event, "table")) {
		return;
	}
	latest = (effect as { Event: ServerEvent }).Event;
	for (const listener of listeners) {
		listener(latest);
	}
}
export function useServerEvent(fromSnapshot?: ServerEvent): ServerEvent | undefined {
	const [live, setLive] = React.useState(latest);
	React.useEffect(() => {
		const listener = (event: ServerEvent) => setLive(event);
		listeners.add(listener);
		return () => {
			listeners.delete(listener);
		};
	}, []);
	if (live !== undefined && (fromSnapshot === undefined || (live.PhaseEndsAt ?? 0) >= (fromSnapshot.PhaseEndsAt ?? 0))) {
		return live;
	}
	return fromSnapshot;
}

const panelOpeners = new Set<() => void>();
export function openServerEventPanel() {
	for (const opener of panelOpeners) {
		opener();
	}
}

export function clockText(seconds: number) {
	const total = math.max(0, math.floor(seconds));
	return string.format("%d:%02d", math.floor(total / 60), total % 60);
}
export function accentOf(def: EventDef | undefined): Color3 {
	return (Palette as unknown as Record<string, Color3 | undefined>)[(def && def.Accent) || "cyan"] ?? Palette.cyan;
}
function hash01(i: number, salt: number) {
	const x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
	return x - math.floor(x);
}
function easeOut(t: number) {
	const u = 1 - math.clamp(t, 0, 1);
	return 1 - u * u * u;
}
function serverNow() {
	return game.GetService("Workspace").GetServerTimeNow();
}

// what the island says about the event right now
function liveValue(event: ServerEvent, def: EventDef) {
	const kind = def.Kind;
	if (kind === "goal") {
		return `${math.floor((100 * (event.Progress ?? 0)) / math.max(1, event.Goal ?? 1))}%`;
	} else if (kind === "titan") {
		return `${compactNumber(math.max(0, (event.Goal ?? 0) - (event.Progress ?? 0)))} HP`;
	} else if (kind === "race") {
		return event.YourRank !== undefined ? `#${event.YourRank}` : "unranked";
	} else if (kind === "draw") {
		return `${event.Tickets ?? 0} tickets`;
	} else if (kind === "stars") {
		return `${event.Caught ?? 0}/${event.MaxStars ?? def.MaxStars}`;
	}
	return undefined;
}

// ------------------------------------------------------------------------------------------------
// weather: each event has its own sky; every particle is a pure function of one clock
// ------------------------------------------------------------------------------------------------
interface SkyStyle {
	kind: string;
	count: number;
	angle?: number;
	hot?: boolean;
	gold?: boolean;
}
const SKY: Record<string, SkyStyle | undefined> = {
	MeteorShower: { kind: "streak", count: 14, angle: 34 },
	StardustRain: { kind: "fall", count: 30 },
	CommunityForge: { kind: "rise", count: 10 },
	Overheat: { kind: "rise", count: 22, hot: true },
	CriticalMass: { kind: "spark", count: 16 },
	ComboFever: { kind: "pulse", count: 3 },
	TwinSuns: { kind: "suns", count: 2 },
	GoldenVault: { kind: "fall", count: 18, gold: true },
	CoreSeam: { kind: "rise", count: 12 },
	KeyCache: { kind: "fall", count: 10 },
	IronTitan: { kind: "streak", count: 6, angle: 80 },
	ForgeRace: { kind: "streak", count: 10, angle: 4 },
	LuckyDraw: { kind: "spark", count: 12 },
	FallingStars: { kind: "fall", count: 8 },
	SupplyDrop: { kind: "rise", count: 6 },
};

interface ParticleProps {
	index: number;
	style: SkyStyle;
	clock: React.Binding<number>;
	width: number;
	height: number;
	color: Color3;
}

function Particle(p: ParticleProps) {
	const [i, style, clock, w, ht, color] = [p.index, p.style, p.clock, p.width, p.height, p.color];
	if (style.kind === "streak") {
		const angle = style.angle!;
		const a = math.rad(angle);
		const [dx, dy] = [-math.cos(a), math.sin(a)];
		const len = 70 + hash01(i, 3) * 100;
		const period = 1.8 + hash01(i, 1) * 2;
		const sx = w * (0.15 + hash01(i, 5) * 1.1);
		const travel = math.max(w, ht) * 1.4;
		const at = (t: number): [number, number, number] => {
			const q = ((t + hash01(i, 2) * period) % period) / period / 0.6;
			return [sx + dx * travel * q, -60 + dy * travel * q, q];
		};
		return h(
			"frame",
			{
				Size: UDim2.fromOffset(len, hash01(i, 4) > 0.7 ? 3 : 2),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: 180 - angle,
				Position: clock.map((t) => {
					const [x, y] = at(t);
					return UDim2.fromOffset(x - (dx * len) / 2, y - (dy * len) / 2);
				}),
				Visible: clock.map((t) => at(t)[2] <= 1),
				BackgroundColor3: new Color3(1, 1, 1),
				BorderSizePixel: 0,
				ZIndex: 120,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uigradient", {
				Color: new ColorSequence(color, WHITE_HOT),
				Transparency: new NumberSequence([
					new NumberSequenceKeypoint(0, 1),
					new NumberSequenceKeypoint(0.7, 0.4),
					new NumberSequenceKeypoint(1, 0),
				]),
			}),
		);
	} else if (style.kind === "pulse") {
		// rings breathing out from the bottom corners: the beat you're keeping
		const period = 2.4;
		return h(
			"frame",
			{
				Size: clock.map((t) => {
					const q = ((t + (i * period) / 3) % period) / period;
					const s = 120 + q * math.max(w, ht) * 0.9;
					return UDim2.fromOffset(s, s);
				}),
				Position: UDim2.fromScale(i % 2 === 0 ? 0 : 1, 1),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 119,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: color,
				Thickness: 2,
				Transparency: clock.map((t) => 0.35 + (((t + (i * period) / 3) % period) / period) * 0.65),
			}),
		);
	} else if (style.kind === "suns") {
		const s = 260 - i * 70;
		return h(
			"frame",
			{
				Size: UDim2.fromOffset(s, s),
				Position: clock.map(
					(t) => new UDim2(i === 1 ? 0.12 : 0.88, math.sin(t * 0.3 + i) * 20, 0, -s * 0.25 + math.cos(t * 0.25 + i) * 10),
				),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: i === 1 ? Palette.mango : WHITE_HOT,
				BackgroundTransparency: 0.82,
				BorderSizePixel: 0,
				ZIndex: 118,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uigradient", {
				Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 1)]),
				Rotation: 90,
			}),
		);
	}
	// motes: falling (rain, gold, keys), rising (embers, heat) or flickering sparks
	const size = 2 + math.floor(hash01(i, 3) * 4);
	const period = 4 + hash01(i, 1) * 4;
	const baseX = w * hash01(i, 5);
	const rising = style.kind === "rise";
	const spark = style.kind === "spark";
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(size, size),
			AnchorPoint: new Vector2(0.5, 0.5),
			Rotation: spark ? 45 : 0,
			Position: clock.map((t) => {
				const q = ((t + hash01(i, 2) * period) % period) / period;
				if (spark) {
					return UDim2.fromOffset(baseX, ht * (0.1 + hash01(i, 7) * 0.8));
				}
				const y = rising ? ht + 10 - q * ht * 0.8 : -10 + q * (ht + 20);
				return UDim2.fromOffset(baseX + math.sin(t * 0.8 + i) * 18, y);
			}),
			BackgroundTransparency: clock.map((t) => {
				const q = ((t + hash01(i, 2) * period) % period) / period;
				if (spark) {
					return 0.2 + (math.sin(t * 7 + i * 2.3) + 1) * 0.4;
				}
				return math.clamp(0.25 + (rising ? q : math.max(0, (q - 0.8) / 0.2)) * 0.75, 0, 1);
			}),
			BackgroundColor3: style.gold ? Palette.mango : style.hot ? Palette.coral : color,
			BorderSizePixel: 0,
			ZIndex: 120,
		},
		!spark && h("uicorner", { CornerRadius: new UDim(1, 0) }),
	);
}

function Sky(props: { eventId?: string; clock: React.Binding<number>; color: Color3 }) {
	const style = SKY[props.eventId ?? ""];
	const viewport = useViewport();
	const antilag = useAntilag();
	const clock = props.clock;
	if (style === undefined) {
		return undefined;
	}
	const budget = antilag.tier <= 1 ? 0.45 : antilag.allowAmbient === false ? 0.7 : 1;
	const count = style.kind === "pulse" || style.kind === "suns" ? style.count : math.max(1, math.floor(style.count * budget));
	const particles: Record<string, unknown> = {};
	for (let i = 1; i <= count; i++) {
		particles["p" + i] = h(Particle, {
			index: i,
			style: style,
			clock: clock,
			width: viewport.width,
			height: viewport.height,
			color: props.color,
		});
	}
	return h("frame", { Name: "EventSky", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Active: false, ZIndex: 118 }, particles);
}

type Dispatch = (action: string, payload: object, callback?: (response: ActResponse) => void) => void;
interface ActResponse {
	ok?: boolean;
	message?: string;
	Dust?: number;
}

// ------------------------------------------------------------------------------------------------
// Falling Stars: stars cross the screen; a tap catches one (the server counts and pays)
// ------------------------------------------------------------------------------------------------
const STAR_SLOTS = 6;
const STAR_FLIGHT = 4.2;
function StarField(props: { clock: React.Binding<number>; dispatch: Dispatch }) {
	const viewport = useViewport();
	const clock = props.clock;
	const caught = React.useRef<Record<string, boolean | undefined>>({});
	const busy = React.useRef(false);
	const stars: Record<string, unknown> = {};
	for (let slot = 1; slot <= STAR_SLOTS; slot++) {
		const wave = (t: number): [number, number] => {
			// each slot launches a new star every flight, offset so they don't arrive together
			const n = math.floor((t + slot * 0.7) / STAR_FLIGHT);
			const q = ((t + slot * 0.7) % STAR_FLIGHT) / STAR_FLIGHT;
			return [n, q];
		};
		const place = (t: number): [number, number, number] => {
			const [n, q] = wave(t);
			const x0 = viewport.width * (0.08 + hash01(n * 7 + slot, 1) * 0.84);
			const drift = (hash01(n * 7 + slot, 2) - 0.5) * 220;
			return [x0 + drift * q, -40 + q * (viewport.height + 80), n];
		};
		stars["s" + slot] = h(
			"textbutton",
			{
				Size: UDim2.fromOffset(46, 46),
				AnchorPoint: new Vector2(0.5, 0.5),
				Position: clock.map((t) => {
					const [x, y] = place(t);
					return UDim2.fromOffset(x, y);
				}),
				Visible: clock.map((t) => {
					const n = place(t)[2];
					return !caught.current[`${slot}:${n}`];
				}),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				ZIndex: 140,
				Event: {
					Activated: (rbx: TextButton) => {
						const now = os.clock();
						const n = place(now)[2];
						const key = `${slot}:${n}`;
						if (caught.current[key] || busy.current) {
							return;
						}
						caught.current[key] = true;
						busy.current = true;
						const at = rbx.AbsolutePosition.add(rbx.AbsoluteSize.div(2));
						props.dispatch("EventAct", { Op: "Catch" }, (response) => {
							busy.current = false;
							const Juice = juice();
							if (response.ok) {
								Audio.play("countTick");
								Juice.burst(at, Palette.mango, 0.8);
								Juice.number(`+${response.Dust ?? 3}`, Palette.violet, { at: at, small: true });
							} else {
								Juice.status(response.message ?? "Missed.", "error");
							}
						});
					},
				},
			},
			h(
				"frame",
				{
					Size: UDim2.fromOffset(40, 40),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: clock.map((t) => (t * 60 + slot * 30) % 360),
					BackgroundTransparency: 1,
					ZIndex: 141,
				},
				h(Icon, { kind: "Milestone.6", color: Palette.mango, accent: WHITE_HOT, size: 40, spin: false }),
			),
		);
	}
	return h("frame", { Name: "StarField", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 140 }, stars);
}

// ------------------------------------------------------------------------------------------------
// Supply Drop: a crate floats down on a chute while it's down; the first three to tap it win
// ------------------------------------------------------------------------------------------------
function SupplyCrates(props: { event: ServerEvent; clock: React.Binding<number>; dispatch: Dispatch }) {
	const [event, clock] = [props.event, props.clock];
	const viewport = useViewport();
	const pending = React.useRef<Record<number, boolean | undefined>>({});
	const crates: Record<string, unknown> = {};
	for (const drop of event.Drops ?? []) {
		const id = drop.Id;
		const x = viewport.width * (0.2 + hash01(id, 9) * 0.6);
		const age = (_now: number) => serverNow() - drop.At;
		const open = drop.Left > 0 && !drop.Mine;
		crates["c" + id] = h(
			"textbutton",
			{
				Size: UDim2.fromOffset(84, 110),
				AnchorPoint: new Vector2(0.5, 1),
				Position: clock.map((now) => {
					const a = age(now);
					const land = easeOut(a / 2.2);
					return UDim2.fromOffset(x + math.sin(now * 1.6 + id) * 8 * (1 - land), -20 + land * viewport.height * 0.62);
				}),
				Visible: clock.map((now) => {
					const a = age(now);
					return a >= 0 && a <= drop.EndsAt - drop.At && open && !pending.current[id];
				}),
				BackgroundTransparency: 1,
				Text: "",
				AutoButtonColor: false,
				ZIndex: 150,
				Event: {
					Activated: (rbx: TextButton) => {
						if (pending.current[id]) {
							return;
						}
						pending.current[id] = true;
						const at = rbx.AbsolutePosition.add(rbx.AbsoluteSize.div(2));
						props.dispatch("EventAct", { Op: "Claim", Drop: id }, (response) => {
							const Juice = juice();
							if (response.ok) {
								Audio.play("crateOpen");
								Juice.burst(at, Palette.mint, 1.2);
								Juice.number("+1 key", Palette.mint, { at: at });
							} else {
								pending.current[id] = undefined;
								Juice.status(response.message ?? "Missed it.", "error");
							}
						});
					},
				},
			},
			h(Icon, {
				kind: "Crate.17",
				color: Palette.mango,
				accent: Palette.mint,
				size: 64,
				spin: false,
				position: new UDim2(0.5, 0, 1, -22),
				anchorPoint: new Vector2(0.5, 1),
			}),
			h("textlabel", {
				Size: new UDim2(1, 20, 0, 16),
				Position: new UDim2(0.5, 0, 1, 0),
				AnchorPoint: new Vector2(0.5, 1),
				BackgroundTransparency: 1,
				Text: `Grab it · ${drop.Left} left`,
				TextSize: 12,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextColor3: Palette.mint,
				ZIndex: 153,
			}),
		);
	}
	return h("frame", { Name: "SupplyCrates", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ZIndex: 150 }, crates);
}

// ------------------------------------------------------------------------------------------------
// the panel: what's happening, what to do, and the live standings
// ------------------------------------------------------------------------------------------------
interface LineProps {
	text: string;
	color?: Color3;
	order: number;
	height?: number;
	size?: number;
	bold?: boolean;
}
function Line(props: LineProps) {
	return h("textlabel", {
		Size: new UDim2(1, 0, 0, props.height ?? 18),
		LayoutOrder: props.order,
		BackgroundTransparency: 1,
		Text: props.text,
		TextSize: props.size ?? 13,
		TextWrapped: true,
		FontFace: Font.fromEnum(props.bold ? Enum.Font.BuilderSansBold : Enum.Font.BuilderSansMedium),
		TextColor3: props.color ?? Palette.creamSoft,
		TextXAlignment: Enum.TextXAlignment.Left,
		TextYAlignment: Enum.TextYAlignment.Top,
		ZIndex: 563,
	});
}
function Bar(props: { value: number; color: Color3; order: number }) {
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, 10),
			LayoutOrder: props.order,
			BackgroundColor3: Palette.graphite,
			BorderSizePixel: 0,
			ZIndex: 563,
		},
		h("uicorner", { CornerRadius: new UDim(1, 0) }),
		h(
			"frame",
			{
				Size: UDim2.fromScale(math.clamp(props.value, 0.02, 1), 1),
				BackgroundColor3: props.color,
				BorderSizePixel: 0,
				ZIndex: 564,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uigradient", { Color: new ColorSequence(props.color, WHITE_HOT) }),
		),
	);
}

function EventPanel(props: { event: ServerEvent; onClose: () => void }) {
	const event = props.event;
	const def = ServerEvents.EVENTS[event.Id ?? ""];
	const now = useWallClock(true);
	const viewport = useViewport();
	// opens and closes like every other panel, and respects Reduced Motion
	const [show, closing, beginExit] = usePresence(game.GetService("GuiService").ReducedMotionEnabled);
	const onClose = props.onClose;
	const close = () => {
		if (!closing) {
			beginExit(onClose);
		}
	};
	const accent = accentOf(def);
	const width = math.min(460, viewport.width - 24);
	const rows: Record<string, unknown> = {};
	let order = 0;
	const add = (element: React.Element) => {
		order += 1;
		rows["r" + order] = element;
	};
	const line = (text: string, color: Color3, opts?: { height?: number; size?: number; bold?: boolean }) => {
		const o = opts ?? {};
		add(h(Line, { text: text, color: color, order: order + 1, height: o.height, size: o.size, bold: o.bold }));
	};
	const standings = (list: Standing[] | undefined, unit: string) => {
		for (const [index, entry] of ipairs(list ?? [])) {
			line(`${index}.  ${entry.Name}  ·  ${compactNumber(entry.Points)} ${unit}`, index <= 3 ? Palette.mango : Palette.muted, {
				size: 12,
			});
		}
	};
	if (def === undefined) {
		line("No event right now. One starts every few minutes; the island warns you a minute before.", Palette.creamSoft, {
			height: 40,
		});
	} else {
		line(def.How, Palette.cream, { height: 54, size: 14 });
		const kind = def.Kind;
		if (kind === "goal" || kind === "titan") {
			const goal = math.max(1, event.Goal ?? 1);
			const progress = event.Progress ?? 0;
			if (kind === "titan") {
				line(
					event.Completed ? "It's down." : `${compactNumber(goal - progress)} of ${compactNumber(goal)} health left`,
					Palette.cream,
					{ bold: true },
				);
				add(h(Bar, { value: 1 - progress / goal, color: accent, order: order + 1 }));
				line(`You've hit it for ${compactNumber(event.Yours ?? 0)}.`, Palette.muted, { size: 12 });
			} else {
				line(event.Completed ? "Order filled." : `${compactNumber(progress)} of ${compactNumber(goal)} points`, Palette.cream, {
					bold: true,
				});
				add(h(Bar, { value: progress / goal, color: accent, order: order + 1 }));
				line(`You've added ${compactNumber(event.Yours ?? 0)}.`, Palette.muted, { size: 12 });
			}
			line(
				"Pays everyone who helped " +
					tostring(math.floor(def.RewardFluxSeconds / 60)) +
					" minutes of output and " +
					tostring(def.RewardStardust) +
					" Stardust, more for the top three.",
				Palette.muted,
				{ size: 12, height: 32 },
			);
			standings(event.Top, kind === "titan" ? "damage" : "pts");
		} else if (kind === "race") {
			line(
				event.YourRank !== undefined
					? `You're #${event.YourRank} with ${compactNumber(event.Yours ?? 0)} points.`
					: "Bank your vault to get on the board.",
				Palette.cream,
				{ bold: true },
			);
			line(
				"Prizes: 1st 120 Stardust and 6 Cores, 2nd 80 and 4, 3rd 50 and 2. Everyone who scores gets 10 Stardust.",
				Palette.muted,
				{ size: 12, height: 32 },
			);
			standings(event.Top, "pts");
		} else if (kind === "draw") {
			line(`You hold ${event.Tickets ?? 0} of ${event.Pool ?? 0} tickets.`, Palette.cream, { bold: true });
			if (event.Winners && event.Winners.size() > 0) {
				line("Drawn:", Palette.mango, { bold: true });
				for (const [index, winner] of ipairs(event.Winners)) {
					line(`${index}.  ${winner.Name}`, Palette.mango);
				}
			} else {
				line(
					"Three winners get 150 Stardust and 5 Cores each. Everyone else with a ticket gets 5 Stardust.",
					Palette.muted,
					{ size: 12, height: 32 },
				);
			}
		} else if (kind === "stars") {
			line(`Caught ${event.Caught ?? 0} of ${event.MaxStars ?? def.MaxStars}.`, Palette.cream, { bold: true });
		} else if (kind === "supply") {
			let nextAt: number | undefined = undefined;
			for (const drop of event.Drops ?? []) {
				if (drop.At > serverNow() && (nextAt === undefined || drop.At < nextAt)) {
					nextAt = drop.At;
				}
			}
			line(nextAt !== undefined ? `Next crate in ${clockText(nextAt - serverNow())}.` : "No more crates this time.", Palette.cream, {
				bold: true,
			});
		} else if (kind === "drops" && def.Drops!.Dust !== undefined) {
			line(`Up to ${def.Drops!.Dust} Stardust per collect.`, accent);
		}
	}
	return h(
		"textbutton",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: show.map((amount) => 1 - amount * 0.5),
			AutoButtonColor: false,
			Text: "",
			ZIndex: 558,
			Event: { Activated: close },
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(width, math.min(460, viewport.height - 40)),
				Position: show.map((amount) => new UDim2(0.5, 0, 0.5, revealOffset(amount))),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.panelRaised,
				BorderSizePixel: 0,
				Active: true,
				ClipsDescendants: true,
				ZIndex: 560,
			},
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uistroke", { Color: accent, Thickness: 1.5, Transparency: 0.3 }),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(52, 52),
					Position: UDim2.fromOffset(18, 18),
					BackgroundColor3: darken(accent, 0.55),
					BorderSizePixel: 0,
					ZIndex: 561,
				},
				h("uicorner", { CornerRadius: new UDim(0, 14) }),
				h(Icon, { kind: (def && def.Icon) || "Calendar.7", color: Palette.cream, accent: accent, size: 52 }),
			),
			h("textlabel", {
				Size: new UDim2(1, -150, 0, 26),
				Position: UDim2.fromOffset(82, 18),
				BackgroundTransparency: 1,
				Text: def ? def.Name : "Server events",
				TextSize: 21,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
				TextColor3: Palette.cream,
				TextXAlignment: Enum.TextXAlignment.Left,
				ZIndex: 561,
			}),
			h("textlabel", {
				Size: new UDim2(1, -150, 0, 18),
				Position: UDim2.fromOffset(82, 46),
				BackgroundTransparency: 1,
				Text: now.map((value) => {
					const left = (event.PhaseEndsAt ?? value) - value;
					return event.Phase === "Warning"
						? `Starts in ${clockText(left)}`
						: event.Phase === "Live"
							? `${clockText(left)} left`
							: event.Phase === "Results"
								? "Finished"
								: `Next event in ${clockText(left)}`;
				}),
				TextSize: 14,
				FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
				TextColor3: accent,
				TextXAlignment: Enum.TextXAlignment.Left,
				ZIndex: 561,
			}),
			h(Button, {
				text: "",
				icon: "Close.14",
				onClick: close,
				color: Palette.ink,
				textColor: Palette.coral,
				size: UDim2.fromOffset(TapTarget, TapTarget),
				position: new UDim2(1, -(TapTarget + 12), 0, 12),
				zIndex: 562,
			}),
			h(
				"scrollingframe",
				{
					Size: new UDim2(1, -36, 1, -100),
					Position: UDim2.fromOffset(18, 86),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					CanvasSize: new UDim2(),
					AutomaticCanvasSize: Enum.AutomaticSize.Y,
					ScrollBarThickness: 3,
					ZIndex: 562,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					Padding: new UDim(0, 8),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				rows,
			),
		),
	);
}

export function ServerEventHost(props: { state?: { ServerEvent?: ServerEvent }; dispatch?: Dispatch }) {
	const state = props.state;
	const event = useServerEvent(state && state.ServerEvent);
	const [panelOpen, setPanelOpen] = React.useState(false);
	const lastPhase = React.useRef<string>();
	const def = event && ServerEvents.EVENTS[event.Id ?? ""];
	const live = def !== undefined && event!.Phase === "Live";
	const [clock, setClock] = React.useBinding(os.clock());
	React.useEffect(() => {
		const opener = () => {
			Audio.play("open");
			setPanelOpen(true);
		};
		panelOpeners.add(opener);
		return () => {
			panelOpeners.delete(opener);
		};
	}, []);
	React.useEffect(() => {
		if (!live) {
			return undefined;
		}
		const conn = RunService.Heartbeat.Connect(() => setClock(os.clock()));
		return () => conn.Disconnect();
	}, [live]);
	// a new event lands as a moment out of the island
	React.useEffect(() => {
		if (event === undefined) {
			return undefined;
		}
		const key = tostring(event.Phase) + ":" + tostring(event.Id);
		if (lastPhase.current !== undefined && lastPhase.current !== key && event.Phase === "Live" && def !== undefined) {
			juice().moment(string.upper(def.Name), def.How, accentOf(def), def.Icon);
		}
		lastPhase.current = key;
		return undefined;
	}, [event && event.Phase, event && event.Id]);
	// while it runs, the island carries it: name, countdown and how it's going
	React.useEffect(() => {
		const Juice = juice();
		if (!live) {
			pcall(Juice.live, "serverEvent", undefined);
			return undefined;
		}
		const ev = event!;
		const d = def!;
		const goal = ev.Goal;
		let progress: number | undefined = undefined;
		if (d.Kind === "goal" && goal !== undefined) {
			progress = (ev.Progress ?? 0) / math.max(1, goal);
		} else if (d.Kind === "titan" && goal !== undefined) {
			progress = 1 - (ev.Progress ?? 0) / math.max(1, goal);
		}
		pcall(Juice.live, "serverEvent", {
			title: string.upper(d.Name),
			value: liveValue(ev, d),
			icon: d.Icon,
			color: accentOf(d),
			serverEndsAt: ev.PhaseEndsAt,
			span: ServerEvents.LIVE_SECONDS,
			progress: progress,
			priority: 1,
			ttl: ServerEvents.LIVE_SECONDS + 5,
		});
		return undefined;
	}, [
		live,
		event && event.Id,
		event && event.Progress,
		event && event.Caught,
		event && event.Tickets,
		event && event.YourRank,
		event && event.PhaseEndsAt,
	]);
	if (event === undefined) {
		return undefined;
	}
	const accent = accentOf(def);
	return h(
		React.Fragment,
		undefined,
		live && h(Sky, { key: event.Id, eventId: event.Id, clock: clock, color: accent }),
		live && def!.Kind === "stars" && props.dispatch && h(StarField, { clock: clock, dispatch: props.dispatch }),
		live && def!.Kind === "supply" && props.dispatch && h(SupplyCrates, { event: event, clock: clock, dispatch: props.dispatch }),
		panelOpen &&
			h(EventPanel, {
				event: event,
				onClose: () => {
					Audio.play("close");
					setPanelOpen(false);
				},
			}),
	);
}

export const EVENTS = ServerEvents.EVENTS;
