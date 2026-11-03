// Ranks: the Hall of Records.
//
// An index of every board runs down the left (grouped, with the scope switch on top) and the board
// itself reads on the right like a printed ledger instead of a grid of cards: a masthead that says
// where you sit and how far the next seat is (a short ladder between the seat below and the seat
// above), three forged plaques for the top of the board, then ruled rows whose bottom edge is also the
// meter of how close each pilot is to the leader. Nothing glows; the only light is the strike: seats
// arrive white-hot and cool into their metal, and a plaque takes one sheen as it lands.
// When your row scrolls out of view it is pinned to the edge it left from; tap it (or R3) to go back.
// Phones swap the index for a strip of boards and drop the plaques so the whole list stays one column.
import React from "@rbxts/react";
import * as ProfileStyle from "../../Shared/AstralForge/Shared/ProfileStyle";
import { frameStroke } from "./CoreKit/profileFrame";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import { Audio } from "./AudioKit/audio";
import { InteractionFeedback } from "./CoreKit/interaction";
import { useClock, useFlipperSpring, useMotionSettings, useViewport } from "./MotionKit/motion";
import * as MotionTokens from "./MotionKit/motionTokens";
import { FocusClaim, KeyLabel } from "./CoreKit/GamepadNavigationService";
import { OmegaMathApi } from "./lua";
import { FittedView } from "./UiCore/viewportKit";
import { live as liveAntilag } from "./MotionKit/antilagState";

const Players = game.GetService("Players");
const TweenService = game.GetService("TweenService");
const ContextActionService = game.GetService("ContextActionService");
const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const Math = require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript) as OmegaMathApi;

interface SocialApi {
	rank(this: void, entries: unknown[], guildBoard: boolean): RankRow[];
}
const SocialProgression = require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SocialProgression") as ModuleScript) as (math: OmegaMathApi) => SocialApi;
const Social = SocialProgression(Math);

interface UiApi {
	SearchField: unknown;
}
const UiCore = require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as CallableFunction;
const ui = UiCore("ui") as UiApi;

interface ArtApi {
	Icon: unknown;
}
const ArtKit = require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction;
const Art = ArtKit("Icon") as ArtApi;

interface ScaffoldApi {
	PageScaffold: unknown;
}
const LayoutKit = require(script.Parent!.FindFirstChild("LayoutKit")! as ModuleScript) as CallableFunction;
const Scaffold = (LayoutKit("pageScaffold") as ScaffoldApi).PageScaffold;

const P = theme.Palette;
const e = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

interface RankRow {
	Name?: string;
	Tag?: string;
	UserId?: number;
	Id?: string;
	Value: unknown;
}

interface BoardMeta {
	id: string;
	short?: string;
	label: string;
	icon: string;
	accent: Color3;
	group: string;
	description: string;
}

interface GroupMeta {
	id: string;
	label: string;
}

interface Helpers {
	boards: BoardMeta[];
	metaFor(this: void, id: string): BoardMeta;
	serverEntries(this: void, players: unknown[], id: string): unknown[];
	ownValue(this: void, state: Record<string, unknown>, id: string): unknown;
	formatValue(this: void, id: string, value: unknown): string;
	scoreCounts(this: void, id: string, value: unknown): boolean;
}

interface Props {
	dispatch: (action: string, payload: Record<string, unknown> | {}, callback: (reply: unknown) => void) => void;
	state: Record<string, unknown>;
	reducedMotion?: boolean;
}

interface Result {
	rows: RankRow[];
	loading: boolean;
	failed: boolean;
	at?: number;
}

const GROUPS: GroupMeta[] = [
	{ id: "Economy", label: "Economy" },
	{ id: "Progression", label: "Progression" },
	{ id: "Activity", label: "Activity" },
	{ id: "Collection", label: "Collection" },
	{ id: "Social", label: "Guilds" },
];

const GUILD_META: BoardMeta = { id: "Guilds", short: "Guilds", label: "Guild Halls", icon: "Guild.3", accent: P.violet, group: "Social", description: "Guild activity earned by banking and building together." };

const RAIL_W = 232;
const RAIL_GAP = 28;
const RAIL_MIN = 940;
const SEAT_CAP = 100;
const HOT = Color3.fromRGB(255, 168, 84);

// the three metals; the plaque, its tag and every number on it take their color from here
interface Metal {
	tone: Color3;
	ink: Color3;
	tag: string;
	caption: string;
}
const METAL: Record<number, Metal> = {
	[1]: { tone: Color3.fromRGB(236, 182, 92), ink: Color3.fromRGB(44, 30, 8), tag: "1ST", caption: "LEADS THE BOARD" },
	[2]: { tone: Color3.fromRGB(200, 210, 232), ink: Color3.fromRGB(24, 28, 40), tag: "2ND", caption: "SECOND SEAT" },
	[3]: { tone: Color3.fromRGB(206, 130, 86), ink: Color3.fromRGB(40, 20, 10), tag: "3RD", caption: "THIRD SEAT" },
};

// podium plaques step down from the champion; the tallest lands last
const PLAQUE_H: Record<number, number> = { [1]: 372, [2]: 326, [3]: 292 };
const PLAQUE_DELAY: Record<number, number> = { [1]: 0.34, [2]: 0.16, [3]: 0 };
const PODIUM_H = 372;
const SHEEN = new NumberSequence([
	new NumberSequenceKeypoint(0, 1),
	new NumberSequenceKeypoint(0.4, 1),
	new NumberSequenceKeypoint(0.5, 0.9),
	new NumberSequenceKeypoint(0.6, 1),
	new NumberSequenceKeypoint(1, 1),
]);

function share(value: unknown, top: unknown): number {
	if (!Math.Gt(top, 0)) {
		return 0;
	}
	const ratio = Math.ToNumber(Math.Div(value, top));
	if (ratio !== ratio) {
		return 0;
	}
	return math.clamp(ratio, 0, 1);
}

function matchesRank(row: RankRow, query: string): boolean {
	const [trimmed] = tostring(query ?? "").lower().match("^%s*(.-)%s*$");
	const needle = typeIs(trimmed, "string") ? trimmed : "";
	const name: string = tostring(row.Name ?? "");
	const tag: string = tostring(row.Tag ?? "");
	const id: string = row.UserId !== undefined ? tostring(row.UserId) : row.Id !== undefined ? tostring(row.Id) : "";
	const haystack: string = `${name} ${tag} ${id}`.lower();
	const [found] = string.find(haystack, needle, 1, true);
	return needle === "" || found !== undefined;
}

function ordinal(n: number): string {
	const tail = n % 100;
	if (tail >= 11 && tail <= 13) {
		return "TH";
	}
	const last = n % 10;
	return last === 1 ? "ST" : last === 2 ? "ND" : last === 3 ? "RD" : "TH";
}

function seatText(place: number): string {
	return place < 10 ? `0${place}` : tostring(place);
}

function ageText(seconds: number): string {
	if (seconds < 5) {
		return "JUST NOW";
	}
	if (seconds < 60) {
		return `${math.floor(seconds)}S AGO`;
	}
	return `${math.floor(seconds / 60)}M AGO`;
}

function escapeRich(text: string): string {
	const [amp] = text.gsub("&", "&amp;");
	const [lt] = amp.gsub("<", "&lt;");
	const [gt] = lt.gsub(">", "&gt;");
	return gt;
}

function slice(value: number, from: number, to: number): number {
	return math.clamp((value - from) / (to - from), 0, 1);
}

function thumb(userId: number): string {
	return `rbxthumb://type=AvatarHeadShot&id=${userId > 0 ? userId : 1}&w=150&h=150`;
}

// cosmetic layers (watermarks, the ladder, sheens) are not the layout guard's business
function ignoreGuard(instance: Instance | undefined) {
	if (instance !== undefined) {
		instance.SetAttribute("LayoutGuardIgnore", true);
	}
}

const faces = new Map<Enum.FontWeight, Font>();
function face(weight: Enum.FontWeight): Font {
	let font = faces.get(weight);
	if (font === undefined) {
		font = Font.fromName("BuilderSans", weight);
		faces.set(weight, font);
	}
	return font;
}

// ── Motion ─────────────────────────────────────────────────────────────────────

/** 0 -> 1 once on mount, on the settle spring; instant with Reduced Motion. Remount (key) to replay. */
function useArrival(reduced: boolean | undefined): React.Binding<number> {
	const [goal, setGoal] = React.useState(reduced === true ? 1 : 0);
	React.useEffect(() => {
		setGoal(1);
	}, [reduced]);
	const spring = MotionTokens.SPRING.settle;
	return useFlipperSpring(goal, reduced === true, spring.stiffness, spring.damping, reduced === true ? 1 : 0);
}

/** hover/selection amount on the house spring */
function useLit(goal: number, reduced: boolean | undefined): React.Binding<number> {
	const spring = MotionTokens.SPRING.smooth;
	return useFlipperSpring(goal, reduced === true, spring.stiffness, spring.damping);
}

// ── Type ───────────────────────────────────────────────────────────────────────

interface LabelProps {
	text: string;
	size?: number;
	weight?: Enum.FontWeight;
	color?: Color3 | React.Binding<Color3>;
	alpha?: number | React.Binding<number>;
	at?: UDim2 | React.Binding<UDim2>;
	box?: UDim2;
	anchor?: Vector2;
	align?: Enum.TextXAlignment;
	yAlign?: Enum.TextYAlignment;
	wrap?: boolean;
	fit?: boolean;
	minSize?: number;
	rich?: boolean;
	auto?: boolean;
	decor?: boolean;
	order?: number;
	z?: number;
}

function Label(props: LabelProps) {
	const settings = useMotionSettings();
	const base = props.size ?? 13;
	// big numerals keep their drawn size; running text follows the Text Size setting
	const scale = base > 26 ? 1 : settings.textScale;
	const size = math.clamp(math.floor(base * scale + 0.5), 11, 160);
	let weight = props.weight ?? Enum.FontWeight.Medium;
	if (weight === Enum.FontWeight.Medium && (settings.boldText ?? 0) >= 0.5) {
		weight = Enum.FontWeight.Bold;
	}
	const shrink = props.fit === true && props.auto !== true;
	const box = props.box ?? UDim2.fromScale(1, 1);
	return (
		<textlabel
			ref={props.decor === true ? ignoreGuard : undefined}
			Size={props.auto === true ? new UDim2(0, 0, box.Y.Scale, box.Y.Offset) : box}
			AutomaticSize={props.auto === true ? Enum.AutomaticSize.X : Enum.AutomaticSize.None}
			Position={props.at}
			AnchorPoint={props.anchor}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text={props.text}
			RichText={props.rich === true}
			FontFace={face(weight)}
			TextSize={size}
			TextScaled={shrink}
			TextColor3={props.color ?? P.cream}
			TextTransparency={props.alpha ?? 0}
			TextWrapped={props.wrap === true}
			TextXAlignment={props.align ?? Enum.TextXAlignment.Left}
			TextYAlignment={props.yAlign ?? (props.wrap === true ? Enum.TextYAlignment.Top : Enum.TextYAlignment.Center)}
			TextTruncate={props.wrap === true || shrink ? Enum.TextTruncate.None : Enum.TextTruncate.AtEnd}
			ZIndex={props.z}
		>
			{shrink && <uitextsizeconstraint MinTextSize={props.minSize ?? 11} MaxTextSize={size} />}
		</textlabel>
	);
}

function Rule(props: { at: UDim2; width: UDim; alpha?: number; color?: Color3 }) {
	return (
		<frame
			Position={props.at}
			Size={new UDim2(props.width, new UDim(0, 1))}
			BackgroundColor3={props.color ?? P.lineSoft}
			BackgroundTransparency={props.alpha ?? 0.6}
			BorderSizePixel={0}
		/>
	);
}

// ── Avatar ─────────────────────────────────────────────────────────────────────

interface AvatarViewProps {
	userId: number;
	reducedMotion?: boolean;
	size: UDim2;
	position?: UDim2;
}

function AvatarView(props: AvatarViewProps): React.Element {
	const ref = React.useRef<ViewportFrame>();
	const scene = React.useRef<{ view: FittedView; target: Vector3; size: Vector3 } | undefined>(undefined);
	const [status, setStatus] = React.useState<string | undefined>("Loading avatar…");
	const [revision, retry] = React.useState(0);
	const [angle, turn] = React.useState(0);
	const previousAngle = React.useRef(0);

	React.useEffect(() => {
		const viewport = ref.current;
		if (viewport === undefined) {
			return undefined;
		}
		let alive = true;
		const world = new Instance("WorldModel");
		world.Parent = viewport;
		const view = new FittedView(viewport, 34);
		setStatus("Loading avatar…");
		const timeout = task.delay(12, () => {
			if (alive && scene.current === undefined) {
				setStatus("Avatar taking too long. Tap to retry.");
			}
		});
		task.spawn(() => {
			const [ok, model] = pcall(() => Players.CreateHumanoidModelFromUserIdAsync(User.fromId(props.userId)));
			if (!alive) {
				if (ok && typeIs(model, "Instance")) {
					model.Destroy();
				}
				return;
			}
			if (!ok) {
				warn(`Ranks avatar ${props.userId}: ${model}`);
				setStatus("Avatar unavailable. Tap to retry.");
				return;
			}
			const humanoidModel = model as Model;
			for (const item of humanoidModel.GetDescendants()) {
				if (item.IsA("LuaSourceContainer")) {
					item.Destroy();
				} else if (item.IsA("BasePart")) {
					item.Anchored = item.Name === "HumanoidRootPart";
					item.CanCollide = false;
				}
			}
			humanoidModel.PivotTo(new CFrame());
			humanoidModel.Parent = world;
			task.wait();
			if (!alive) {
				humanoidModel.Destroy();
				return;
			}
			const [bounds, size] = humanoidModel.GetBoundingBox();
			view.setModel(humanoidModel);
			scene.current = { view, target: bounds.Position, size };
			setStatus(undefined);
		});
		return () => {
			alive = false;
			task.cancel(timeout);
			scene.current = undefined;
			viewport.CurrentCamera = undefined;
			world.Destroy();
			view.destroy();
		};
	}, [props.userId, revision]);

	React.useEffect(() => {
		const viewport = ref.current!;
		const current = scene.current!;
		if (current === undefined || viewport === undefined) {
			return undefined;
		}
		let tween: Tween | undefined;
		function fit(animate: boolean) {
			if (!current.view.ready()) {
				return;
			}
			if (tween !== undefined) {
				tween.Cancel();
			}
			const yaw = math.rad(angle);
			// face the avatar from this yaw, slightly above, with a little air around it
			const orientation = CFrame.lookAt(new Vector3(math.sin(yaw), 0.08, -math.cos(yaw)), Vector3.zero);
			const target = current.view.frame(orientation, 0.08);
			if (animate && !props.reducedMotion) {
				tween = TweenService.Create(current.view.camera, new TweenInfo(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame: target });
				tween.Play();
			} else {
				current.view.camera.CFrame = target;
			}
		}
		fit(previousAngle.current !== angle);
		previousAngle.current = angle;
		current.view.onFit = () => fit(false);
		return () => {
			current.view.onFit = undefined;
			if (tween !== undefined) {
				tween.Cancel();
			}
		};
	}, [status, angle, props.reducedMotion]);

	// the whole figure is the button: tap to turn it (or to try again when it didn't load)
	return (
		<frame {...{ Name: "RankAvatar" }} Size={props.size} Position={props.position} BackgroundTransparency={1}>
			<viewportframe
				ref={ref}
				{...{ Name: "AvatarViewport" }}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Ambient={Color3.fromRGB(180, 185, 205)}
				LightColor={Color3.fromRGB(255, 235, 215)}
				LightDirection={new Vector3(-1, -1, -2)}
			/>
			{status !== undefined && (
				<Label text={status} size={12} color={P.creamSoft} wrap={true} fit={true} minSize={10} align={Enum.TextXAlignment.Center} yAlign={Enum.TextYAlignment.Center} box={new UDim2(1, -24, 1, 0)} at={UDim2.fromOffset(12, 0)} />
			)}
			<textbutton
				{...{ Name: "Turn" }}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				AutoButtonColor={false}
				Text=""
				ZIndex={3}
				Event={{
					Activated: () => {
						Audio.play("tabSwitch");
						if (status !== undefined) {
							if (status !== "Loading avatar…") {
								retry((v) => v + 1);
							}
						} else {
							turn((v) => (v === 0 ? 30 : v === 30 ? -30 : 0));
						}
					},
				}}
			/>
		</frame>
	);
}

// ── Rows ───────────────────────────────────────────────────────────────────────

/**
 * Profile-style hook for rank rows (plaque names, ledger rows and the pinned "you" row).
 * Return an accent to tint the row's headshot ring and name. Undefined keeps the board's default colors.
 */
function rankRowStyle(row: RankRow, guildBoard: boolean): { accent?: Color3; frame?: ProfileStyle.FrameOption } | undefined {
	// only players in this server publish their style attributes; everyone else keeps the default look
	if (guildBoard || !typeIs(row.UserId, "number")) {
		return undefined;
	}
	const style = ProfileStyle.fromPlayer(game.GetService("Players").GetPlayerByUserId(row.UserId));
	return style.accent !== undefined || style.frame !== undefined ? { accent: style.accent, frame: style.frame } : undefined;
}

interface Cols {
	placeW: number;
	markX: number;
	markSize: number;
	nameX: number;
	valueW: number;
	pctW: number;
	rowH: number;
}

function colsFor(contentW: number): Cols {
	if (contentW < 420) {
		return { placeW: 30, markX: 38, markSize: 28, nameX: 76, valueW: 100, pctW: 0, rowH: 48 };
	}
	return { placeW: 44, markX: 60, markSize: 34, nameX: 106, valueW: 150, pctW: contentW >= 700 ? 64 : 0, rowH: 56 };
}

// a guild's tag, set as a little stamped plate in place of a headshot
function GuildStamp(props: { tag: string; accent: Color3; size: number; at?: UDim2; anchor?: Vector2 }) {
	return (
		<frame
			Size={UDim2.fromOffset(props.size, props.size)}
			Position={props.at}
			AnchorPoint={props.anchor}
			BackgroundColor3={theme.darken(props.accent, 0.78)}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(0, math.floor(props.size * 0.22))} />
			<uistroke Color={props.accent} Transparency={0.35} Thickness={1.5} />
			<Label text={props.tag} size={math.max(11, math.floor(props.size * 0.3))} weight={Enum.FontWeight.Heavy} color={props.accent} align={Enum.TextXAlignment.Center} fit={true} minSize={9} box={new UDim2(1, -6, 1, 0)} at={UDim2.fromOffset(3, 0)} />
		</frame>
	);
}

interface RowProps {
	row: RankRow;
	place: number;
	mine: boolean;
	guild: boolean;
	accent: Color3;
	cols: Cols;
	y?: number;
	valueText: string;
	share: number;
	/** 0..1 arrival for the first rows of a list; later rows just appear */
	arrival?: React.Binding<number>;
	pinned?: boolean;
	hint?: string;
}

function LedgerRow(props: RowProps) {
	const { row, place, mine, guild, cols } = props;
	const [hover, setHover] = React.useBinding(0);
	const styled = rankRowStyle(row, guild);
	const tint = styled?.accent ?? (mine ? P.mint : props.accent);
	const ring = frameStroke(styled?.frame, tint, 1);
	const medal = METAL[place];
	const arrival = props.arrival;
	const fade = (rest: number): number | React.Binding<number> => (arrival !== undefined ? arrival.map((a) => 1 - (1 - rest) * a) : rest);
	const name = tostring(row.Name ?? "Unknown pilot");
	const nameColor = styled?.accent ?? (mine ? P.mint : P.cream);
	let nameText = name;
	let rich = false;
	if (mine || (guild && row.Tag !== undefined)) {
		rich = true;
		nameText = escapeRich(name);
		if (guild && row.Tag !== undefined) {
			nameText = `${nameText}  <font color="#${P.muted.ToHex()}">[${escapeRich(tostring(row.Tag))}]</font>`;
		}
		if (mine) {
			nameText = `${nameText}  <font color="#${P.mint.ToHex()}">YOU</font>`;
		}
	}
	const placeColor = medal !== undefined ? medal.tone : mine ? P.mint : P.muted;
	const rightPad = 12;
	const valueRight = rightPad + cols.pctW;
	return (
		<frame
			{...{ Name: `rank-row-${place}` }}
			Position={props.y !== undefined ? UDim2.fromOffset(0, props.y) : undefined}
			Size={new UDim2(1, 0, 0, cols.rowH)}
			BackgroundTransparency={1}
			Event={{
				MouseEnter: () => setHover(1),
				MouseLeave: () => setHover(0),
			}}
		>
			<frame
				{...{ Name: "Plate" }}
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={mine ? theme.darken(P.mint, 0.78) : P.panelSoft}
				BackgroundTransparency={
					props.pinned === true
						? 0.04
						: hover.map((h) => (mine ? 0.55 - 0.12 * h : 1 - 0.5 * h))
				}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
				{props.pinned === true && <uistroke Color={P.mint} Transparency={0.45} Thickness={1} />}
			</frame>
			<frame {...{ Name: "Flash" }} Size={UDim2.fromScale(1, 1)} BackgroundColor3={P.mint} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
				<uicorner CornerRadius={new UDim(0, 8)} />
			</frame>
			{mine && (
				<frame Size={new UDim2(0, 3, 0.56, 0)} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={P.mint} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			)}
			<Label
				text={seatText(place)}
				size={cols.placeW < 40 ? 13 : 16}
				weight={Enum.FontWeight.Bold}
				color={placeColor}
				alpha={fade(0)}
				align={Enum.TextXAlignment.Right}
				box={UDim2.fromOffset(cols.placeW, cols.rowH)}
				at={UDim2.fromOffset(2, 0)}
			/>
			{guild ? (
				<GuildStamp tag={tostring(row.Tag ?? "?")} accent={tint} size={cols.markSize} at={new UDim2(0, cols.markX, 0.5, 0)} anchor={new Vector2(0, 0.5)} />
			) : (
				<frame
					Size={UDim2.fromOffset(cols.markSize, cols.markSize)}
					Position={new UDim2(0, cols.markX, 0.5, 0)}
					AnchorPoint={new Vector2(0, 0.5)}
					BackgroundColor3={P.panelRaised}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={ring.color} Transparency={mine || ring.framed ? 0.15 : 0.7} Thickness={ring.thickness}>
						{ring.gradient !== undefined && <uigradient Color={ring.gradient} Rotation={35} />}
					</uistroke>
					<imagelabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Image={thumb(row.UserId ?? 0)} ImageTransparency={fade(0)}>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</imagelabel>
				</frame>
			)}
			<Label
				text={nameText}
				rich={rich}
				size={cols.rowH < 52 ? 14 : 15}
				weight={Enum.FontWeight.SemiBold}
				color={nameColor}
				alpha={fade(0)}
				box={new UDim2(1, -(cols.nameX + valueRight + cols.valueW + 8), 1, 0)}
				at={UDim2.fromOffset(cols.nameX, 0)}
			/>
			<Label
				text={props.valueText}
				size={cols.rowH < 52 ? 13 : 15}
				weight={Enum.FontWeight.Bold}
				alpha={fade(0)}
				align={Enum.TextXAlignment.Right}
				box={UDim2.fromOffset(cols.valueW, cols.rowH)}
				at={new UDim2(1, -(valueRight + cols.valueW), 0, 0)}
			/>
			{cols.pctW > 0 && (
				<Label
					text={props.pinned === true && props.hint !== undefined ? props.hint : `${math.floor(props.share * 100 + 0.5)}%`}
					size={props.pinned === true ? 11 : 12}
					weight={props.pinned === true ? Enum.FontWeight.Bold : Enum.FontWeight.Medium}
					color={props.pinned === true ? P.mint : P.muted}
					alpha={fade(0.1)}
					align={Enum.TextXAlignment.Right}
					box={UDim2.fromOffset(cols.pctW, cols.rowH)}
					at={new UDim2(1, -(rightPad + cols.pctW), 0, 0)}
				/>
			)}
			<frame {...{ Name: "Meter" }} Size={new UDim2(1, -(cols.markX + rightPad), 0, 3)} Position={new UDim2(0, cols.markX, 1, -3)} BackgroundTransparency={1}>
				<frame {...{ Name: "Track" }} Size={new UDim2(1, 0, 0, 1)} Position={new UDim2(0, 0, 1, -1)} BackgroundColor3={P.lineSoft} BackgroundTransparency={0.8} BorderSizePixel={0} />
				<frame
					{...{ Name: "Fill" }}
					Size={arrival !== undefined ? arrival.map((a) => new UDim2(props.share * a, 0, 0, 2)) : new UDim2(props.share, 0, 0, 2)}
					Position={new UDim2(0, 0, 1, -2)}
					BackgroundColor3={medal !== undefined ? medal.tone : tint}
					BackgroundTransparency={mine ? 0.1 : 0.35}
					BorderSizePixel={0}
				/>
			</frame>
		</frame>
	);
}

// ── Plaques ────────────────────────────────────────────────────────────────────

interface PlaqueProps {
	place: number;
	row: RankRow;
	mine: boolean;
	guild: boolean;
	valueText: string;
	share: number;
	caption: string;
	x: number;
	w: number;
	arrive: React.Binding<number>;
	reduced?: boolean;
}

function Plaque(props: PlaqueProps) {
	const { place, row, mine, guild, w } = props;
	const h = PLAQUE_H[place];
	const metal = METAL[place];
	const styled = rankRowStyle(row, guild);
	const arrival = props.arrive.map((a) => slice(a, PLAQUE_DELAY[place], PLAQUE_DELAY[place] + 0.6));
	const info = 112;
	const avatarH = h - 40 - info - 6;
	const name = tostring(row.Name ?? "Unknown");
	return (
		<frame
			{...{ Name: `PodiumSeat${place}` }}
			Position={UDim2.fromOffset(props.x, PODIUM_H - h)}
			Size={UDim2.fromOffset(w, h)}
			BackgroundColor3={P.panel}
			BackgroundTransparency={arrival.map((a) => 1 - 0.94 * a)}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={arrival.map((a) => HOT.Lerp(metal.tone, math.clamp(a * 1.25, 0, 1)))} Transparency={mine ? 0.1 : 0.4} Thickness={mine ? 2 : 1.5} />
			<frame {...{ Name: "Cap" }} Size={new UDim2(1, 0, 0, 3)} BackgroundColor3={metal.tone} BorderSizePixel={0} />
			<frame {...{ Name: "Inset" }} Position={UDim2.fromOffset(6, 9)} Size={new UDim2(1, -12, 1, -15)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 7)} />
				<uistroke Color={mine ? P.mint : metal.tone} Transparency={mine ? 0.5 : 0.86} Thickness={1} />
			</frame>
			<Label
				text={tostring(place)}
				size={math.floor(h * 0.5)}
				weight={Enum.FontWeight.Heavy}
				color={metal.tone}
				alpha={0.9}
				align={Enum.TextXAlignment.Right}
				decor={true}
				box={new UDim2(0.8, 0, 0.6, 0)}
				at={new UDim2(0.2, -14, 0, 14)}
			/>
			<frame {...{ Name: "Tag" }} Position={UDim2.fromOffset(18, 20)} Size={UDim2.fromOffset(44, 22)} BackgroundColor3={metal.tone} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 4)} />
				<Label text={metal.tag} size={12} weight={Enum.FontWeight.Heavy} color={metal.ink} align={Enum.TextXAlignment.Center} />
			</frame>
			<Label text={metal.caption} size={11} weight={Enum.FontWeight.Bold} color={P.muted} box={UDim2.fromOffset(w - 90, 22)} at={UDim2.fromOffset(72, 20)} />
			{guild ? (
				<GuildStamp tag={tostring(row.Tag ?? "?")} accent={metal.tone} size={place === 1 ? 92 : 76} at={new UDim2(0.5, 0, 0, 52 + avatarH / 2)} anchor={new Vector2(0.5, 0.5)} />
			) : liveAntilag.viewports ? (
				<AvatarView userId={row.UserId ?? 0} reducedMotion={props.reduced} size={new UDim2(0.8, 0, 0, avatarH)} position={new UDim2(0.1, 0, 0, 48)} />
			) : (
				// a slow machine gets the flat portrait: no 3D viewport, no avatar model to build and render
				<imagelabel
					Size={UDim2.fromOffset(math.min(avatarH, w * 0.8), math.min(avatarH, w * 0.8))}
					Position={new UDim2(0.5, 0, 0, 48 + avatarH / 2)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Image={`rbxthumb://type=AvatarBust&id=${row.UserId !== undefined && row.UserId > 0 ? row.UserId : 1}&w=420&h=420`}
				/>
			)}
			<Label
				text={mine ? `${name}  ·  YOU` : name}
				size={20}
				weight={Enum.FontWeight.Bold}
				color={styled?.accent ?? (mine ? P.mint : P.cream)}
				align={Enum.TextXAlignment.Center}
				fit={true}
				minSize={13}
				box={new UDim2(1, -36, 0, 30)}
				at={new UDim2(0, 18, 1, -info + 6)}
			/>
			<Label text={props.valueText} size={15} weight={Enum.FontWeight.Bold} color={metal.tone} align={Enum.TextXAlignment.Center} fit={true} minSize={11} box={new UDim2(1, -36, 0, 22)} at={new UDim2(0, 18, 1, -info + 38)} />
			<frame {...{ Name: "Meter" }} Size={new UDim2(1, -36, 0, 3)} Position={new UDim2(0, 18, 1, -info + 72)} BackgroundColor3={P.lineSoft} BackgroundTransparency={0.7} BorderSizePixel={0}>
				<frame Size={arrival.map((a) => new UDim2(props.share * a, 0, 1, 0))} BackgroundColor3={metal.tone} BorderSizePixel={0} />
			</frame>
			<Label text={props.caption} size={11} weight={Enum.FontWeight.Medium} color={P.muted} align={Enum.TextXAlignment.Center} box={new UDim2(1, -36, 0, 18)} at={new UDim2(0, 18, 1, -info + 80)} />
			<frame {...{ Name: "Flash" }} Size={UDim2.fromScale(1, 1)} BackgroundColor3={P.mint} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={6} />
			<frame ref={ignoreGuard} {...{ Name: "Sheen" }} Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(255, 244, 222)} BorderSizePixel={0} ZIndex={7}>
				<uigradient Rotation={20} Transparency={SHEEN} Offset={arrival.map((a) => new Vector2(-1.2 + 2.4 * slice(a, 0.55, 1), 0))} />
			</frame>
		</frame>
	);
}

function Podium(props: { plaques: Array<Omit<PlaqueProps, "arrive" | "reduced" | "x" | "w">>; width: number; reduced?: boolean }) {
	const arrive = useArrival(props.reduced);
	const gap = 14;
	const goldW = math.floor((props.width - gap * 2) * 0.4);
	const sideW = math.floor((props.width - gap * 2 - goldW) / 2);
	const only = props.plaques.size() === 1;
	const xs: Record<number, number> = { [2]: 0, [1]: sideW + gap, [3]: sideW + gap + goldW + gap };
	if (only) {
		xs[1] = math.floor((props.width - goldW) / 2);
	}
	const children: React.Element[] = [];
	for (const plaque of props.plaques) {
		children.push(<Plaque key={tostring(plaque.place)} {...plaque} x={xs[plaque.place]} w={plaque.place === 1 ? goldW : sideW} arrive={arrive} reduced={props.reduced} />);
	}
	return (
		<frame {...{ Name: "Podium" }} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{children}
		</frame>
	);
}

// ── Masthead ───────────────────────────────────────────────────────────────────

// your seat: arrives white-hot and cools into its metal (plain cream below the podium)
function Seat(props: { place?: number; size: number; reduced?: boolean }) {
	const arrive = useArrival(props.reduced);
	const place = props.place;
	const metal = place !== undefined ? METAL[place] : undefined;
	const rest = metal !== undefined ? metal.tone : place === undefined ? P.muted : P.cream;
	const color = arrive.map((a) => HOT.Lerp(rest, math.clamp(a, 0, 1) ** 1.5));
	const tail = math.floor(props.size * 0.17);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Bottom} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Label text={place !== undefined ? tostring(place) : "—"} size={place !== undefined ? props.size : math.floor(props.size * 0.6)} weight={Enum.FontWeight.Heavy} color={color} auto={true} box={UDim2.fromScale(0, 1)} order={1} />
			{place !== undefined && (
				<frame Size={UDim2.fromScale(0, 1)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} LayoutOrder={2}>
					<uipadding PaddingBottom={new UDim(0, tail)} />
					<Label text={ordinal(place)} size={math.max(14, math.floor(props.size * 0.3))} weight={Enum.FontWeight.Bold} color={rest} alpha={0.15} auto={true} yAlign={Enum.TextYAlignment.Bottom} box={UDim2.fromScale(0, 1)} />
				</frame>
			)}
		</frame>
	);
}

interface LadderProps {
	w: number;
	own: unknown;
	place: number;
	above?: RankRow;
	below?: RankRow;
	accent: Color3;
	valueText(this: void, value: unknown): string;
	reduced?: boolean;
}

// the climb: the seat below on the left, the seat above on the right, you in between by score
function Ladder(props: LadderProps) {
	const arrive = useArrival(props.reduced);
	const w = props.w;
	let t = 1;
	if (props.above !== undefined && props.below !== undefined) {
		const span = Math.ToNumber(Math.Sub(props.above.Value, props.below.Value));
		const into = Math.ToNumber(Math.Sub(props.own, props.below.Value));
		t = span > 0 ? into / span : 0.5;
	} else if (props.above !== undefined) {
		t = share(props.own, props.above.Value);
	}
	if (t !== t) {
		t = 0.5;
	}
	t = math.clamp(t, 0.08, props.above === undefined ? 1 : 0.92);
	const reach = w - 16;
	const markX = (a: number) => 8 + t * a * reach;
	const leader = props.above === undefined;
	return (
		<frame {...{ Name: "Ladder" }} Size={UDim2.fromOffset(w, 82)} BackgroundTransparency={1}>
			<frame Position={UDim2.fromOffset(0, 25)} Size={UDim2.fromOffset(w, 2)} BackgroundColor3={P.lineSoft} BackgroundTransparency={0.45} BorderSizePixel={0} />
			<frame Position={UDim2.fromOffset(0, 25)} Size={arrive.map((a) => UDim2.fromOffset(markX(a), 2))} BackgroundColor3={props.accent} BorderSizePixel={0} />
			<frame ref={ignoreGuard} Position={UDim2.fromOffset(4, 26)} Size={UDim2.fromOffset(9, 9)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={45} BackgroundColor3={P.panel} BorderSizePixel={0}>
				<uistroke Color={P.muted} Transparency={0.3} Thickness={1.5} />
			</frame>
			{!leader && (
				<frame ref={ignoreGuard} Position={UDim2.fromOffset(w - 4, 26)} Size={UDim2.fromOffset(9, 9)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={45} BackgroundColor3={P.panel} BorderSizePixel={0}>
					<uistroke Color={P.muted} Transparency={0.3} Thickness={1.5} />
				</frame>
			)}
			<frame
				ref={ignoreGuard}
				Position={arrive.map((a) => UDim2.fromOffset(markX(a), 26))}
				Size={UDim2.fromOffset(16, 16)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={P.mint}
				BorderSizePixel={0}
				ZIndex={3}
			>
				<uistroke Color={P.cream} Transparency={0.4} Thickness={1} />
			</frame>
			<Label
				text="YOU"
				size={11}
				weight={Enum.FontWeight.Heavy}
				color={P.mint}
				align={Enum.TextXAlignment.Center}
				decor={true}
				box={UDim2.fromOffset(44, 16)}
				anchor={new Vector2(0.5, 0.5)}
				at={arrive.map((a) => UDim2.fromOffset(math.clamp(markX(a), 22, w - 22), 6))}
			/>
			<Label
				text={props.below !== undefined ? `#${props.place + 1}` : "ENTRY"}
				size={12}
				weight={Enum.FontWeight.Bold}
				box={UDim2.fromOffset(w / 2 - 8, 16)}
				at={UDim2.fromOffset(0, 40)}
			/>
			<Label
				text={props.below !== undefined ? props.valueText(props.below.Value) : "ANY SCORE"}
				size={11}
				color={P.muted}
				box={UDim2.fromOffset(w / 2 - 8, 16)}
				at={UDim2.fromOffset(0, 57)}
			/>
			<Label
				text={props.above !== undefined ? `#${props.place - 1}` : "TOP SEAT"}
				size={12}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				box={UDim2.fromOffset(w / 2 - 8, 16)}
				at={UDim2.fromOffset(w / 2 + 8, 40)}
			/>
			<Label
				text={props.above !== undefined ? props.valueText(props.above.Value) : "NO ONE AHEAD"}
				size={11}
				color={P.muted}
				align={Enum.TextXAlignment.Right}
				box={UDim2.fromOffset(w / 2 - 8, 16)}
				at={UDim2.fromOffset(w / 2 + 8, 57)}
			/>
		</frame>
	);
}

// a small "UPDATED 12S AGO" that keeps its own clock so the page isn't redrawn every second
function StatusLine(props: { result: Result; count: number; align: Enum.TextXAlignment; box: UDim2; at: UDim2 }) {
	const [, tick] = React.useState(0);
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				task.wait(1);
				if (alive) {
					tick((v) => v + 1);
				}
			}
		});
		return () => {
			alive = false;
		};
	}, []);
	const result = props.result;
	const age = result.at !== undefined ? os.clock() - result.at : 0;
	let text: string;
	let dot = P.mint;
	if (result.loading && result.rows.size() === 0) {
		text = "LOADING THE BOARD";
		dot = P.mango;
	} else if (result.loading) {
		text = "REFRESHING";
		dot = P.mango;
	} else if (result.failed) {
		text = "COULD NOT REACH THE BOARD";
		dot = P.red;
	} else {
		text = `${props.count} ${props.count === 1 ? "ENTRY" : "ENTRIES"}  ·  UPDATED ${ageText(age)}`;
	}
	return (
		<frame Size={props.box} Position={props.at} BackgroundTransparency={1}>
			<Label text={text} size={11} weight={Enum.FontWeight.Bold} color={P.muted} align={props.align} box={new UDim2(1, -16, 1, 0)} at={props.align === Enum.TextXAlignment.Right ? UDim2.fromOffset(0, 0) : UDim2.fromOffset(16, 0)} />
			<frame Size={UDim2.fromOffset(7, 7)} Position={props.align === Enum.TextXAlignment.Right ? new UDim2(1, -3, 0.5, 0) : new UDim2(0, 3, 0.5, 0)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={dot} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</frame>
	);
}

function LinkButton(props: { text: string; color: Color3; width: number; height?: number; at?: UDim2; align?: Enum.TextXAlignment; disabled?: boolean; onClick: () => void }) {
	const [hot, setHot] = React.useBinding(0);
	const height = props.height ?? 28;
	return (
		<textbutton
			Size={UDim2.fromOffset(props.width, height)}
			Position={props.at}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Active={props.disabled !== true}
			Selectable={props.disabled !== true}
			Text=""
			Event={{
				MouseEnter: () => setHot(1),
				MouseLeave: () => setHot(0),
				Activated: () => {
					if (props.disabled !== true) {
						Audio.play("click");
						InteractionFeedback.tick();
						props.onClick();
					}
				},
			}}
		>
			<Label
				text={props.text}
				size={11}
				weight={Enum.FontWeight.Heavy}
				color={hot.map((h) => props.color.Lerp(P.cream, h * 0.6))}
				alpha={props.disabled === true ? 0.6 : 0}
				align={props.align ?? Enum.TextXAlignment.Right}
			/>
			<frame Size={hot.map((h) => new UDim2(h, 0, 0, 1))} Position={new UDim2(props.align === Enum.TextXAlignment.Left ? 0 : 1, 0, 1, -5)} AnchorPoint={new Vector2(props.align === Enum.TextXAlignment.Left ? 0 : 1, 0)} BackgroundColor3={props.color} BorderSizePixel={0} />
		</textbutton>
	);
}

interface MastheadProps {
	meta: BoardMeta;
	groupLabel: string;
	scopeLabel: string;
	width: number;
	phone: boolean;
	rows: RankRow[];
	result: Result;
	place?: number;
	own: unknown;
	above?: RankRow;
	below?: RankRow;
	guildBoard: boolean;
	hasGuild: boolean;
	valueText(this: void, value: unknown): string;
	gapText(this: void, value: unknown): string;
	counts: boolean;
	reduced?: boolean;
	onRefresh: () => void;
}

function mastheadHeight(phone: boolean): number {
	return phone ? 348 : 214;
}

function Masthead(props: MastheadProps) {
	const { meta, width: W, phone, place, rows } = props;
	const count = rows.size();
	const iconSize = phone ? 32 : 40;
	const titleX = iconSize + 12;
	const seatY = phone ? 156 : 124;
	const labelY = phone ? 142 : 110;
	const scoreX = phone ? math.floor(W * 0.46) : math.floor(W * 0.28);
	const scoreW = phone ? W - scoreX : math.floor(W * 0.26) - 12;
	const climbX = phone ? 0 : math.floor(W * 0.56);
	const climbW = phone ? W : W - climbX;
	const climbY = phone ? 238 : labelY;

	let headline: string;
	let detail: string;
	if (place !== undefined) {
		const gap = props.above !== undefined && Math.Gt(props.above.Value, props.own) ? props.gapText(Math.Sub(props.above.Value, props.own)) : undefined;
		headline = place === 1 ? "Leading the board" : gap !== undefined ? `${gap} to #${place - 1}` : `Level with #${place - 1}`;
		detail = count >= 10 ? `${place}${ordinal(place).lower()} of ${count}  ·  top ${math.max(1, math.ceil((place / count) * 100))}%` : `${place}${ordinal(place).lower()} of ${count}`;
		if (place === 1 && props.below !== undefined && Math.Gt(props.own, props.below.Value)) {
			detail = `${props.gapText(Math.Sub(props.own, props.below.Value))} clear of #2`;
		}
	} else if (props.guildBoard && !props.hasGuild) {
		headline = "No guild yet";
		detail = "Join or found a guild to compete here";
	} else if (!props.counts) {
		headline = "Nothing scored yet";
		detail = "Earn some to take a seat";
	} else if (props.result.loading) {
		headline = "Finding your seat…";
		detail = "";
	} else if (props.result.failed && count === 0) {
		headline = "Board unreachable";
		detail = "Trying again every half minute";
	} else {
		headline = count >= SEAT_CAP ? "Just off the board" : "Posts on the next refresh";
		detail = count >= SEAT_CAP ? `Beat ${props.valueText(rows[count - 1].Value)} to enter` : "Scores sync every half minute";
	}

	return (
		<frame {...{ Name: "Masthead" }} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Label text={`${props.groupLabel.upper()}  ·  ${props.scopeLabel}`} size={11} weight={Enum.FontWeight.Heavy} color={meta.accent} box={new UDim2(0.6, 0, 0, 16)} />
			{e(Art.Icon, { kind: meta.icon, color: meta.accent, accent: meta.accent, size: iconSize, spin: false, position: UDim2.fromOffset(0, 22) })}
			<Label text={meta.label} size={phone ? 24 : 30} weight={Enum.FontWeight.Bold} fit={true} minSize={18} box={new UDim2(phone ? 1 : 0.62, -titleX, 0, phone ? 32 : 38)} at={UDim2.fromOffset(titleX, phone ? 24 : 21)} />
			<Label text={meta.description} size={13} color={P.muted} wrap={true} fit={true} minSize={11} box={new UDim2(phone ? 1 : 0.6, phone ? 0 : -titleX, 0, 34)} at={UDim2.fromOffset(phone ? 0 : titleX, 62)} />
			<StatusLine
				result={props.result}
				count={count}
				align={phone ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Right}
				box={phone ? new UDim2(1, -90, 0, 16) : UDim2.fromOffset(300, 16)}
				at={phone ? UDim2.fromOffset(0, 104) : new UDim2(1, -300, 0, 2)}
			/>
			<LinkButton text="REFRESH" color={meta.accent} width={80} at={phone ? new UDim2(1, -86, 0, 98) : new UDim2(1, -86, 0, 26)} disabled={props.result.loading} onClick={props.onRefresh} />
			<Rule at={UDim2.fromOffset(0, phone ? 134 : 100)} width={new UDim(1, 0)} alpha={0.55} />

			<Label text="YOUR SEAT" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} box={UDim2.fromOffset(120, 16)} at={UDim2.fromOffset(0, labelY)} />
			<frame Size={UDim2.fromOffset(phone ? math.floor(W * 0.44) : scoreX - 16, phone ? 66 : 76)} Position={UDim2.fromOffset(0, seatY)} BackgroundTransparency={1}>
				<Seat key={tostring(place ?? 0)} place={place} size={phone ? 54 : 70} reduced={props.reduced} />
			</frame>
			<Label text="SCORE" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} box={UDim2.fromOffset(120, 16)} at={UDim2.fromOffset(scoreX, labelY)} />
			<Label text={props.counts || place !== undefined ? props.valueText(props.own) : "—"} size={phone ? 22 : 26} weight={Enum.FontWeight.Bold} fit={true} minSize={14} box={UDim2.fromOffset(scoreW, 34)} at={UDim2.fromOffset(scoreX, seatY - 2)} />
			<Label text={headline} size={13} weight={Enum.FontWeight.SemiBold} color={place === 1 ? METAL[1].tone : P.cream} box={UDim2.fromOffset(scoreW, 20)} at={UDim2.fromOffset(scoreX, seatY + 36)} />
			<Label text={detail} size={12} color={P.muted} box={UDim2.fromOffset(scoreW, 18)} at={UDim2.fromOffset(scoreX, seatY + 56)} />

			<Label text="THE CLIMB" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} box={UDim2.fromOffset(120, 16)} at={UDim2.fromOffset(climbX, climbY)} />
			{place !== undefined ? (
				<frame Size={UDim2.fromOffset(climbW, 82)} Position={UDim2.fromOffset(climbX, climbY + 20)} BackgroundTransparency={1}>
					<Ladder w={climbW} own={props.own} place={place} above={props.above} below={props.below} accent={meta.accent} valueText={props.valueText} reduced={props.reduced} />
				</frame>
			) : (
				<Label
					text={props.result.loading && count === 0 ? "Loading the board…" : props.result.failed && count === 0 ? "No standings to show right now." : "You are not on this board yet."}
					size={13}
					color={P.muted}
					box={UDim2.fromOffset(climbW, 20)}
					at={UDim2.fromOffset(climbX, climbY + 28)}
				/>
			)}
		</frame>
	);
}

// ── Controls ───────────────────────────────────────────────────────────────────

interface SegmentedProps {
	options: Array<{ id: string; label: string }>;
	value: string;
	accent: Color3;
	height: number;
	disabled?: boolean;
	reduced?: boolean;
	size?: UDim2;
	position?: UDim2;
	onChange: (id: string) => void;
}

// two or three words on a hairline; the accent bar under the chosen one glides
function Segmented(props: SegmentedProps) {
	const n = props.options.size();
	let index = 0;
	for (let i = 0; i < n; i++) {
		if (props.options[i].id === props.value) {
			index = i;
		}
	}
	const slide = useLit(index, props.reduced);
	return (
		<frame Size={props.size ?? new UDim2(1, 0, 0, props.height)} Position={props.position} BackgroundTransparency={1}>
			<frame Size={new UDim2(1, 0, 0, 1)} Position={new UDim2(0, 0, 1, -1)} BackgroundColor3={P.lineSoft} BackgroundTransparency={0.55} BorderSizePixel={0} />
			<frame
				Size={new UDim2(1 / n, -16, 0, 2)}
				Position={slide.map((v) => new UDim2(v / n, 8, 1, -2))}
				BackgroundColor3={props.accent}
				BackgroundTransparency={props.disabled === true ? 0.7 : 0}
				BorderSizePixel={0}
			/>
			{props.options.map((option, i) => (
				<textbutton
					key={option.id}
					Size={new UDim2(1 / n, 0, 1, 0)}
					Position={new UDim2(i / n, 0, 0, 0)}
					BackgroundTransparency={1}
					AutoButtonColor={false}
					Active={props.disabled !== true}
					Text=""
					Event={{
						Activated: () => {
							if (props.disabled !== true && option.id !== props.value) {
								Audio.play("tabSwitch");
								InteractionFeedback.tick();
								props.onChange(option.id);
							}
						},
					}}
				>
					<Label
						text={option.label.upper()}
						size={12}
						weight={Enum.FontWeight.Heavy}
						color={slide.map((v) => P.muted.Lerp(P.cream, math.clamp(1 - math.abs(v - i), 0, 1)))}
						alpha={props.disabled === true ? 0.55 : 0}
						align={Enum.TextXAlignment.Center}
						box={new UDim2(1, 0, 1, -4)}
					/>
				</textbutton>
			))}
		</frame>
	);
}

// the "only me" switch: a short track and knob with its label, 44px tall to tap
function Toggle(props: { label: string; on: boolean; accent: Color3; width: number; reduced?: boolean; at?: UDim2; onChange: (value: boolean) => void }) {
	const lit = useLit(props.on ? 1 : 0, props.reduced);
	return (
		<textbutton
			Size={UDim2.fromOffset(props.width, 44)}
			Position={props.at}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			Event={{
				Activated: () => {
					Audio.play(props.on ? "toggleOff" : "toggleOn");
					InteractionFeedback.tick();
					props.onChange(!props.on);
				},
			}}
		>
			<frame Size={UDim2.fromOffset(34, 18)} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={lit.map((a) => P.panelSoft.Lerp(props.accent, a * 0.85))} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<frame Size={UDim2.fromOffset(12, 12)} Position={lit.map((a) => new UDim2(0, 3 + 16 * a, 0.5, 0))} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={P.cream} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
			<Label text={props.label} size={12} weight={Enum.FontWeight.Heavy} color={lit.map((a) => P.muted.Lerp(P.cream, a))} box={new UDim2(1, -46, 1, 0)} at={UDim2.fromOffset(46, 0)} />
		</textbutton>
	);
}

// ── Index ──────────────────────────────────────────────────────────────────────

interface IndexEntry {
	group: GroupMeta;
	boards: BoardMeta[];
}

function RailItem(props: { board: BoardMeta; selected: boolean; height: number; order: number; reduced?: boolean; onSelect: () => void }) {
	const [hover, setHover] = React.useState(0);
	const sel = useLit(props.selected ? 1 : 0, props.reduced);
	const hot = useLit(hover, props.reduced);
	const board = props.board;
	return (
		<textbutton
			Size={new UDim2(1, 0, 0, props.height)}
			LayoutOrder={props.order}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			Event={{
				MouseEnter: () => setHover(1),
				MouseLeave: () => setHover(0),
				Activated: () => {
					if (!props.selected) {
						Audio.play("tabSwitch");
						InteractionFeedback.tick();
						props.onSelect();
					}
				},
			}}
		>
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={theme.darken(board.accent, 0.7)}
				BackgroundTransparency={React.joinBindings({ s: sel, h: hot }).map(({ s, h }) => 1 - math.max(0.62 * s, 0.22 * h))}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
			</frame>
			<frame Size={sel.map((a) => new UDim2(0, 3, 0.58 * a, 0))} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundColor3={board.accent} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
			{e(Art.Icon, { kind: board.icon, color: board.accent, accent: board.accent, size: 18, spin: false, position: new UDim2(0, 14, 0.5, -9) })}
			<Label
				text={board.label}
				size={14}
				weight={Enum.FontWeight.SemiBold}
				color={React.joinBindings({ s: sel, h: hot }).map(({ s, h }) => P.creamSoft.Lerp(P.cream, math.max(s, h)))}
				alpha={sel.map((a) => 0.18 * (1 - a))}
				box={new UDim2(1, -46, 1, 0)}
				at={UDim2.fromOffset(42, 0)}
			/>
		</textbutton>
	);
}

interface RailProps {
	index: IndexEntry[];
	selected: string;
	accent: Color3;
	itemH: number;
	scope: string;
	guildBoard: boolean;
	reduced?: boolean;
	onSelect: (id: string) => void;
	onScope: (scope: string) => void;
}

function Rail(props: RailProps) {
	const children: React.Element[] = [];
	let order = 0;
	children.push(
		<frame key="scope" Size={new UDim2(1, 0, 0, 74)} LayoutOrder={order++} BackgroundTransparency={1}>
			<Label text="SHOWING" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} box={UDim2.fromOffset(120, 16)} at={UDim2.fromOffset(2, 2)} />
			<Segmented
				options={[
					{ id: "Global", label: "Global" },
					{ id: "Server", label: "This server" },
				]}
				value={props.guildBoard ? "Global" : props.scope}
				accent={props.accent}
				height={36}
				disabled={props.guildBoard}
				reduced={props.reduced}
				position={UDim2.fromOffset(0, 26)}
				size={new UDim2(1, 0, 0, 36)}
				onChange={props.onScope}
			/>
		</frame>,
	);
	for (const entry of props.index) {
		const active = entry.boards.some((board) => board.id === props.selected);
		children.push(
			<frame key={`head-${entry.group.id}`} Size={new UDim2(1, 0, 0, 30)} LayoutOrder={order++} BackgroundTransparency={1}>
				<Label text={entry.group.label.upper()} size={11} weight={Enum.FontWeight.Heavy} color={active ? props.accent : P.muted} box={new UDim2(1, -4, 0, 20)} at={UDim2.fromOffset(2, 6)} />
				<Rule at={new UDim2(0, 0, 1, -2)} width={new UDim(1, 0)} alpha={0.6} />
			</frame>,
		);
		for (const board of entry.boards) {
			children.push(
				<RailItem key={board.id} board={board} selected={board.id === props.selected} height={props.itemH} order={order++} reduced={props.reduced} onSelect={() => props.onSelect(board.id)} />,
			);
		}
		children.push(<frame key={`gap-${entry.group.id}`} Size={new UDim2(1, 0, 0, 10)} LayoutOrder={order++} BackgroundTransparency={1} />);
	}
	return (
		<scrollingframe
			{...{ Name: "RankIndex" }}
			Size={new UDim2(0, RAIL_W, 1, 0)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={UDim2.fromOffset(0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={3}
			ScrollBarImageColor3={props.accent}
			ScrollBarImageTransparency={0.45}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
			VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
			Selectable={false}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 2)} />
			<uipadding PaddingRight={new UDim(0, 10)} PaddingTop={new UDim(0, 4)} PaddingBottom={new UDim(0, 24)} />
			{children}
		</scrollingframe>
	);
}

// phones and narrow windows: every board in one horizontal strip, grouped with small headings
function Strip(props: { index: IndexEntry[]; selected: string; reduced?: boolean; onSelect: (id: string) => void }) {
	const scroller = React.useRef<ScrollingFrame>();
	const chips = React.useRef(new Map<string, GuiObject>());
	React.useEffect(() => {
		const strip = scroller.current;
		const chip = chips.current.get(props.selected);
		if (strip === undefined || chip === undefined) {
			return;
		}
		const left = chip.AbsolutePosition.X - strip.AbsolutePosition.X + strip.CanvasPosition.X;
		const goal = math.clamp(left - (strip.AbsoluteWindowSize.X - chip.AbsoluteSize.X) / 2, 0, math.max(0, strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X));
		if (props.reduced === true) {
			strip.CanvasPosition = new Vector2(goal, 0);
		} else {
			TweenService.Create(strip, new TweenInfo(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition: new Vector2(goal, 0) }).Play();
		}
	}, [props.selected]);
	const children: React.Element[] = [];
	let order = 0;
	for (const entry of props.index) {
		children.push(
			<textlabel
				key={`head-${entry.group.id}`}
				Size={UDim2.fromOffset(0, 44)}
				AutomaticSize={Enum.AutomaticSize.X}
				LayoutOrder={order++}
				BackgroundTransparency={1}
				Text={entry.group.label.upper()}
				FontFace={face(Enum.FontWeight.Heavy)}
				TextSize={11}
				TextColor3={P.muted}
			>
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 4)} />
			</textlabel>,
		);
		for (const board of entry.boards) {
			const active = board.id === props.selected;
			children.push(
				<textbutton
					key={board.id}
					ref={(chip: TextButton | undefined) => {
						if (chip !== undefined) {
							chips.current.set(board.id, chip);
						} else {
							chips.current.delete(board.id);
						}
					}}
					Size={UDim2.fromOffset(0, 44)}
					AutomaticSize={Enum.AutomaticSize.X}
					LayoutOrder={order++}
					BackgroundColor3={theme.darken(board.accent, 0.7)}
					BackgroundTransparency={active ? 0.35 : 1}
					BorderSizePixel={0}
					AutoButtonColor={false}
					Text=""
					Event={{
						Activated: () => {
							if (!active) {
								Audio.play("tabSwitch");
								InteractionFeedback.tick();
								props.onSelect(board.id);
							}
						},
					}}
				>
					<uicorner CornerRadius={new UDim(0, 8)} />
					<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 14)} />
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame Size={UDim2.fromOffset(18, 18)} BackgroundTransparency={1} LayoutOrder={1}>
						{e(Art.Icon, { kind: board.icon, color: board.accent, accent: board.accent, size: 18, spin: false })}
					</frame>
					<Label text={board.short ?? board.label} size={13} weight={Enum.FontWeight.SemiBold} color={active ? P.cream : P.creamSoft} alpha={active ? 0 : 0.18} auto={true} box={UDim2.fromScale(0, 1)} order={2} />
				</textbutton>,
			);
		}
	}
	return (
		<scrollingframe
			ref={scroller}
			{...{ Name: "RankStrip" }}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={UDim2.fromOffset(0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.X}
			ScrollBarThickness={0}
			ScrollingDirection={Enum.ScrollingDirection.X}
			ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
			Selectable={false}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} />
			{children}
		</scrollingframe>
	);
}

// ── Ledger ─────────────────────────────────────────────────────────────────────

const LEDGER_HEAD = 34;

function ledgerHeight(rows: number, cols: Cols): number {
	return LEDGER_HEAD + rows * cols.rowH + 6;
}

interface LedgerEntry {
	row: RankRow;
	place: number;
	mine: boolean;
	valueText: string;
	share: number;
}

function Ledger(props: { entries: LedgerEntry[]; cols: Cols; guild: boolean; accent: Color3; reduced?: boolean }) {
	const arrive = useArrival(props.reduced);
	const cols = props.cols;
	const valueRight = 12 + cols.pctW;
	const rows: React.Element[] = [];
	props.entries.forEach((entry, i) => {
		const d = math.min(i, 14) * 0.03;
		rows.push(
			<LedgerRow
				key={`${entry.row.UserId ?? entry.row.Id ?? i}`}
				row={entry.row}
				place={entry.place}
				mine={entry.mine}
				guild={props.guild}
				accent={props.accent}
				cols={cols}
				y={LEDGER_HEAD + i * cols.rowH}
				valueText={entry.valueText}
				share={entry.share}
				arrival={i < 16 ? arrive.map((a) => slice(a, d, d + 0.5)) : undefined}
			/>,
		);
	});
	return (
		<frame {...{ Name: "Ledger" }} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Label text="#" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} align={Enum.TextXAlignment.Right} box={UDim2.fromOffset(cols.placeW, 24)} at={UDim2.fromOffset(2, 0)} />
			<Label text={props.guild ? "GUILD" : "PILOT"} size={11} weight={Enum.FontWeight.Heavy} color={P.muted} box={UDim2.fromOffset(160, 24)} at={UDim2.fromOffset(cols.markX, 0)} />
			<Label text="SCORE" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} align={Enum.TextXAlignment.Right} box={UDim2.fromOffset(cols.valueW, 24)} at={new UDim2(1, -(valueRight + cols.valueW), 0, 0)} />
			{cols.pctW > 0 && <Label text="OF #1" size={11} weight={Enum.FontWeight.Heavy} color={P.muted} align={Enum.TextXAlignment.Right} box={UDim2.fromOffset(cols.pctW, 24)} at={new UDim2(1, -(12 + cols.pctW), 0, 0)} />}
			<Rule at={UDim2.fromOffset(0, 26)} width={new UDim(1, 0)} alpha={0.45} />
			{rows}
		</frame>
	);
}

function Skeleton(props: { count: number; cols: Cols; reduced?: boolean }) {
	const clock = useClock(props.reduced !== true, 1.6);
	const cols = props.cols;
	const rows: React.Element[] = [];
	for (let i = 0; i < props.count; i++) {
		const alpha = clock.map((t) => 0.7 - 0.08 * math.sin(t - i * 0.55));
		const widths = [0.34, 0.24, 0.3, 0.2, 0.28];
		rows.push(
			<frame key={i} Position={UDim2.fromOffset(0, LEDGER_HEAD + i * cols.rowH)} Size={new UDim2(1, 0, 0, cols.rowH)} BackgroundTransparency={1}>
				<frame Position={UDim2.fromOffset(cols.placeW - 18, cols.rowH / 2 - 4)} Size={UDim2.fromOffset(20, 8)} BackgroundColor3={P.panelSoft} BackgroundTransparency={alpha} BorderSizePixel={0} />
				<frame Position={new UDim2(0, cols.markX, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} Size={UDim2.fromOffset(cols.markSize, cols.markSize)} BackgroundColor3={P.panelSoft} BackgroundTransparency={alpha} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
				<frame Position={new UDim2(0, cols.nameX, 0.5, -5)} Size={new UDim2(widths[i % widths.size()], 0, 0, 10)} BackgroundColor3={P.panelSoft} BackgroundTransparency={alpha} BorderSizePixel={0} />
				<frame Position={new UDim2(1, -(12 + cols.pctW + 96), 0.5, -5)} Size={UDim2.fromOffset(96, 10)} BackgroundColor3={P.panelSoft} BackgroundTransparency={alpha} BorderSizePixel={0} />
				<Rule at={new UDim2(0, cols.markX, 1, -1)} width={new UDim(1, -(cols.markX + 12))} alpha={0.85} />
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{rows}
		</frame>
	);
}

// an empty board, a failed load or a search with no match: one centered note and, when useful, one action
function Notice(props: { title: string; body: string; accent: Color3; action?: string; reduced?: boolean; onAction?: () => void }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Rule at={new UDim2(0.5, -60, 0, 18)} width={new UDim(0, 120)} alpha={0.4} />
			<frame ref={ignoreGuard} Position={new UDim2(0.5, 0, 0, 18)} Size={UDim2.fromOffset(9, 9)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={45} BackgroundColor3={props.accent} BorderSizePixel={0} />
			<Label text={props.title} size={17} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Center} fit={true} minSize={13} box={new UDim2(1, -32, 0, 26)} at={UDim2.fromOffset(16, 34)} />
			<Label text={props.body} size={13} color={P.muted} wrap={true} fit={true} minSize={11} align={Enum.TextXAlignment.Center} box={new UDim2(1, -48, 0, 40)} at={UDim2.fromOffset(24, 62)} />
			{props.action !== undefined && props.onAction !== undefined && (
				<LinkButton text={props.action} color={props.accent} width={140} height={32} align={Enum.TextXAlignment.Center} at={new UDim2(0.5, -70, 0, 108)} onClick={props.onAction} />
			)}
		</frame>
	);
}

// ── Pin ────────────────────────────────────────────────────────────────────────

// Keeps your row on screen: while it is scrolled out of view it sits on the edge it left from.
function PinHost(props: { scroller: React.MutableRefObject<ScrollingFrame | undefined>; place?: number; enabled: boolean; revision: number; pinH: number; reduced?: boolean; onJump: () => void; children?: React.ReactNode }) {
	const [side, setSide] = React.useState<"above" | "below" | undefined>(undefined);
	const last = React.useRef<"above" | "below">("below");
	if (side !== undefined) {
		last.current = side;
	}
	React.useEffect(() => {
		const scroller = props.scroller.current;
		const place = props.place;
		if (scroller === undefined || place === undefined || !props.enabled) {
			setSide(undefined);
			return undefined;
		}
		function measure() {
			const target = scroller!.FindFirstChild(`rank-row-${place}`, true) ?? scroller!.FindFirstChild(`PodiumSeat${place}`, true);
			if (target === undefined || !target.IsA("GuiObject")) {
				setSide(undefined);
				return;
			}
			const top = target.AbsolutePosition.Y - scroller!.AbsolutePosition.Y;
			const bottom = top + target.AbsoluteSize.Y;
			const view = scroller!.AbsoluteWindowSize.Y;
			const seen: "above" | "below" | undefined = bottom < 4 ? "above" : top > view - 4 ? "below" : undefined;
			setSide((current) => (current === seen ? current : seen));
		}
		measure();
		const settle = task.delay(0.7, measure);
		const connections = [
			scroller.GetPropertyChangedSignal("CanvasPosition").Connect(measure),
			scroller.GetPropertyChangedSignal("AbsoluteWindowSize").Connect(measure),
			scroller.GetPropertyChangedSignal("AbsoluteCanvasSize").Connect(measure),
		];
		return () => {
			pcall(task.cancel, settle);
			for (const connection of connections) {
				connection.Disconnect();
			}
		};
	}, [props.place, props.enabled, props.revision]);
	const presence = useLit(side !== undefined ? 1 : 0, props.reduced);
	const anchorTop = last.current === "above";
	const pinH = props.pinH;
	return (
		<textbutton
			ref={(button: TextButton | undefined) => {
				if (button !== undefined) {
					button.SetAttribute("LayoutFloating", true);
					button.SetAttribute("LayoutGuardIgnore", true);
				}
			}}
			{...{ Name: "RankPinnedYou" }}
			Size={new UDim2(1, 0, 0, pinH)}
			Position={presence.map((a) => (anchorTop ? new UDim2(0, 0, 0, -(1 - a) * 16) : new UDim2(0, 0, 1, -pinH + (1 - a) * 16)))}
			Visible={presence.map((a) => a > 0.02)}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			ZIndex={40}
			Event={{
				Activated: () => {
					Audio.play("click");
					InteractionFeedback.tap();
					props.onJump();
				},
			}}
		>
			<frame {...{ Name: "Backing" }} Size={UDim2.fromScale(1, 1)} BackgroundColor3={P.night} BackgroundTransparency={0.06} BorderSizePixel={0} />
			{props.children}
		</textbutton>
	);
}

function scrollToSeat(scroller: ScrollingFrame | undefined, place: number, instant: boolean) {
	if (scroller === undefined) {
		return;
	}
	const target = scroller.FindFirstChild(`rank-row-${place}`, true) ?? scroller.FindFirstChild(`PodiumSeat${place}`, true);
	if (target === undefined || !target.IsA("GuiObject")) {
		return;
	}
	const offset = target.AbsolutePosition.Y - scroller.AbsolutePosition.Y - (scroller.AbsoluteWindowSize.Y - target.AbsoluteSize.Y) / 2;
	const maxY = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y);
	const goal = new Vector2(scroller.CanvasPosition.X, math.clamp(scroller.CanvasPosition.Y + offset, 0, maxY));
	if (instant) {
		scroller.CanvasPosition = goal;
	} else {
		TweenService.Create(scroller, new TweenInfo(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition: goal }).Play();
	}
	// mark where you landed: the row takes a wash of color that fades out
	const flash = target.FindFirstChild("Flash");
	if (flash !== undefined && flash.IsA("GuiObject")) {
		flash.BackgroundTransparency = 0.6;
		TweenService.Create(flash, new TweenInfo(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, instant ? 0.1 : 0.35), { BackgroundTransparency: 1 }).Play();
	}
}

// ── Dashboard ──────────────────────────────────────────────────────────────────

interface Section {
	id: string;
	height: number;
	element: React.Element;
}

function RankDashboard(helpers: Helpers): (props: Props) => React.Element {
	const boardList = [...helpers.boards];
	boardList.push(GUILD_META);
	const index: IndexEntry[] = [];
	for (const group of GROUPS) {
		const boards: BoardMeta[] = [];
		for (const board of boardList) {
			if (board.group === group.id) {
				boards.push(board);
			}
		}
		if (boards.size() > 0) {
			index.push({ group, boards });
		}
	}
	function groupOf(id: string): GroupMeta {
		for (const entry of index) {
			if (entry.boards.some((board) => board.id === id)) {
				return entry.group;
			}
		}
		return GROUPS[0];
	}
	return function (props: Props): React.Element {
		const viewport = useViewport();
		const hostRef = React.useRef<Frame>();
		const scrollRef = React.useRef<ScrollingFrame>();
		const [measuredWidth, setMeasuredWidth] = React.useState(viewport.width);

		React.useEffect(() => {
			const host = hostRef.current!;
			if (host === undefined) {
				return undefined;
			}
			function resize() {
				setMeasuredWidth(host.AbsoluteSize.X);
			}
			resize();
			const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(resize);
			return () => connection.Disconnect();
		}, []);

		const rail = measuredWidth >= RAIL_MIN;
		// the page scrollbar and its inset take a few pixels off the right; explicit widths stay inside them
		const contentW = math.max(280, (rail ? measuredWidth - RAIL_W - RAIL_GAP : measuredWidth) - 10);
		const phone = contentW < 620;
		const cols = colsFor(contentW);
		const reducedMotion = props.reducedMotion;
		const [selected, setSelected] = React.useState("Flux");
		const [scope, setScope] = React.useState("Global");
		const [revision, reload] = React.useState(0);
		const [query, setQuery] = React.useState("");
		const [mineOnly, setMineOnly] = React.useState(false);

		React.useEffect(() => {
			if (!UserInputService.GamepadEnabled) {
				return undefined;
			}
			const host = hostRef.current!;
			if (host === undefined) {
				return undefined;
			}
			const focusJob = task.defer(() => {
				if (host.Parent !== undefined) {
					FocusClaim(host);
				}
			});
			return () => {
				pcall(() => task.cancel(focusJob));
			};
		}, [selected, scope]);

		// gamepad: right-stick click jumps to your row, same as tapping the pinned row
		const findPlaceRef = React.useRef<number>();
		const reducedRef = React.useRef(false);
		React.useEffect(() => {
			const name = "AstralForgeRankFindMe";
			ContextActionService.BindActionAtPriority(
				name,
				(_: string, inputState: Enum.UserInputState) => {
					const place = findPlaceRef.current;
					if (inputState !== Enum.UserInputState.Begin || place === undefined) {
						return Enum.ContextActionResult.Pass;
					}
					scrollToSeat(scrollRef.current, place, reducedRef.current);
					return Enum.ContextActionResult.Sink;
				},
				false,
				2300,
				Enum.KeyCode.ButtonR3,
			);
			return () => ContextActionService.UnbindAction(name);
		}, []);

		// Studio only: ReplicatedStorage.AstralDevRank = "Board[:Global|Server[:search text]]" opens a board without clicking
		// (screenshots and playtests); AstralDevRankHold = true keeps the board loading, "fail" makes the fetch fail
		React.useEffect(() => {
			if (!game.GetService("RunService").IsStudio()) {
				return undefined;
			}
			function apply() {
				const spec = ReplicatedStorage.GetAttribute("AstralDevRank");
				if (!typeIs(spec, "string") || spec === "") {
					return;
				}
				const parts = spec.split(":");
				const board = parts[0];
				if (boardList.some((entry) => entry.id === board)) {
					setSelected(board);
				}
				setScope(parts[1] === "Server" ? "Server" : "Global");
				setQuery(parts[2] ?? "");
			}
			apply();
			const connection = ReplicatedStorage.GetAttributeChangedSignal("AstralDevRank").Connect(apply);
			return () => connection.Disconnect();
		}, []);

		const [result, setResult] = React.useState<Result>({ rows: [], loading: true, failed: false });
		const guildBoard = selected === "Guilds";
		const meta = guildBoard ? GUILD_META : helpers.metaFor(selected);
		const group = groupOf(selected);
		const localId = Players.LocalPlayer.UserId;

		React.useEffect(() => {
			let alive = true;
			let pending = false;
			let serial = 0;
			let timer: thread | undefined;
			function refresh() {
				if (!alive || pending) {
					return;
				}
				pending = true;
				serial += 1;
				const request = serial;
				setResult((previous) => ({ rows: previous.rows, loading: true, failed: false, at: previous.at }));
				function finish(reply: unknown) {
					if (!alive || !pending || serial !== request) {
						return;
					}
					pending = false;
					serial += 1;
					if (!typeIs(reply, "table") || (reply as { ok?: boolean }).ok !== true) {
						setResult((previous) => ({ rows: previous.rows, loading: false, failed: true, at: previous.at }));
						return;
					}
					const typedReply = reply as { GuildLeaderboard?: unknown[]; Leaderboard?: unknown[]; Players?: unknown[] };
					let entries = guildBoard ? typedReply.GuildLeaderboard ?? typedReply.Leaderboard : scope === "Server" ? helpers.serverEntries(typedReply.Players ?? [], selected) : typedReply.Leaderboard;
					// Studio only: AstralDevRankPad = N appends N made-up low scorers so long boards can be checked by eye
					const pad = game.GetService("RunService").IsStudio() ? ReplicatedStorage.GetAttribute("AstralDevRankPad") : undefined;
					if (typeIs(pad, "number") && pad > 0 && !guildBoard) {
						const padded = [...(entries ?? [])] as defined[];
						for (let i = 1; i <= pad; i++) {
							padded.push({ UserId: 1000 + i, Name: `Test pilot ${i}`, Value: pad - i + 1, Category: selected });
						}
						entries = padded;
					}
					let rows = Social.rank(entries ?? [], guildBoard);
					if (!guildBoard) {
						const eligible: RankRow[] = [];
						for (const row of rows) {
							if (helpers.scoreCounts(selected, row.Value)) {
								eligible.push(row);
							}
						}
						rows = eligible;
					}
					setResult({ rows, loading: false, failed: false, at: os.clock() });
				}
				const hold = game.GetService("RunService").IsStudio() ? ReplicatedStorage.GetAttribute("AstralDevRankHold") : undefined;
				if (hold === true) {
					pending = false;
					return;
				}
				if (hold === "fail") {
					finish({ ok: false });
					return;
				}
				task.delay(12, () => finish(undefined));
				const action = guildBoard ? "GetGuildLeaderboard" : scope === "Server" ? "GetPlayers" : "GetLeaderboard";
				const payload = action === "GetPlayers" ? {} : { Id: selected };
				const ok = pcall(() => props.dispatch(action, payload, finish));
				if (!ok) {
					finish({ ok: false });
				}
			}
			setResult({ rows: [], loading: true, failed: false });
			function tick() {
				refresh();
				timer = task.delay(30, tick);
			}
			tick();
			return () => {
				alive = false;
				serial += 1;
				const activeTimer = timer;
				if (activeTimer !== undefined) {
					pcall(() => task.cancel(activeTimer));
				}
			};
		}, [props.dispatch, selected, scope, revision]);

		const rows = result.rows;
		const guildState = (props.state.Guild ?? {}) as { Id?: string; Activity?: unknown };
		const guildId = guildState.Id;
		const own = guildBoard ? guildState.Activity ?? 0 : helpers.ownValue(props.state, selected) ?? 0;
		function isMine(row: RankRow): boolean {
			return guildBoard ? row.Id !== undefined && row.Id === guildId : row.UserId === localId;
		}
		function valueText(value: unknown): string {
			return guildBoard ? `${format.compactNumber(value)} activity` : helpers.formatValue(selected, value);
		}
		// a difference between two scores: playtime reads as a duration, everything else as a plain count
		function gapText(value: unknown): string {
			return selected === "PlayTime" ? helpers.formatValue(selected, value) : format.compactNumber(value);
		}
		let personalIndex: number | undefined;
		for (let i = 0; i < rows.size(); i++) {
			if (isMine(rows[i])) {
				personalIndex = i + 1;
				break;
			}
		}
		const searching = query !== "" || mineOnly;
		findPlaceRef.current = searching ? undefined : personalIndex;
		reducedRef.current = reducedMotion === true;
		const above = personalIndex !== undefined ? rows[personalIndex - 2] : undefined;
		const below = personalIndex !== undefined ? rows[personalIndex] : undefined;
		const top = rows[0]?.Value ?? 0;
		const scopeLabel = guildBoard ? "GUILD ACTIVITY" : scope === "Server" ? "THIS SERVER" : "GLOBAL";
		const showPodium = !searching && !phone && rows.size() > 0;

		const sections: Section[] = [];
		if (!rail) {
			sections.push({
				id: "rank-strip",
				height: 44,
				element: <Strip index={index} selected={selected} reduced={reducedMotion} onSelect={setSelected} />,
			});
			sections.push({
				id: "rank-scope",
				height: 40,
				element: (
					<Segmented
						options={[
							{ id: "Global", label: "Global" },
							{ id: "Server", label: "This server" },
						]}
						value={guildBoard ? "Global" : scope}
						accent={meta.accent}
						height={40}
						disabled={guildBoard}
						reduced={reducedMotion}
						onChange={setScope}
					/>
				),
			});
		}

		sections.push({
			id: "rank-masthead",
			height: mastheadHeight(phone),
			element: (
				<Masthead
					meta={meta}
					groupLabel={group.label}
					scopeLabel={scopeLabel}
					width={contentW}
					phone={phone}
					rows={rows}
					result={result}
					place={personalIndex}
					own={own}
					above={above}
					below={below}
					guildBoard={guildBoard}
					hasGuild={guildId !== undefined}
					valueText={valueText}
					gapText={gapText}
					counts={guildBoard ? guildId !== undefined : helpers.scoreCounts(selected, own)}
					reduced={reducedMotion}
					onRefresh={() => reload((v) => v + 1)}
				/>
			),
		});

		// search, the "only me" switch and what the list is showing
		const matches: LedgerEntry[] = [];
		const start = showPodium ? 3 : 0;
		for (let i = start; i < rows.size(); i++) {
			const row = rows[i];
			const mine = isMine(row);
			if (!matchesRank(row, query) || (mineOnly && !mine)) {
				continue;
			}
			matches.push({ row, place: i + 1, mine, valueText: valueText(row.Value), share: share(row.Value, top) });
		}
		const searchBox = phone ? new UDim2(1, 0, 0, 44) : new UDim2(0.46, 0, 0, 44);
		sections.push({
			id: "rank-controls",
			height: phone ? 92 : 44,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
					{e(ui.SearchField, {
						value: query,
						onChange: setQuery,
						placeholder: guildBoard ? "Find a guild or tag" : "Find a pilot or user ID",
						accent: meta.accent,
						reducedMotion,
						hint: searching ? `${matches.size()} found` : undefined,
						position: UDim2.fromOffset(0, 0),
						size: searchBox,
					})}
					<Toggle label="ONLY ME" on={mineOnly} accent={meta.accent} width={104} reduced={reducedMotion} at={phone ? UDim2.fromOffset(0, 48) : new UDim2(0.46, 20, 0, 0)} onChange={setMineOnly} />
					{!phone && rows.size() > 0 && (
						<Label
							text={searching ? `SHOWING ${matches.size()} OF ${rows.size()}` : `TOP ${rows.size()}`}
							size={11}
							weight={Enum.FontWeight.Heavy}
							color={P.muted}
							align={Enum.TextXAlignment.Right}
							box={UDim2.fromOffset(180, 44)}
							at={new UDim2(1, -188, 0, 0)}
						/>
					)}
				</frame>
			),
		});

		const boardKey = `${selected}:${scope}`;
		if (rows.size() === 0 && result.loading) {
			sections.push({ id: "rank-skeleton", height: ledgerHeight(7, cols), element: <Skeleton count={7} cols={cols} reduced={reducedMotion} /> });
		} else if (rows.size() === 0) {
			sections.push({
				id: "rank-empty",
				height: 190,
				element: result.failed ? (
					<Notice title="The board didn't answer" body="The rankings couldn't be reached just now. Check your connection and try again." accent={P.red} action="TRY AGAIN" reduced={reducedMotion} onAction={() => reload((v) => v + 1)} />
				) : (
					<Notice title="Nobody has scored here yet" body={guildBoard ? "No guild has earned activity yet. The first one on the board takes the top seat." : "The first pilot to score takes the top seat. Yours could be the next run."} accent={meta.accent} />
				),
			});
		} else {
			if (showPodium) {
				const plaques: Array<Omit<PlaqueProps, "arrive" | "reduced" | "x" | "w">> = [];
				for (const place of [2, 1, 3]) {
					const row = rows[place - 1];
					if (row === undefined) {
						continue;
					}
					const second = rows[1];
					const caption =
						place === 1
							? second === undefined
								? "ALONE AT THE TOP"
								: Math.Gt(row.Value, second.Value)
									? `${gapText(Math.Sub(row.Value, second.Value))} CLEAR OF #2`
									: "LEVEL WITH #2"
							: `${math.floor(share(row.Value, top) * 100 + 0.5)}% OF THE LEADER`;
					plaques.push({ place, row, mine: isMine(row), guild: guildBoard, valueText: valueText(row.Value), share: share(row.Value, top), caption });
				}
				sections.push({ id: "rank-podium", height: PODIUM_H, element: <Podium key={boardKey} plaques={plaques} width={contentW} reduced={reducedMotion} /> });
			}
			if (matches.size() > 0) {
				sections.push({
					id: "rank-ledger",
					height: ledgerHeight(matches.size(), cols),
					element: <Ledger key={boardKey} entries={matches} cols={cols} guild={guildBoard} accent={meta.accent} reduced={reducedMotion} />,
				});
			} else if (searching) {
				sections.push({
					id: "rank-no-match",
					height: 150,
					element: (
						<Notice
							title={mineOnly ? "You are not on this board" : `No ${guildBoard ? "guild" : "pilot"} matches "${query}"`}
							body={mineOnly ? "Score on this board and your row appears here." : "Try a shorter name, a guild tag or a user ID."}
							accent={meta.accent}
							action={query !== "" || mineOnly ? "CLEAR" : undefined}
							onAction={() => {
								setQuery("");
								setMineOnly(false);
							}}
						/>
					),
				});
			}
			sections.push({
				id: "rank-footer",
				height: 28,
				element: <Label text="BOARDS REFRESH EVERY 30 SECONDS" size={11} weight={Enum.FontWeight.Bold} color={P.muted} alpha={0.3} align={Enum.TextXAlignment.Center} />,
			});
		}

		const youRow: LedgerEntry | undefined =
			personalIndex !== undefined
				? { row: rows[personalIndex - 1], place: personalIndex, mine: true, valueText: valueText(rows[personalIndex - 1].Value), share: share(rows[personalIndex - 1].Value, top) }
				: undefined;
		const pinCols: Cols = { ...cols, pctW: phone ? 0 : UserInputService.GamepadEnabled ? 120 : 76 };
		const pinHint = UserInputService.GamepadEnabled ? `FIND ME · ${KeyLabel(Enum.KeyCode.ButtonR3, "R3")}` : "FIND ME";

		return (
			<frame {...{ Name: "RankDashboard" }} ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ClipsDescendants={false}>
				{rail && (
					<>
						<Rail
							index={index}
							selected={selected}
							accent={meta.accent}
							itemH={UserInputService.TouchEnabled ? 44 : 38}
							scope={scope}
							guildBoard={guildBoard}
							reduced={reducedMotion}
							onSelect={setSelected}
							onScope={setScope}
						/>
						<frame
							Position={UDim2.fromOffset(RAIL_W + math.floor(RAIL_GAP / 2), 8)}
							Size={new UDim2(0, 1, 1, -16)}
							BackgroundColor3={P.lineSoft}
							BackgroundTransparency={0.7}
							BorderSizePixel={0}
						/>
					</>
				)}
				<frame
					{...{ Name: "RankContent" }}
					Position={UDim2.fromOffset(rail ? RAIL_W + RAIL_GAP : 0, 0)}
					Size={new UDim2(1, -(rail ? RAIL_W + RAIL_GAP : 0), 1, 0)}
					BackgroundTransparency={1}
				>
					{e(Scaffold, { sections, gap: 18, tailPad: 96, scrollBarColor: meta.accent, scrollBarThickness: 4, hostRef: scrollRef })}
					<PinHost
						scroller={scrollRef}
						place={personalIndex}
						enabled={!searching && youRow !== undefined}
						revision={rows.size() * 100 + matches.size()}
						pinH={cols.rowH + 8}
						reduced={reducedMotion}
						onJump={() => {
							if (personalIndex !== undefined) {
								scrollToSeat(scrollRef.current, personalIndex, reducedMotion === true);
							}
						}}
					>
						{youRow !== undefined && (
							<LedgerRow row={youRow.row} place={youRow.place} mine={true} guild={guildBoard} accent={meta.accent} cols={pinCols} y={4} valueText={youRow.valueText} share={youRow.share} pinned={true} hint={pinHint} />
						)}
					</PinHost>
				</frame>
			</frame>
		);
	};
}

export = RankDashboard;
