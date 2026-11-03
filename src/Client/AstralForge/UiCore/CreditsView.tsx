import { clamp01 } from "../CoreKit/easing";
// Credits: the Forge Reel. Everyone who made the game, read from SharedData#CreditsConfig through CreditsModel.
//
// The credits roll like a reel struck at the anvil. The title letters arrive white-hot and cool to
// cream, each chapter draws its rule with a spark running down it, and every name plate is struck
// into place as it scrolls into view (a heat flash across the plate, a bright sweep, then it settles).
// Behind it a three-layer star field drifts at different depths against the scroll, and embers rise.
// The reel rolls by itself and gives way the moment you touch the wheel, a drag or a chapter: it waits
// a few seconds, then carries on. A chapter rail follows where you are, its marker stretching as it
// travels. Tap a plate to cheer: sparks fly off the avatar. B or Esc closes, LB/RB change chapter, and
// a tap outside the panel closes too. Reduced Motion drops the auto-roll, the drift and the embers.
import React from "@rbxts/react";
import { useBackLayer } from "../CoreKit/backLayer";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { revealOffset, useFlipperSpring, usePresence, useViewport } from "../MotionKit/motion";
import * as MotionTokens from "../MotionKit/motionTokens";
import { Button, OverlayPresence, useGamepadAutofocus } from "./ui";
import {
	KindChip,
	SearchField,
	Surface,
	SurfaceMetrics,
	SurfaceRow,
	SurfaceText,
	surfaceFont,
	useSurfaceEnter,
	useSurfaceSpring,
} from "./surface";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");
const TextService = game.GetService("TextService");
const RunService = game.GetService("RunService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

interface Member {
	UserId?: number;
	DisplayName: string;
	Name: string;
	Role: string;
	Note: string;
}
interface Category {
	Id: string;
	Accent: string;
	Icon: string;
	Label: string;
	Description: string;
	EmptyText: string;
	Members: Member[];
}
interface VisibleEntry {
	category: Category;
	members: Member[];
}
interface Tab {
	id: string;
	label: string;
	count: number;
	accent: string;
}
interface CreditsModelData {
	FetchNames?: boolean;
	Categories: Category[];
	AvatarShape: string;
	EntranceStagger?: boolean;
	AvatarSize: number;
	ShowAvatars?: boolean;
	ShowRoles?: boolean;
	ShowUsernames?: boolean;
	ShowNotes?: boolean;
	ShowCategoryCounts?: boolean;
	DefaultCategory: string;
	CategoryTabs?: boolean;
	Tagline: string;
	DefaultEmptyText: string;
	Acknowledgements: string[];
	Footer: string;
	Eyebrow: string;
	Title: string;
	ShowVersion?: boolean;
}
interface CreditsModelModule {
	normalize(this: void, config: unknown): CreditsModelData;
	tabs(this: void, model: CreditsModelData): Tab[];
	showSearch(this: void, model: CreditsModelData): boolean;
	columns(this: void, model: CreditsModelData, width: number, gap: number): number;
	cardHeight(this: void, model: CreditsModelData): number;
	visible(this: void, model: CreditsModelData, tab: string, query: string): VisibleEntry[];
}

const SharedData = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript,
) as (name: string) => unknown;
const CreditsModel = SharedData("CreditsModel") as CreditsModelModule;
const MODEL = CreditsModel.normalize(SharedData("CreditsConfig"));

const GAP = SurfaceMetrics.gap;
const CHIP_ROW_H = TapTarget;
const RAIL_W = 196;
const ROW_STEP = TapTarget + SurfaceMetrics.rowGap;

// the reel
const REEL_PAD = 14;
const PLATE_GAP = 12;
const HEAD_H = 84;
const CHAPTER_GAP = 36;
const FINALE_H = 250;
const ROLL_SPEED = 30;
const ROLL_RAMP = 1.5;
const USER_PAUSE = 3.5;
const CLOCK_STEP = 1 / 45;
const JUMP_SECONDS = 0.6;
const HOT = Color3.fromRGB(255, 168, 84);
const WHITE_HOT = Color3.fromRGB(255, 244, 222);


function tone(key: string, fallback: Color3): Color3 {
	const color = (Palette as unknown as Record<string, unknown>)[key];
	return typeIs(color, "Color3") ? color : fallback;
}

function memberKey(category: Category, member: Member): string {
	return category.Id + ":" + member.Name;
}

// the animated layers and the sparks are cosmetic; the guard has nothing to repair in them
function ignoreGuard(instance: Instance | undefined) {
	if (instance !== undefined) {
		instance.SetAttribute("LayoutGuardIgnore", true);
	}
}

// ── Live names ─────────────────────────────────────────────────────────────────

const liveNames: Record<number, { display?: unknown; username?: unknown } | undefined> = {};
let liveNamesRequested = false;

// display names and usernames change; ask Roblox once per session and redraw when they land
function useLiveNames() {
	const [, setVersion] = React.useState(0);
	React.useEffect(() => {
		if (!MODEL.FetchNames || liveNamesRequested) {
			return undefined;
		}
		liveNamesRequested = true;
		const ids: number[] = [];
		const seen = new Set<number>();
		for (const category of MODEL.Categories) {
			for (const member of category.Members) {
				if (member.UserId !== undefined && !seen.has(member.UserId)) {
					seen.add(member.UserId);
					ids.push(member.UserId);
				}
			}
		}
		if (ids.size() === 0) {
			return undefined;
		}
		let alive = true;
		task.spawn(() => {
			const [ok, infos] = pcall(() => game.GetService("UserService").GetUserInfosByUserIdsAsync(ids) as unknown);
			if (!ok || !typeIs(infos, "table")) {
				return;
			}
			for (const [, info] of pairs(infos as Record<string, unknown>)) {
				if (typeIs(info, "table")) {
					const record = info as {
						Id?: number;
						DisplayName?: unknown;
						Username?: unknown;
					};
					if (record.Id !== undefined) {
						liveNames[record.Id] = {
							display: record.DisplayName,
							username: record.Username,
						};
					}
				}
			}
			if (alive) {
				setVersion((current) => current + 1);
			}
		});
		return () => {
			alive = false;
		};
	}, []);
}

function namesOf(member: Member): LuaTuple<[string, string]> {
	const live = member.UserId !== undefined ? liveNames[member.UserId] : undefined;
	const display = live !== undefined && typeIs(live.display, "string") && live.display !== "" ? live.display : member.DisplayName;
	const username = live !== undefined && typeIs(live.username, "string") && live.username !== "" ? live.username : member.Name;
	return $tuple(display, username);
}

// ── Reel plumbing ──────────────────────────────────────────────────────────────

// where the reel is scrolled to, shared with everything that reveals as it comes into view
interface Hub {
	y: number;
	h: number;
	listeners: Set<(y: number) => void>;
}

// true while any part of [top, top + height] is inside the reel window; it lets go only once the block
// is well clear of the window, so a block at the edge does not flicker between struck and unstruck
function useInView(hub: Hub, top: number, height: number): boolean {
	const decide = (y: number, previous: boolean): boolean => {
		const bottom = y + hub.h;
		if (top < bottom - hub.h * 0.06 && top + height > y) {
			return true;
		}
		const far = top > bottom + hub.h * 0.5 || top + height < y - hub.h * 0.5;
		return far ? false : previous;
	};
	const [seen, setSeen] = React.useState(() => decide(hub.y, false));
	const last = React.useRef(seen);
	React.useEffect(() => {
		const listener = (y: number) => {
			const nowSeen = decide(y, last.current);
			if (nowSeen !== last.current) {
				last.current = nowSeen;
				setSeen(nowSeen);
			}
		};
		hub.listeners.add(listener);
		listener(hub.y);
		return () => {
			hub.listeners.delete(listener);
		};
	}, [top, height]);
	return seen;
}

// 0 -> 1 on the bouncy spring once `seen` (after `delay`), back to 0 when it leaves; instant with reduced motion
function useStrike(seen: boolean, reduced: boolean, delay: number): React.Binding<number> {
	const [goal, setGoal] = React.useState(0);
	React.useEffect(() => {
		if (!seen) {
			setGoal(0);
			return undefined;
		}
		if (reduced || delay <= 0) {
			setGoal(1);
			return undefined;
		}
		const job = task.delay(delay, () => setGoal(1));
		return () => {
			pcall(task.cancel, job);
		};
	}, [seen]);
	const spring = MotionTokens.SPRING.bouncy;
	return useFlipperSpring(reduced ? 1 : goal, reduced, spring.stiffness, spring.damping, reduced ? 1 : 0);
}

// ── Backdrop: star field and embers ────────────────────────────────────────────

interface Dot {
	x: number;
	y: number;
	s: number;
	a: number;
}
interface Ember {
	x: number;
	speed: number;
	phase: number;
	sway: number;
	size: number;
}
const rng = new Random(11);
const LAYER_SPECS = [
	{ depth: 0.05, drift: 3, count: 18, size: 2, alpha: 0.7 },
	{ depth: 0.11, drift: 7, count: 12, size: 2, alpha: 0.54 },
	{ depth: 0.2, drift: 13, count: 8, size: 3, alpha: 0.4 },
];
const LAYERS = LAYER_SPECS.map((spec) => {
	const dots: Dot[] = [];
	for (let i = 0; i < spec.count; i++) {
		dots.push({ x: rng.NextNumber(), y: rng.NextNumber(), s: spec.size + rng.NextInteger(0, 1), a: spec.alpha + rng.NextNumber() * 0.14 });
	}
	return { depth: spec.depth, drift: spec.drift, dots };
});
const EMBERS: Ember[] = [];
for (let i = 0; i < 9; i++) {
	EMBERS.push({ x: rng.NextNumber(), speed: 14 + rng.NextNumber() * 18, phase: rng.NextNumber(), sway: 0.6 + rng.NextNumber() * 1.1, size: 3 + rng.NextInteger(0, 1) });
}

function Backdrop(props: { width: number; height: number; scroll: React.Binding<number>; clock?: React.Binding<number> }) {
	const { width, height, scroll, clock } = props;
	const span = height + 60;
	return (
		<frame ref={ignoreGuard} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={true} ZIndex={1}>
			{LAYERS.map((layer, li) => {
				const offset =
					clock !== undefined
						? React.joinBindings({ s: scroll, t: clock }).map(({ s, t }) => (s * layer.depth + t * layer.drift) % height)
						: scroll.map((s) => (s * layer.depth) % height);
				const dots: React.Element[] = [];
				for (const tile of [0, 1]) {
					layer.dots.forEach((dot, di) => {
						dots.push(
							<frame
								key={`${tile}:${di}`}
								Size={UDim2.fromOffset(dot.s, dot.s)}
								Position={UDim2.fromOffset(dot.x * width, dot.y * height + tile * height)}
								BackgroundColor3={di % 4 === 0 ? HOT : Palette.cream}
								BackgroundTransparency={1 - dot.a * 0.5}
								BorderSizePixel={0}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
							</frame>,
						);
					});
				}
				return (
					<frame
						key={`layer${li}`}
						Size={UDim2.fromOffset(width, height * 2)}
						Position={offset.map((o) => UDim2.fromOffset(0, -o))}
						BackgroundTransparency={1}
					>
						{dots}
					</frame>
				);
			})}
			{clock !== undefined &&
				EMBERS.map((ember, i) => (
					<frame
						key={`ember${i}`}
						Size={UDim2.fromOffset(ember.size, ember.size)}
						Position={clock.map((t) => {
							const life = (t * ember.speed + ember.phase * span) % span;
							return UDim2.fromOffset(ember.x * width + math.sin(t * ember.sway + ember.phase * 9) * 10, height - life);
						})}
						BackgroundColor3={i % 3 === 0 ? WHITE_HOT : HOT}
						BackgroundTransparency={clock.map((t) => {
							const life = ((t * ember.speed + ember.phase * span) % span) / span;
							return 1 - 0.72 * math.sin(life * math.pi);
						})}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				))}
		</frame>
	);
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

// the member's initial, with their headshot loaded over it when they have a UserId; `ring` turns a
// bright arc around the edge
function Avatar(props: {
	member: Member;
	size: number;
	accent: Color3;
	position?: UDim2;
	anchor?: Vector2;
	ring?: React.Binding<number>;
	zIndex: number;
}) {
	const member = props.member;
	const size = props.size;
	const radius = MODEL.AvatarShape === "Circle" ? new UDim(1, 0) : new UDim(0, math.floor(size * 0.22));
	const initial = string.upper((string.match(member.DisplayName, utf8.charpattern)[0] as string | undefined) ?? "?");
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={props.position}
			AnchorPoint={props.anchor}
			BackgroundColor3={darken(props.accent, 0.6)}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			<uicorner CornerRadius={radius} />
			<uistroke Color={props.accent} Thickness={props.ring !== undefined ? 2 : 1} Transparency={props.ring !== undefined ? 0.1 : 0.7}>
				{props.ring !== undefined && (
					<uigradient
						Color={
							new ColorSequence([
								new ColorSequenceKeypoint(0, props.accent),
								new ColorSequenceKeypoint(0.5, Palette.cream),
								new ColorSequenceKeypoint(1, props.accent),
							])
						}
						Transparency={
							new NumberSequence([new NumberSequenceKeypoint(0, 0.65), new NumberSequenceKeypoint(0.5, 0), new NumberSequenceKeypoint(1, 0.65)])
						}
						Rotation={props.ring}
					/>
				)}
			</uistroke>
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text={initial}
				TextColor3={Palette.cream}
				TextSize={math.floor(size * 0.46)}
				FontFace={Font.fromName("BuilderSans", Enum.FontWeight.Heavy)}
				ZIndex={props.zIndex + 1}
			/>
			{member.UserId !== undefined && (
				<imagelabel
					Size={new UDim2(1, -4, 1, -4)}
					Position={UDim2.fromOffset(2, 2)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Image={`rbxthumb://type=AvatarHeadShot&id=${member.UserId}&w=150&h=150`}
					ZIndex={props.zIndex + 2}
				>
					<uicorner CornerRadius={radius} />
				</imagelabel>
			)}
		</frame>
	);
}

// ── Hero title ─────────────────────────────────────────────────────────────────

function HeroLetter(props: { char: string; index: number; fontSize: number; reduced: boolean; seen: boolean; clock?: React.Binding<number> }) {
	const p = useStrike(props.seen, props.reduced, 0.3 + props.index * 0.05);
	const size = props.fontSize;
	if (props.char === " ") {
		return <frame Size={UDim2.fromOffset(size * 0.45, size)} LayoutOrder={props.index} BackgroundTransparency={1} />;
	}
	const index = props.index;
	// white-hot as it lands, cooling to cream; once cool, a glint runs along the word now and then
	const color =
		props.clock !== undefined
			? React.joinBindings({ p, t: props.clock }).map(({ p: a, t }) => {
					const cool = HOT.Lerp(Palette.cream, clamp01(a) ** 1.6);
					const glint = math.max(0, math.sin(t * 1.4 - index * 0.42)) ** 14;
					return cool.Lerp(WHITE_HOT, glint * 0.85 * clamp01(a));
				})
			: p.map((a) => HOT.Lerp(Palette.cream, clamp01(a) ** 1.6));
	return (
		<frame Size={new UDim2(0, 0, 1, 0)} AutomaticSize={Enum.AutomaticSize.X} LayoutOrder={props.index} BackgroundTransparency={1}>
			<textlabel
				Size={new UDim2(0, 0, 1, 0)}
				AutomaticSize={Enum.AutomaticSize.X}
				Position={p.map((a) => UDim2.fromOffset(0, (1 - clamp01(a)) * 36))}
				BackgroundTransparency={1}
				Text={props.char}
				FontFace={surfaceFont(Enum.FontWeight.Heavy)}
				TextSize={size}
				TextColor3={color}
				TextTransparency={p.map((a) => 1 - math.clamp(a * 1.7, 0, 1))}
			/>
		</frame>
	);
}

function Hero(props: { hub: Hub; top: number; width: number; height: number; subline: string; reduced: boolean; clock?: React.Binding<number> }) {
	const seen = useInView(props.hub, props.top, props.height);
	const p = useStrike(seen, props.reduced, 0.9);
	const letters: React.Element[] = [];
	const fontSize = props.width < 420 ? 34 : props.width < 600 ? 44 : 54;
	let index = 0;
	for (const [char] of string.gmatch(string.upper(MODEL.Title), utf8.charpattern)) {
		letters.push(
			<HeroLetter
				key={`c${index}`}
				char={char as string}
				index={index}
				fontSize={fontSize}
				reduced={props.reduced}
				seen={seen}
				clock={seen ? props.clock : undefined}
			/>,
		);
		index += 1;
	}
	const lineW = math.min(props.width - 40, 280);
	return (
		<frame
			ref={ignoreGuard}
			Size={UDim2.fromOffset(props.width, props.height)}
			Position={UDim2.fromOffset(0, props.top)}
			BackgroundTransparency={1}
			ZIndex={2}
		>
			<frame Size={new UDim2(1, 0, 0, fontSize + 6)} Position={UDim2.fromOffset(0, 26)} BackgroundTransparency={1}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					HorizontalAlignment={Enum.HorizontalAlignment.Center}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, math.floor(fontSize * 0.08))}
				/>
				{letters}
			</frame>
			{/* the forged rule: grows out from the middle, a diamond lands on it last */}
			<frame
				Size={p.map((a) => UDim2.fromOffset(lineW * clamp01(a), 2))}
				Position={new UDim2(0.5, 0, 0, fontSize + 46)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={HOT}
				BackgroundTransparency={0.35}
				BorderSizePixel={0}
			/>
			<frame
				Size={UDim2.fromOffset(9, 9)}
				Position={new UDim2(0.5, 0, 0, fontSize + 46)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={WHITE_HOT}
				BackgroundTransparency={p.map((a) => 1 - clamp01((a - 0.55) * 2.2))}
				BorderSizePixel={0}
			/>
			{props.subline !== "" && (
				<frame Size={new UDim2(1, 0, 0, 18)} Position={p.map((a) => UDim2.fromOffset(0, fontSize + 62 + (1 - clamp01(a)) * 10))} BackgroundTransparency={1}>
					<SurfaceText
						text={props.subline}
						type="body"
						color={Palette.creamSoft}
						align={Enum.TextXAlignment.Center}
						transparency={p.map((a) => 1 - clamp01(a * 1.3))}
					/>
				</frame>
			)}
		</frame>
	);
}

// ── Chapter head ───────────────────────────────────────────────────────────────

function ChapterHead(props: {
	hub: Hub;
	top: number;
	width: number;
	index: number;
	category: Category;
	accent: Color3;
	reduced: boolean;
}) {
	const seen = useInView(props.hub, props.top, HEAD_H);
	const p = useStrike(seen, props.reduced, 0);
	const accent = props.accent;
	const width = props.width;
	return (
		<frame Size={UDim2.fromOffset(width, HEAD_H)} Position={UDim2.fromOffset(0, props.top)} BackgroundTransparency={1} ZIndex={2}>
			<textlabel
				Size={UDim2.fromOffset(64, 48)}
				Position={p.map((a) => UDim2.fromOffset(0, 6 + (1 - clamp01(a)) * 16))}
				BackgroundTransparency={1}
				Text={string.format("%02d", props.index)}
				FontFace={surfaceFont(Enum.FontWeight.Heavy)}
				TextSize={42}
				TextColor3={accent}
				TextTransparency={p.map((a) => 1 - 0.55 * clamp01(a))}
				TextXAlignment={Enum.TextXAlignment.Left}
			/>
			<frame
				Size={new UDim2(1, -74, 0, 30)}
				Position={p.map((a) => UDim2.fromOffset(74 + (1 - clamp01(a)) * 24, 8))}
				BackgroundTransparency={1}
			>
				<SurfaceText text={string.upper(props.category.Label)} type="display" transparency={p.map((a) => 1 - clamp01(a * 1.4))} />
			</frame>
			{props.category.Description !== "" && (
				<frame Size={new UDim2(1, -74, 0, 18)} Position={UDim2.fromOffset(74, 40)} BackgroundTransparency={1}>
					<SurfaceText
						text={props.category.Description}
						type="small"
						color={Palette.muted}
						transparency={p.map((a) => 1 - clamp01((a - 0.3) * 1.5))}
					/>
				</frame>
			)}
			<frame
				Size={p.map((a) => UDim2.fromOffset(width * clamp01(a), 2))}
				Position={UDim2.fromOffset(0, 70)}
				BackgroundColor3={accent}
				BackgroundTransparency={0.45}
				BorderSizePixel={0}
			/>
			{/* the spark that draws the rule */}
			<frame
				Size={UDim2.fromOffset(8, 8)}
				Position={p.map((a) => UDim2.fromOffset(width * clamp01(a) - 4, 67))}
				BackgroundColor3={WHITE_HOT}
				BackgroundTransparency={p.map((a) => 1 - math.sin(clamp01(a) * math.pi))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</frame>
	);
}

// ── Cheer sparks ───────────────────────────────────────────────────────────────

const SPARK_COUNT = 10;

function Sparks(props: { x: number; y: number; accent: Color3 }) {
	const [progress, setProgress] = React.useMemo(() => React.createBinding(0), []);
	const [done, setDone] = React.useState(false);
	React.useEffect(() => {
		const started = os.clock();
		const connection = RunService.Heartbeat.Connect(() => {
			const a = (os.clock() - started) / 0.8;
			if (a >= 1) {
				connection.Disconnect();
				setDone(true);
				return;
			}
			setProgress(a);
		});
		return () => connection.Disconnect();
	}, []);
	if (done) {
		return <></>;
	}
	const sparks: React.Element[] = [];
	for (let i = 0; i < SPARK_COUNT; i++) {
		const angle = (i / SPARK_COUNT) * math.pi * 2 + (i % 2) * 0.3;
		const reach = 52 + (i % 3) * 16;
		sparks.push(
			<frame
				key={`s${i}`}
				ref={ignoreGuard}
				Size={progress.map((a) => UDim2.fromOffset(math.max(1, 6 * (1 - a)), math.max(1, 6 * (1 - a))))}
				Position={progress.map((a) => {
					const out = 1 - (1 - a) ** 3;
					return UDim2.fromOffset(props.x + math.cos(angle) * reach * out, props.y + math.sin(angle) * reach * out + 26 * a * a);
				})}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={i % 2 === 0 ? WHITE_HOT : props.accent}
				BackgroundTransparency={progress.map((a) => a ** 1.5)}
				BorderSizePixel={0}
				ZIndex={14}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return <>{sparks}</>;
}

// ── Name plate ─────────────────────────────────────────────────────────────────

const cheers: Record<string, number> = {};

function Plate(props: {
	member: Member;
	category: Category;
	accent: Color3;
	hub: Hub;
	left: number;
	top: number;
	width: number;
	height: number;
	delay: number;
	reduced: boolean;
	clock?: React.Binding<number>;
}) {
	const member = props.member;
	const accent = props.accent;
	const width = props.width;
	const height = props.height;
	const key = memberKey(props.category, member);
	const seen = useInView(props.hub, props.top, height);
	const p = useStrike(seen, props.reduced, props.delay);
	const [hovered, setHovered] = React.useState(false);
	const lit = useSurfaceSpring(hovered ? 1 : 0, props.reduced);
	const [count, setCount] = React.useState(cheers[key] ?? 0);
	const [burst, setBurst] = React.useState(0);
	const [display, username] = namesOf(member);
	const avatar = MODEL.ShowAvatars !== false ? math.min(MODEL.AvatarSize, height - 28) : 0;
	const textX = avatar > 0 ? 16 + avatar + 16 : 18;
	const showNote = MODEL.ShowNotes !== false && member.Note !== "" && height >= 100;
	const hasRole = MODEL.ShowRoles !== false && member.Role !== "";
	const ring =
		props.clock !== undefined && avatar > 0
			? React.joinBindings({ t: props.clock, l: lit }).map(({ t, l }) => (t * (50 + 160 * l)) % 360)
			: undefined;
	const cheer = () => {
		const total = (cheers[key] ?? 0) + 1;
		cheers[key] = total;
		setCount(total);
		setBurst((current) => current + 1);
		Audio.play("confirm");
	};
	return (
		<frame
			Size={UDim2.fromOffset(width, height)}
			Position={p.map((a) => UDim2.fromOffset(props.left, props.top + (1 - clamp01(a)) * 30))}
			BackgroundTransparency={1}
			ZIndex={2}
		>
			{/* the plate */}
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={darken(accent, 0.78)}
				BackgroundTransparency={React.joinBindings({ p, l: lit }).map(({ p: a, l }) => 1 - (0.8 + 0.1 * l) * clamp01(a))}
				BorderSizePixel={0}
				ZIndex={1}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke
					Color={accent}
					Thickness={1}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Transparency={React.joinBindings({ p, l: lit }).map(({ p: a, l }) => 1 - (0.2 + 0.3 * l) * clamp01(a))}
				/>
			</frame>
			{/* heat: the plate flashes as it lands, then cools to its own colour */}
			<frame
				ref={ignoreGuard}
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={HOT}
				BackgroundTransparency={p.map((a) => 1 - 0.34 * math.sin(clamp01(a) * math.pi))}
				BorderSizePixel={0}
				ZIndex={2}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
			</frame>
			{/* a bright sweep crosses the plate while it is struck */}
			<frame ref={ignoreGuard} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={true} ZIndex={3}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<frame
					Size={new UDim2(0, 64, 1, 0)}
					Position={p.map((a) => UDim2.fromOffset(-80 + (width + 160) * clamp01(a / 0.9), 0))}
					BackgroundColor3={WHITE_HOT}
					BackgroundTransparency={p.map((a) => 1 - 0.55 * math.sin(clamp01(a) * math.pi))}
					BorderSizePixel={0}
				>
					<uigradient
						Transparency={
							new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.5, 0), new NumberSequenceKeypoint(1, 1)])
						}
					/>
				</frame>
			</frame>
			{/* accent edge: grows from the middle as the plate lands */}
			<frame
				Size={p.map((a) => new UDim2(0, 3, clamp01(a) * 0.62, 0))}
				Position={new UDim2(0, 5, 0.5, 0)}
				AnchorPoint={new Vector2(0, 0.5)}
				BackgroundColor3={accent}
				BorderSizePixel={0}
				ZIndex={4}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			{avatar > 0 && (
				<Avatar
					member={member}
					size={avatar}
					accent={accent}
					position={new UDim2(0, 16, 0.5, 0)}
					anchor={new Vector2(0, 0.5)}
					ring={ring}
					zIndex={5}
				/>
			)}
			<SurfaceText
				text={display}
				type="display"
				size={new UDim2(1, -(textX + 16), 0, 28)}
				position={UDim2.fromOffset(textX, 18)}
				transparency={p.map((a) => 1 - clamp01(a * 1.5))}
				zIndex={8}
			/>
			<frame Size={new UDim2(1, -(textX + 16), 0, 22)} Position={UDim2.fromOffset(textX, 50)} BackgroundTransparency={1} ZIndex={8}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, 8)}
				/>
				{hasRole && <KindChip text={member.Role} accent={accent} order={1} zIndex={8} />}
				{MODEL.ShowUsernames !== false && (
					<SurfaceText text={`@${username}`} type="small" color={Palette.muted} autoSize={true} order={2} zIndex={8} />
				)}
			</frame>
			{showNote && (
				<SurfaceText
					text={member.Note}
					type="body"
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					size={new UDim2(1, -(textX + 18), 0, height - 88)}
					position={UDim2.fromOffset(textX, 78)}
					transparency={p.map((a) => 1 - clamp01((a - 0.2) * 1.5))}
					zIndex={8}
				/>
			)}
			<SurfaceText
				text={count > 0 ? `Cheered ×${count}` : "Tap to cheer"}
				type="hint"
				color={count > 0 ? accent : Palette.muted}
				align={Enum.TextXAlignment.Right}
				size={UDim2.fromOffset(120, 13)}
				position={new UDim2(1, -134, 0, 5)}
				zIndex={8}
			/>
			{burst > 0 && <Sparks key={`b${burst}`} x={16 + avatar / 2} y={height / 2} accent={accent} />}
			{/* the whole plate is one tap target */}
			<textbutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Selectable={true}
				Text=""
				ZIndex={12}
				Event={{
					MouseEnter: () => setHovered(true),
					MouseLeave: () => setHovered(false),
					SelectionGained: () => setHovered(true),
					SelectionLost: () => setHovered(false),
					Activated: cheer,
				}}
			/>
		</frame>
	);
}

// ── Finale ─────────────────────────────────────────────────────────────────────

function Finale(props: {
	hub: Hub;
	top: number;
	width: number;
	lines: string[];
	reduced: boolean;
	clock?: React.Binding<number>;
	onReplay: () => void;
}) {
	const seen = useInView(props.hub, props.top, FINALE_H);
	const p = useStrike(seen, props.reduced, 0.1);
	const breathe = props.clock !== undefined ? props.clock.map((t) => 0.5 + 0.5 * math.sin(t * 1.6)) : undefined;
	const footer = MODEL.Footer;
	const lineW = math.min(props.width - 40, 220);
	return (
		<frame Size={UDim2.fromOffset(props.width, FINALE_H)} Position={UDim2.fromOffset(0, props.top)} BackgroundTransparency={1} ZIndex={2}>
			<frame
				Size={p.map((a) => UDim2.fromOffset(lineW * clamp01(a), 2))}
				Position={new UDim2(0.5, 0, 0, 20)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={HOT}
				BackgroundTransparency={0.4}
				BorderSizePixel={0}
			/>
			{footer !== "" && (
				<textlabel
					Size={new UDim2(1, 0, 0, 40)}
					Position={p.map((a) => UDim2.fromOffset(0, 40 + (1 - clamp01(a)) * 20))}
					BackgroundTransparency={1}
					Text={footer}
					FontFace={surfaceFont(Enum.FontWeight.Heavy)}
					TextSize={30}
					TextColor3={breathe !== undefined ? breathe.map((b) => Palette.cream.Lerp(HOT, b * 0.4)) : Palette.cream}
					TextTransparency={p.map((a) => 1 - clamp01(a * 1.4))}
				/>
			)}
			{props.lines.map((line, i) => (
				<frame
					key={`p${i}`}
					Size={new UDim2(1, -40, 0, 16)}
					Position={UDim2.fromOffset(20, 92 + i * 18)}
					BackgroundTransparency={1}
				>
					<SurfaceText
						text={line}
						type="small"
						color={Palette.muted}
						align={Enum.TextXAlignment.Center}
						transparency={p.map((a) => 1 - clamp01((a - 0.4) * 1.6))}
					/>
				</frame>
			))}
			<Button
				text="Replay credits"
				onClick={props.onReplay}
				size={UDim2.fromOffset(170, TapTarget)}
				position={new UDim2(0.5, -85, 0, 100 + props.lines.size() * 18)}
				outline={true}
				reducedMotion={props.reduced}
				zIndex={6}
			/>
		</frame>
	);
}

// ── Chapter pickers ────────────────────────────────────────────────────────────

function SectionPick(props: {
	tab: Tab;
	active: boolean;
	order: number;
	width?: UDim;
	reducedMotion: boolean;
	onPick: (id: string) => void;
}) {
	const accent = tone(props.tab.accent, Palette.mango);
	const [hovered, setHovered] = React.useState(false);
	const lit = useSurfaceSpring(props.active ? 1 : hovered ? 0.55 : 0, props.reducedMotion);
	return (
		<SurfaceRow
			width={props.width}
			order={props.order}
			accent={accent}
			lit={lit}
			selectable={true}
			zIndex={6}
			events={{
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
				Activated: () => props.onPick(props.tab.id),
			}}
		>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={8}>
				<uipadding PaddingLeft={new UDim(0, 14)} PaddingRight={new UDim(0, 10)} />
				<uilistlayout
					FillDirection={Enum.FillDirection.Horizontal}
					VerticalAlignment={Enum.VerticalAlignment.Center}
					Padding={new UDim(0, 8)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				<SurfaceText
					text={props.tab.label}
					type="title"
					color={props.active ? Palette.cream : Palette.creamSoft}
					autoSize={true}
					order={1}
					zIndex={8}
				/>
				{MODEL.ShowCategoryCounts !== false && (
					<KindChip text={tostring(props.tab.count)} accent={props.active ? accent : undefined} order={2} zIndex={8} />
				)}
			</frame>
		</SurfaceRow>
	);
}

function chipWidth(tab: Tab): number {
	let width = tab.label.size() * 8;
	pcall(() => {
		width = TextService.GetTextSize(tab.label, 15, Enum.Font.BuilderSansBold, new Vector2(400, 20)).X;
	});
	return math.ceil(width) + 14 + 10 + (MODEL.ShowCategoryCounts !== false ? 8 + 30 : 0);
}

// the marker beside the rail: its head leaps ahead of its tail, so it stretches while it travels
function RailMarker(props: { index: number; accent: Color3; reduced: boolean }) {
	const head = useFlipperSpring(props.index, props.reduced, 900, 44);
	const tail = useFlipperSpring(props.index, props.reduced, 260, 36);
	const frame = React.joinBindings({ h: head, t: tail });
	return (
		<frame
			ref={ignoreGuard}
			Size={frame.map(({ h, t }) => UDim2.fromOffset(3, math.max(14, math.abs(h - t) * ROW_STEP + TapTarget - 18)))}
			Position={frame.map(({ h, t }) => UDim2.fromOffset(-8, math.min(h, t) * ROW_STEP + 9))}
			BackgroundColor3={props.accent}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
}

// ── Overlay ────────────────────────────────────────────────────────────────────

interface Jump {
	from: number;
	to: number;
	started: number;
}

export function CreditsOverlay(props: { version?: string; reducedMotion?: boolean; onClose: () => void }) {
	const reduced = props.reducedMotion === true;
	const antilag = useAntilag();
	const [reveal, exiting, beginExit] = usePresence(reduced);
	const [query, setQuery] = React.useState("");
	const [rolling, setRolling] = React.useState(!reduced);
	const [active, setActive] = React.useState(0);
	useLiveNames();
	const headEnter = useSurfaceEnter(reduced, 0.05);
	const onClose = props.onClose;
	const requestClose = React.useCallback(() => {
		if (exiting) {
			return;
		}
		Audio.play("close");
		beginExit(onClose);
	}, [beginExit, exiting, onClose]);

	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const pad = stack ? 12 : SurfaceMetrics.pad + 4;
	const safeSide = math.max(8, viewport.sideInset, chrome.sideSafe);
	const safeTop = math.max(8, viewport.topInset);
	const safeBottom = math.max(8, viewport.bottomInset, chrome.bottomSafe);
	const width = math.min(940, math.max(260, viewport.width - safeSide * 2 - 12));
	const height = math.min(680, math.max(260, viewport.height - safeTop - safeBottom - 12));
	const centerY = safeTop + math.max(0, (viewport.height - safeTop - safeBottom) / 2);
	const innerW = width - pad * 2;

	const visible = CreditsModel.visible(MODEL, "All", query);
	const chapterTabs: Tab[] = visible.map((entry) => ({
		id: entry.category.Id,
		label: entry.category.Label,
		count: entry.members.size(),
		accent: entry.category.Accent,
	}));
	const showTabs = MODEL.CategoryTabs === true && chapterTabs.size() > 1;
	const showSearch = CreditsModel.showSearch(MODEL);
	// wide: chapters in a rail on the left; narrow: a row of chapter chips above the reel
	const rail = showTabs && !stack && innerW >= 720;
	const mainX = rail ? RAIL_W + 16 : 0;
	const mainW = innerW - mainX;
	const headerH = 52;
	const chipsH = !rail && showTabs ? CHIP_ROW_H + GAP : 0;
	const searchH = !rail && showSearch ? TapTarget + GAP : 0;
	const reelTop = headerH + chipsH + searchH;
	const reelH = math.max(120, height - pad * 2 - reelTop);
	const contentW = mainW - REEL_PAD * 2 - 6;

	// the clock runs the drift, the embers, the glints and the avatar rings; it sleeps under reduced motion
	// and while the game is struggling
	const clockOn = !reduced && !antilag.constrained;
	const [scrollB, setScrollB] = React.useMemo(() => React.createBinding(0), []);
	const [clockB, setClockB] = React.useMemo(() => React.createBinding(0), []);
	const clock = clockOn ? clockB : undefined;

	// ── the reel's layout: every block has a known top, so each can reveal itself as it nears the window
	const replayRef = React.useRef<() => void>(() => {});
	const hubRef = React.useRef<Hub>({ y: 0, h: reelH, listeners: new Set() });
	const hub = hubRef.current;
	hub.h = reelH;
	const cols = math.max(1, math.min(2, CreditsModel.columns(MODEL, contentW, PLATE_GAP)));
	let anyNote = false;
	for (const entry of visible) {
		for (const member of entry.members) {
			if (MODEL.ShowNotes !== false && member.Note !== "") {
				anyNote = true;
			}
		}
	}
	const plateH = anyNote ? 112 : 88;
	const heroH = stack ? 150 : 176;
	const subline = [MODEL.ShowVersion === true && props.version !== undefined ? `Version ${props.version}` : "", MODEL.Tagline]
		.filter((part) => part !== "")
		.join("  ·  ");

	const reelItems: React.Element[] = [];
	const chapterTops: number[] = [];
	let y = 0;
	reelItems.push(<Hero key="hero" hub={hub} top={y} width={contentW} height={heroH} subline={subline} reduced={reduced} clock={clock} />);
	y += heroH + 24;
	for (const [ci, entry] of ipairs(visible)) {
		const accent = tone(entry.category.Accent, Palette.violet);
		chapterTops.push(y);
		reelItems.push(
			<ChapterHead key={`h:${entry.category.Id}`} hub={hub} top={y} width={contentW} index={ci} category={entry.category} accent={accent} reduced={reduced} />,
		);
		y += HEAD_H + 14;
		if (entry.members.size() === 0) {
			reelItems.push(
				<frame key={`e:${entry.category.Id}`} Size={UDim2.fromOffset(contentW, 28)} Position={UDim2.fromOffset(0, y)} BackgroundTransparency={1} ZIndex={2}>
					<SurfaceText text={entry.category.EmptyText !== "" ? entry.category.EmptyText : MODEL.DefaultEmptyText} type="body" color={Palette.muted} />
				</frame>,
			);
			y += 28;
		} else {
			// a chapter with fewer people than columns gives each a wider plate
			const entryCols = math.max(1, math.min(cols, entry.members.size()));
			const entryW = math.floor((contentW - PLATE_GAP * (entryCols - 1)) / entryCols);
			entry.members.forEach((member, mi) => {
				const row = math.floor(mi / entryCols);
				const col = mi % entryCols;
				reelItems.push(
					<Plate
						key={memberKey(entry.category, member)}
						member={member}
						category={entry.category}
						accent={accent}
						hub={hub}
						left={col * (entryW + PLATE_GAP)}
						top={y + row * (plateH + PLATE_GAP)}
						width={entryW}
						height={plateH}
						delay={MODEL.EntranceStagger !== false ? math.min(mi, 6) * 0.07 : 0}
						reduced={reduced}
						clock={clock}
					/>,
				);
			});
			const rows = math.ceil(entry.members.size() / entryCols);
			y += rows * plateH + (rows - 1) * PLATE_GAP;
		}
		y += CHAPTER_GAP;
	}
	if (visible.size() === 0) {
		reelItems.push(
			<frame key="none" Size={UDim2.fromOffset(contentW, 40)} Position={UDim2.fromOffset(0, y)} BackgroundTransparency={1} ZIndex={2}>
				<SurfaceText
					text={query !== "" ? `No one called "${query}"` : MODEL.DefaultEmptyText}
					type="body"
					color={Palette.muted}
					align={Enum.TextXAlignment.Center}
				/>
			</frame>,
		);
		y += 60;
	}
	const smallPrint = table.clone(MODEL.Acknowledgements);
	const finaleTop = y;
	reelItems.push(<Finale key="finale" hub={hub} top={finaleTop} width={contentW} lines={smallPrint} reduced={reduced} clock={clock} onReplay={() => replayRef.current()} />);
	const canvasH = finaleTop + FINALE_H + 24;
	const maxScroll = math.max(0, canvasH - reelH);

	// ── scrolling: spy, auto-roll, jumps
	const scrollRef = React.useRef<ScrollingFrame>();
	const rollingRef = React.useRef(rolling);
	rollingRef.current = rolling;
	const userUntil = React.useRef(0);
	const rolledFor = React.useRef(0);
	const expectedY = React.useRef(0);
	const jump = React.useRef<Jump | undefined>(undefined);
	const maxRef = React.useRef(maxScroll);
	maxRef.current = maxScroll;
	const topsRef = React.useRef<number[]>(chapterTops);
	topsRef.current = chapterTops;
	const activeRef = React.useRef(0);

	const onScroll = (value: number) => {
		hub.y = value;
		setScrollB(value);
		for (const listener of hub.listeners) {
			listener(value);
		}
		if (math.abs(value - expectedY.current) > 2) {
			userUntil.current = os.clock() + USER_PAUSE;
			expectedY.current = value;
		}
		const tops = topsRef.current;
		let index = 0;
		for (const [i, top] of ipairs(tops)) {
			if (top <= value + 70) {
				index = i - 1;
			}
		}
		if (maxRef.current > 0 && value >= maxRef.current - 4 && tops.size() > 0) {
			index = tops.size() - 1;
		}
		if (index !== activeRef.current) {
			activeRef.current = index;
			setActive(index);
		}
	};
	const place = (target: number) => {
		const scroller = scrollRef.current;
		if (scroller === undefined) {
			return;
		}
		const clamped = math.clamp(target, 0, maxRef.current);
		expectedY.current = clamped;
		scroller.CanvasPosition = new Vector2(0, clamped);
	};
	const jumpTo = (target: number) => {
		const scroller = scrollRef.current;
		if (scroller === undefined) {
			return;
		}
		userUntil.current = os.clock() + USER_PAUSE;
		if (reduced) {
			place(target);
			return;
		}
		jump.current = { from: scroller.CanvasPosition.Y, to: math.clamp(target, 0, maxRef.current), started: os.clock() };
	};
	const pickChapter = (id: string) => {
		for (const [i, entry] of ipairs(visible)) {
			if (entry.category.Id === id) {
				Audio.play("tabSwitch");
				jumpTo(math.max(0, (topsRef.current[i - 1] ?? 0) - 10));
				return;
			}
		}
	};
	replayRef.current = () => {
		Audio.play("confirm");
		rolledFor.current = 0;
		setRolling(true);
		jumpTo(0);
	};
	const step = (direction: number) => {
		const tops = topsRef.current;
		const target = math.clamp(activeRef.current + direction, 0, math.max(0, tops.size() - 1));
		const top = tops[target];
		if (top !== undefined) {
			Audio.play("tabSwitch");
			jumpTo(math.max(0, top - 10));
		}
	};
	const stepRef = React.useRef(step);
	stepRef.current = step;

	// one heartbeat: the clock, the auto-roll and the chapter jumps
	React.useEffect(() => {
		let acc = 0;
		let t = 0;
		const connection = RunService.Heartbeat.Connect((dt) => {
			if (clockOn) {
				acc += dt;
				if (acc >= CLOCK_STEP) {
					t += acc;
					acc = 0;
					setClockB(t);
				}
			}
			const scroller = scrollRef.current;
			if (scroller === undefined) {
				return;
			}
			const now = os.clock();
			const move = jump.current;
			if (move !== undefined) {
				const a = clamp01((now - move.started) / JUMP_SECONDS);
				place(move.from + (move.to - move.from) * MotionTokens.EASE.decelerate(a));
				if (a >= 1) {
					jump.current = undefined;
				}
				return;
			}
			if (!rollingRef.current || now < userUntil.current) {
				rolledFor.current = 0;
				return;
			}
			const current = scroller.CanvasPosition.Y;
			if (current >= maxRef.current - 0.5) {
				setRolling(false);
				return;
			}
			rolledFor.current += dt;
			place(current + ROLL_SPEED * clamp01(rolledFor.current / ROLL_RAMP) * dt);
		});
		return () => connection.Disconnect();
	}, [clockOn]);

	// LB / RB step through the chapters
	React.useEffect(() => {
		if (!showTabs) {
			return undefined;
		}
		const connection = UserInputService.InputBegan.Connect((input) => {
			const direction = input.KeyCode === Enum.KeyCode.ButtonR1 ? 1 : input.KeyCode === Enum.KeyCode.ButtonL1 ? -1 : 0;
			if (direction !== 0) {
				stepRef.current(direction);
			}
		});
		return () => connection.Disconnect();
	}, [showTabs]);
	React.useEffect(() => {
		ClientLog.debug("nav", "credits opened");
		return () => ClientLog.debug("nav", "credits closed");
	}, []);
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.Escape && !processed) {
				requestClose();
			}
		});
		return () => connection.Disconnect();
	}, [requestClose]);
	useBackLayer(true, requestClose);

	// gamepad: the overlay owns focus while open and starts on its first button
	const padFocus = useGamepadAutofocus(true);
	const hostRef = React.useRef<Frame>();
	React.useEffect(() => {
		GamepadNavigationService.BeginOverlayFocus();
		return () => GamepadNavigationService.EndOverlayFocus();
	}, []);
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host: Instance | undefined = hostRef.current ?? padFocus.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, []);

	const activeAccent = tone(chapterTabs[active]?.accent ?? "mango", Palette.mango);
	const rollLabel = rolling ? "Pause" : "Roll";
	const rollW = 96;
	const toggleRoll = () => {
		Audio.play("tick");
		if (!rolling && scrollRef.current !== undefined && scrollRef.current.CanvasPosition.Y >= maxRef.current - 1) {
			replayRef.current();
			return;
		}
		rolledFor.current = 0;
		userUntil.current = 0;
		setRolling(!rolling);
	};

	return (
		<OverlayPresence amount={reveal}>
			<frame key="CreditsClaimActions" ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={320}>
				{/* tap outside the panel closes */}
				<imagebutton
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={new Color3(0, 0, 0)}
					BackgroundTransparency={reveal.map((a) => 1 - 0.55 * a)}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Selectable={false}
					ZIndex={320}
					Event={{ Activated: requestClose }}
				/>
				<frame
					Size={UDim2.fromOffset(width, height)}
					Position={reveal.map((a) => UDim2.fromOffset(viewport.width / 2, centerY + revealOffset(a)))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Active={true}
					ZIndex={321}
				>
					<Surface appear={reveal} padding={pad} active={true} zIndex={321}>
						{/* header */}
						<SurfaceText
							text={MODEL.Eyebrow}
							type="label"
							color={Palette.mango}
							size={new UDim2(1, -(TapTarget + rollW + 24), 0, 16)}
							position={UDim2.fromOffset(0, 6)}
							transparency={headEnter.map((a) => 1 - clamp01(a))}
							zIndex={322}
						/>
						<SurfaceText
							text={rolling ? "Rolling" : "Paused"}
							type="small"
							color={Palette.creamSoft}
							size={new UDim2(1, -(TapTarget + rollW + 24), 0, 16)}
							position={UDim2.fromOffset(0, 26)}
							transparency={headEnter.map((a) => 1 - clamp01(a))}
							zIndex={322}
						/>
						<Button
							text={rollLabel}
							onClick={toggleRoll}
							size={UDim2.fromOffset(rollW, TapTarget)}
							position={new UDim2(1, -(TapTarget + rollW + 10), 0, 0)}
							outline={true}
							reducedMotion={reduced}
							zIndex={323}
						/>
						<Button
							icon="Close.24"
							onClick={requestClose}
							size={UDim2.fromOffset(TapTarget, TapTarget)}
							position={new UDim2(1, -TapTarget, 0, 0)}
							outline={true}
							reducedMotion={reduced}
							zIndex={323}
						/>
						{/* chapters: rail (wide) */}
						{rail && (
							<frame
								Size={new UDim2(0, RAIL_W, 1, -headerH)}
								Position={UDim2.fromOffset(0, headerH)}
								BackgroundTransparency={1}
								ZIndex={322}
							>
								<RailMarker index={active} accent={activeAccent} reduced={reduced} />
								<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} ZIndex={322}>
									<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, SurfaceMetrics.rowGap)} />
									{chapterTabs.map((entry, i) => (
										<SectionPick key={entry.id} tab={entry} active={i === active} order={i} reducedMotion={reduced} onPick={pickChapter} />
									))}
									{showSearch && (
										<frame
											key="search"
											Size={new UDim2(1, 0, 0, TapTarget + GAP)}
											LayoutOrder={chapterTabs.size() + 1}
											BackgroundTransparency={1}
											ZIndex={322}
										>
											<SearchField
												value={query}
												onChange={setQuery}
												placeholder="Find someone"
												size={new UDim2(1, 0, 0, TapTarget)}
												position={UDim2.fromOffset(0, GAP)}
												reducedMotion={reduced}
												zIndex={323}
											/>
										</frame>
									)}
								</frame>
							</frame>
						)}
						{/* chapters: chips (narrow) */}
						{!rail && showTabs && (
							<scrollingframe
								Size={new UDim2(1, 0, 0, CHIP_ROW_H)}
								Position={UDim2.fromOffset(0, headerH)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								CanvasSize={new UDim2()}
								AutomaticCanvasSize={Enum.AutomaticSize.X}
								ScrollingDirection={Enum.ScrollingDirection.X}
								ScrollBarThickness={0}
								ZIndex={322}
							>
								<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
								{chapterTabs.map((entry, i) => (
									<SectionPick
										key={entry.id}
										tab={entry}
										active={i === active}
										order={i}
										width={new UDim(0, chipWidth(entry))}
										reducedMotion={reduced}
										onPick={pickChapter}
									/>
								))}
							</scrollingframe>
						)}
						{!rail && showSearch && (
							<SearchField
								value={query}
								onChange={setQuery}
								placeholder="Find someone"
								size={new UDim2(1, 0, 0, TapTarget)}
								position={UDim2.fromOffset(0, headerH + chipsH)}
								reducedMotion={reduced}
								zIndex={323}
							/>
						)}
						{/* the reel */}
						<frame
							Size={UDim2.fromOffset(mainW, reelH)}
							Position={UDim2.fromOffset(mainX, reelTop)}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.55}
							BorderSizePixel={0}
							ClipsDescendants={true}
							ZIndex={322}
						>
							<uicorner CornerRadius={new UDim(0, SurfaceMetrics.radius)} />
							<uistroke Color={Palette.lineSoft} Thickness={1} Transparency={0.7} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
							<Backdrop width={mainW} height={reelH} scroll={scrollB} clock={clock} />
							<scrollingframe
								ref={scrollRef}
								Size={UDim2.fromScale(1, 1)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								CanvasSize={UDim2.fromOffset(0, canvasH)}
								AutomaticCanvasSize={Enum.AutomaticSize.None}
								ScrollingDirection={Enum.ScrollingDirection.Y}
								ScrollBarThickness={3}
								ScrollBarImageColor3={Palette.muted}
								ZIndex={2}
								Change={{ CanvasPosition: (rbx: ScrollingFrame) => onScroll(rbx.CanvasPosition.Y) }}
								Event={{
									InputChanged: (_rbx: ScrollingFrame, input: InputObject) => {
										if (input.UserInputType === Enum.UserInputType.MouseWheel) {
											userUntil.current = os.clock() + USER_PAUSE;
										}
									},
									InputBegan: (_rbx: ScrollingFrame, input: InputObject) => {
										if (input.UserInputType === Enum.UserInputType.Touch || input.UserInputType === Enum.UserInputType.MouseButton1) {
											userUntil.current = os.clock() + USER_PAUSE;
										}
									},
								}}
							>
								<frame Size={UDim2.fromOffset(contentW, canvasH)} Position={UDim2.fromOffset(REEL_PAD, 0)} BackgroundTransparency={1}>
									{reelItems}
								</frame>
							</scrollingframe>
							{/* the reel fades into its edges */}
							<frame
								ref={ignoreGuard}
								Size={new UDim2(1, 0, 0, 22)}
								BackgroundColor3={Palette.panel}
								BackgroundTransparency={0}
								BorderSizePixel={0}
								Active={false}
								ZIndex={3}
							>
								<uigradient Rotation={90} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.1), new NumberSequenceKeypoint(1, 1)])} />
							</frame>
							<frame
								ref={ignoreGuard}
								Size={new UDim2(1, 0, 0, 30)}
								Position={new UDim2(0, 0, 1, -30)}
								BackgroundColor3={Palette.panel}
								BackgroundTransparency={0}
								BorderSizePixel={0}
								Active={false}
								ZIndex={3}
							>
								<uigradient Rotation={90} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(1, 0.1)])} />
							</frame>
						</frame>
					</Surface>
				</frame>
			</frame>
		</OverlayPresence>
	);
}
