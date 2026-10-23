// Ranks: grouped categories, podium, your-standing card and scaled rows.
import React from "@rbxts/react";
import * as ProfileStyle from "../../Shared/AstralForge/Shared/ProfileStyle";
import { frameStroke } from "./CoreKit/profileFrame";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import { useViewport } from "./MotionKit/motion";
import { KeyLabel } from "./CoreKit/GamepadNavigationService";
import { useFocusOrder } from "./CoreKit/focusOrder";
import { OmegaMathApi } from "./lua";
import { FittedView } from "./UiCore/viewportKit";
import { SplitColumns, splitColumns, StackBlocks, stackHeight } from "./UiCore/ui";

import { BODY_BOLD, BODY_SEMI, DiamondRule, NUM, PanelHeading, RowSurface, TITLE_FACE } from "./UiCore/mockKit";
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
	Button: unknown;
	Text: unknown;
	SearchField: unknown;
	Panel: unknown;
}
const UiCore = require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as CallableFunction;
const ui = UiCore("ui") as UiApi;

interface ArtApi {
	PlayerMark: unknown;
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
	icon: string;
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

const GROUPS: GroupMeta[] = [
	{ id: "Economy", label: "Economy", icon: "Flux.17" },
	{ id: "Progression", label: "Progression", icon: "Rebirth.7" },
	{ id: "Activity", label: "Activity", icon: "Forge.24" },
	{ id: "Collection", label: "Collection", icon: "Crate.16" },
	{ id: "Social", label: "Guilds", icon: "Guild.2" },
];

const GUILD_META: BoardMeta = { id: "Guilds", short: "Guilds", label: "Guild Halls", icon: "Guild.3", accent: P.violet, group: "Social", description: "Guild activity earned by banking and building together." };
const PODIUM_ORDER = [2, 1, 3];
const MEDAL: Record<number, Color3> = {
	[1]: Color3.fromRGB(255, 190, 70),
	[2]: Color3.fromRGB(230, 220, 212),
	[3]: Color3.fromRGB(208, 138, 74),
};
const PODIUM_HEIGHT: Record<number, number> = { [1]: 210, [2]: 150, [3]: 110 };

// 17-leaderboards card: radius 18 with a thin brass inner rule over the padded panel
const FORGE_RADIUS = 18;
function BrassRule(props: { pad: number }): React.Element {
	return e("frame", {
		Size: new UDim2(1, props.pad * 2 - 4, 1, props.pad * 2 - 4), Position: UDim2.fromScale(0.5, 0.5), AnchorPoint: new Vector2(0.5, 0.5),
		BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 1,
	}, {
		Corner: e("uicorner", { CornerRadius: new UDim(0, FORGE_RADIUS - 2) }),
		Rule: e("uistroke", { Color: P.brass, Thickness: 1, Transparency: 0.75 }),
	});
}

// 17-leaderboards type: serif for titles and podium numerals, GothamBold for numbers
const SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
const NUMERIC = Font.fromEnum(Enum.Font.GothamBold);
function face(font: Font, value: string, size: number, color: Color3, position: UDim2, box: UDim2, align?: Enum.TextXAlignment): React.Element {
	return e("textlabel", {
		Text: value, FontFace: font, TextColor3: color, TextScaled: true, TextWrapped: false, TextTruncate: Enum.TextTruncate.AtEnd,
		TextXAlignment: align ?? Enum.TextXAlignment.Left, BackgroundTransparency: 1, BorderSizePixel: 0, Position: position, Size: box, ZIndex: 3,
	}, { Fit: e("uitextsizeconstraint", { MaxTextSize: size, MinTextSize: 9 }) });
}

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

function bar(ratio: number, color: Color3, position: UDim2, size: UDim2): React.Element {
	return e("frame", { BackgroundColor3: P.ink, BackgroundTransparency: 0.1, BorderSizePixel: 0, Position: position, Size: size }, {
		Corner: e("uicorner", { CornerRadius: new UDim(1, 0) }),
		Fill: e("frame", { BackgroundColor3: color, BorderSizePixel: 0, Size: UDim2.fromScale(math.max(ratio, 0.015), 1) }, {
			Corner: e("uicorner", { CornerRadius: new UDim(1, 0) }),
		}),
	});
}

interface ChipProps {
	text: string;
	icon: string;
	accent: Color3;
	active: boolean;
	position?: UDim2;
	size?: UDim2;
	disabled?: boolean;
	reducedMotion?: boolean;
	onClick: () => void;
}

function chip(props: ChipProps): React.Element {
	return e(ui.Button, {
		text: props.text, icon: props.icon, color: props.accent,
		outline: !props.active, highlight: props.active,
		position: props.position, size: props.size, disabled: props.disabled,
		reducedMotion: props.reducedMotion, onClick: props.onClick,
	});
}

interface AvatarViewProps {
	userId: number;
	accent: Color3;
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
				setStatus("Avatar taking too long. Retry.");
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
				setStatus("Avatar unavailable. Retry.");
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

	return e("frame", { Name: "RankAvatar", Size: props.size, Position: props.position, BackgroundTransparency: 1 }, {
		View: e("viewportframe", {
			Name: "AvatarViewport", ref, Size: new UDim2(1, 0, 1, -54), BackgroundTransparency: 1,
			Ambient: Color3.fromRGB(180, 185, 205), LightColor: Color3.fromRGB(255, 235, 215), LightDirection: new Vector3(-1, -1, -2),
		}),
		Status: status !== undefined ? e(ui.Text, { value: status, size: 11, color: P.creamSoft, wrap: true, fit: true, minSize: 9, align: Enum.TextXAlignment.Center, position: UDim2.fromOffset(0, 8), sizeConstraint: new UDim2(1, 0, 1, -62) }) : undefined,
		Turn: e(ui.Button, {
			text: status !== undefined && status !== "Loading avatar…" ? "Retry" : "Turn",
			icon: status !== undefined ? "Refresh.6" : "Crew.11", color: props.accent, outline: true,
			size: new UDim2(1, 0, 0, 48), position: new UDim2(0, 0, 1, -48),
			disabled: status === "Loading avatar…", reducedMotion: props.reducedMotion,
			onClick: () => {
				if (status !== undefined) {
					retry((v) => v + 1);
				} else {
					turn((v) => (v === 0 ? 30 : v === 30 ? -30 : 0));
				}
			},
		}),
	});
}

interface MarkProps {
	row: RankRow;
	guildBoard: boolean;
	accent: Color3;
	size: number;
	position: UDim2;
}

function mark(props: MarkProps): React.Element {
	const { row, guildBoard, accent, size, position } = props;
	if (guildBoard) {
		return e("frame", { BackgroundColor3: accent, BackgroundTransparency: 0.7, BorderSizePixel: 0, AnchorPoint: new Vector2(0.5, 0), Position: position, Size: UDim2.fromOffset(size, size) }, {
			Corner: e("uicorner", { CornerRadius: new UDim(0, math.floor(size * 0.28)) }),
			Stroke: e("uistroke", { Color: accent, Transparency: 0.2, Thickness: 1.5 }),
			Tag: e(ui.Text, { value: tostring(row.Tag ?? "?"), size: math.max(11, math.floor(size * 0.3)), weight: Enum.FontWeight.Bold, align: Enum.TextXAlignment.Center, sizeConstraint: UDim2.fromScale(1, 1) }),
		});
	}
	return e(Art.PlayerMark, { userId: row.UserId, accent, size, position, anchorPoint: new Vector2(0.5, 0) });
}

/**
 * Profile-style hook for rank rows (podium names, list rows and the pinned "you" row).
 * Return an accent to tint the row's mark, name and stroke. Undefined keeps the board's default colors.
 * The profile-style work plugs ProfileStyle data in here; nothing else in this file needs to change.
 */
// Scrolls the board so your row sits in the middle of the list. The rows are page sections named
// by id, so this finds the section and moves its scrolling frame; it does nothing if the row isn't
// mounted.
function scrollToRankRow(place: number, instant: boolean) {
	const gui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
	const pinned = gui?.FindFirstChild("RankPinnedYou", true);
	const scroller = pinned?.FindFirstAncestorWhichIsA("ScrollingFrame");
	const target = scroller?.FindFirstChild(`rank-row-${place}`, true);
	if (scroller === undefined || target === undefined || !target.IsA("GuiObject")) {
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
	// mark where you landed: the row outline lights up and settles back (a held glow with Reduced Motion)
	const stroke = target.FindFirstChildWhichIsA("UIStroke", true);
	if (stroke !== undefined) {
		const rest = stroke.Transparency;
		stroke.Transparency = 0;
		if (instant) {
			task.delay(0.8, () => {
				stroke.Transparency = rest;
			});
		} else {
			TweenService.Create(stroke, new TweenInfo(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.35), { Transparency: rest }).Play();
		}
	}
}

function rankRowStyle(row: RankRow, guildBoard: boolean): { accent?: Color3; frame?: ProfileStyle.FrameOption } | undefined {
	// only players in this server publish their style attributes; everyone else keeps the default look
	if (guildBoard || !typeIs(row.UserId, "number")) {
		return undefined;
	}
	const style = ProfileStyle.fromPlayer(game.GetService("Players").GetPlayerByUserId(row.UserId));
	return style.accent !== undefined || style.frame !== undefined ? { accent: style.accent, frame: style.frame } : undefined;
}

interface Section {
	id: string;
	height: number;
	element: React.Element;
}

function RankDashboard(helpers: Helpers): (props: Props) => React.Element {
	const boardList = [...helpers.boards];
	boardList.push(GUILD_META);
	function boardsIn(group: string): BoardMeta[] {
		const found: BoardMeta[] = [];
		for (const board of boardList) {
			if (board.group === group) {
				found.push(board);
			}
		}
		return found;
	}
	function groupOf(id: string): string {
		for (const board of boardList) {
			if (board.id === id) {
				return board.group;
			}
		}
		return "Economy";
	}
	return function (props: Props): React.Element {
		const viewport = useViewport();
		const hostRef = React.useRef<Frame>();
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

		// wide desktop: standing, categories and controls sit in a left column beside podium + rows
		const plan = splitColumns(measuredWidth, 360, 22, 1060);
		let narrow = measuredWidth < 620;
		// phones: one-line rows (place, mark, name, value) with the share bar along the bottom edge
		const phoneRow = measuredWidth < 420;
		const rankRowH = phoneRow ? 44 : 48;
		const reducedMotion = props.reducedMotion;
		const [selected, setSelected] = React.useState("Flux");
		const [scope, setScope] = React.useState("Global");
		const [revision, reload] = React.useState(0);
		const [query, setQuery] = React.useState("");

		// gamepad: standing > categories (groups, then boards) > scope/refresh/search/only-me > pinned you +
		// Find me > podium > rows. On wide desktop the left control column (Side) and podium/rows (Main)
		// step left/right. Re-claimed on board or scope change, like the old FocusClaim.
		useFocusOrder(
			hostRef,
			{
				regions: ["rank-standing", "rank-categories", "rank-controls", "rank-you", "rank-podium", "rank-row-*", "rank-no-match", "rank-empty"],
				first: ["rank-categories", "rank-controls"],
				columns: [["Side", "Main"]],
			},
			[selected, scope],
		);

		// gamepad: right-stick click jumps to your row, same as the Find me button
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
					scrollToRankRow(place, reducedRef.current);
					return Enum.ContextActionResult.Sink;
				},
				false,
				2300,
				Enum.KeyCode.ButtonR3,
			);
			return () => ContextActionService.UnbindAction(name);
		}, []);

		const [mineOnly, setMineOnly] = React.useState(false);
		const [result, setResult] = React.useState<{ rows: RankRow[]; loading: boolean; status: string }>({ rows: [], loading: true, status: "Loading rankings…" });
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
				setResult((previous) => ({ rows: previous.rows, loading: true, status: "Refreshing rankings…" }));
				function finish(reply: unknown) {
					if (!alive || !pending || serial !== request) {
						return;
					}
					pending = false;
					serial += 1;
					if (!typeIs(reply, "table") || (reply as { ok?: boolean }).ok !== true) {
						const message = typeIs(reply, "table") ? ((reply as { error?: string; message?: string }).error ?? (reply as { error?: string; message?: string }).message) : undefined;
						setResult((previous) => ({ rows: previous.rows, loading: false, status: message ?? "Rankings unavailable. Retry below." }));
						return;
					}
					const typedReply = reply as { GuildLeaderboard?: unknown[]; Leaderboard?: unknown[]; Players?: unknown[] };
					const entries = guildBoard ? typedReply.GuildLeaderboard ?? typedReply.Leaderboard : scope === "Server" ? helpers.serverEntries(typedReply.Players ?? [], selected) : typedReply.Leaderboard;
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
					setResult({ rows, loading: false, status: `Updated · ${rows.size()} entries · ${guildBoard ? "Guild activity" : scope + " board"}` });
				}
				task.delay(12, () => finish(undefined));
				const action = guildBoard ? "GetGuildLeaderboard" : scope === "Server" ? "GetPlayers" : "GetLeaderboard";
				const payload = action === "GetPlayers" ? {} : { Id: selected };
				const ok = pcall(() => props.dispatch(action, payload, finish));
				if (!ok) {
					finish({ ok: false, error: "Lost the connection to the rankings." });
				}
			}
			setResult({ rows: [], loading: true, status: "Loading rankings…" });
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
		let personalIndex: number | undefined;
		for (let index = 0; index < rows.size(); index++) {
			if (isMine(rows[index])) {
				personalIndex = index + 1;
				break;
			}
		}
		findPlaceRef.current = mineOnly ? undefined : personalIndex;
		reducedRef.current = reducedMotion === true;
		const ahead = personalIndex !== undefined ? rows[personalIndex - 2] : undefined;
		const gap = ahead !== undefined ? Math.Max(0, Math.ToNumber(Math.Sub(ahead.Value, own))) : 0;
		const top = rows[0]?.Value ?? 0;
		const sections: Section[] = [];
		function text(value: string, x: number, y: number, w: number, h: number, size?: number, color?: Color3, extra?: Record<string, unknown>): React.Element {
			const textProps: Record<string, unknown> = { value, position: new UDim2(0, x, 0, y), sizeConstraint: new UDim2(w, w === 1 ? -x : 0, 0, h), size: size ?? 14, color: color ?? P.cream, wrap: true };
			if (extra !== undefined) {
				for (const [k, v] of pairs(extra)) {
					textProps[k] = v;
				}
			}
			return e(ui.Text, textProps);
		}
		function section(id: string, height: number, children: Record<string, React.Element | undefined>, accent?: Color3) {
			sections.push({ id, height, element: e(ui.Panel, { size: UDim2.fromScale(1, 1), padding: 22, radius: FORGE_RADIUS, background: P.panel, accent: accent ?? P.brass }, { BrassRule: e(BrassRule, { pad: 22 }), ...children }) });
		}

		const mainNarrow = plan.split ? plan.main < 620 : narrow;
		const panelWidth = plan.split ? plan.side : measuredWidth;
		narrow = narrow || plan.split;
		// Standing card: your rank, your score and the climb to the next seat.
		const nextRatio = ahead !== undefined ? share(own, ahead.Value) : personalIndex === 1 ? 1 : share(own, top);
		const standing = personalIndex !== undefined ? `#${personalIndex}` : "—";
		section("rank-standing", narrow ? 190 : 168, {
			Icon: e(Art.Icon, { kind: meta.icon ?? "Leaderboard.2", color: meta.accent, accent: meta.accent, size: 28, spin: false, position: UDim2.fromOffset(0, 2) }),
			Title: face(SERIF, meta.label, 24, P.cream, UDim2.fromOffset(44, 0), new UDim2(1, -44, 0, 32)),
			Seat: face(SERIF, standing, 44, personalIndex === 1 ? MEDAL[1] : P.brass, UDim2.fromOffset(0, narrow ? 56 : 24), new UDim2(1, 0, 0, 48), Enum.TextXAlignment.Right),
			Score: face(NUMERIC, valueText(own), 16, P.cream, UDim2.fromOffset(0, narrow ? 70 : 64), new UDim2(0.6, 0, 0, 22)),
			Climb: bar(nextRatio, personalIndex === 1 ? MEDAL[1] : P.brass, new UDim2(0, 0, 0, narrow ? 112 : 100), new UDim2(1, 0, 0, 6)),
			Gap: text(Math.ToNumber(gap) > 0 ? `+${format.compactNumber(gap)} to #${personalIndex! - 1}` : personalIndex === undefined && rows.size() > 0 ? `${valueText(rows[rows.size() - 1].Value)} to #${rows.size()}` : "", 0, narrow ? 126 : 114, 1, 18, 11, P.creamSoft),
		});

		// Category picker: group strip, then the boards inside the group.
		const groupKids: Record<string, React.Element> = {};
		const groupCols = panelWidth < 480 ? 2 : panelWidth < 1000 ? 3 : 6;
		for (let index = 0; index < GROUPS.size(); index++) {
			const entry = GROUPS[index];
			const col = index % groupCols;
			const rowIndex = math.floor(index / groupCols);
			groupKids[entry.id] = chip({
				text: entry.label, icon: entry.icon, accent: group === entry.id ? meta.accent : P.muted, active: group === entry.id,
				position: new UDim2(col / groupCols, 2, 0, rowIndex * 56), size: new UDim2(1 / groupCols, -8, 0, 48), reducedMotion,
				onClick: () => {
					const first = boardsIn(entry.id)[0];
					if (first !== undefined) {
						setSelected(first.id);
					}
				},
			});
		}
		const groupRows = math.ceil(GROUPS.size() / groupCols);
		const inGroup = boardsIn(group);
		const boardCols = math.min(inGroup.size(), narrow ? 2 : 4);
		for (let index = 0; index < inGroup.size(); index++) {
			const board = inGroup[index];
			const col = index % boardCols;
			const rowIndex = math.floor(index / boardCols);
			groupKids[`board-${board.id}`] = chip({
				text: board.short ?? board.label, icon: board.icon, accent: board.accent, active: selected === board.id,
				position: new UDim2(col / boardCols, 2, 0, groupRows * 56 + 14 + rowIndex * 56), size: new UDim2(1 / boardCols, -8, 0, 48), reducedMotion,
				onClick: () => setSelected(board.id),
			});
		}
		groupKids.Divider = e("frame", { BackgroundColor3: P.brass, BackgroundTransparency: 0.6, BorderSizePixel: 0, Position: new UDim2(0, 0, 0, groupRows * 56 + 5), Size: new UDim2(1, 0, 0, 1) });
		section("rank-categories", groupRows * 56 + 14 + math.ceil(inGroup.size() / boardCols) * 56 + 32, groupKids);

		// Scope, refresh and search in one card.
		const controls: Record<string, React.Element> = { Status: text(result.status ?? "Rankings unavailable.", 0, 0, 1, 18, 11, P.creamSoft) };
		for (let index = 0; index < 2; index++) {
			const id = (["Global", "Server"] as const)[index];
			controls[id] = chip({
				text: id === "Global" ? "Global" : "This server", icon: id === "Global" ? "World.10" : "Command.5", accent: meta.accent, active: scope === id && !guildBoard,
				position: new UDim2((index) / 3, 2, 0, 24), size: new UDim2(1 / 3, -8, 0, 48), disabled: guildBoard, reducedMotion,
				onClick: () => {
					if (!guildBoard) {
						setScope(id);
					}
				},
			});
		}
		controls.Refresh = e(ui.Button, { text: result.loading ? "Loading…" : "Refresh", position: new UDim2(2 / 3, 2, 0, 24), size: new UDim2(1 / 3, -8, 0, 48), disabled: result.loading, reducedMotion, onClick: () => reload((v) => v + 1), color: P.mint });
		controls.Search = e(ui.SearchField, { value: query, onChange: setQuery, placeholder: guildBoard ? "Find a guild or tag" : "Find a player or user ID", accent: meta.accent, reducedMotion, position: new UDim2(0, 2, 0, 84), size: narrow ? new UDim2(1, -8, 0, 48) : new UDim2(2 / 3, -8, 0, 48) });
		controls.Mine = e(ui.Button, { text: mineOnly ? "Show everyone" : "Only me", icon: "Crew.12", color: P.mint, outline: !mineOnly, reducedMotion, position: narrow ? new UDim2(0, 2, 0, 140) : new UDim2(2 / 3, 2, 0, 84), size: narrow ? new UDim2(1, -8, 0, 48) : new UDim2(1 / 3, -8, 0, 48), onClick: () => setMineOnly((v) => !v) });
		section("rank-controls", narrow ? 220 : 164, controls);
		const sideEnd = sections.size();
		narrow = mainNarrow;

		function rankRow(row: RankRow, place: number | undefined, pinned: boolean): React.Element {
			const mine = isMine(row);
			const styled = rankRowStyle(row, guildBoard);
			const accent = styled?.accent ?? (mine ? P.mint : meta.accent);
			// same frame treatment as the player list card (thickness, gradient frames, a bit more opaque)
			const ring = frameStroke(styled?.frame, accent, pinned ? 2 : 1);
			// design/17-leaderboards .row: 44px num rank (22px, muted), name, .v value; your row ringed mango,
			// profile-style rank rings keep their own colours
			const ringColor = mine ? P.mango : ring.color;
			const ringT = mine ? 0 : ring.framed ? 0.45 : 0.95;
			return e("frame", {
				BackgroundColor3: P.white, BackgroundTransparency: 0, BorderSizePixel: 0, Size: new UDim2(1, 0, 0, rankRowH),
			}, {
				Surface: e(RowSurface, {}),
				Stroke: e("uistroke", { Color: ringColor, Transparency: ringT, Thickness: mine ? 2 : ring.thickness, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }, !mine && ring.gradient !== undefined ? { Gradient: e("uigradient", { Color: ring.gradient, Rotation: 35 }) } : undefined),
				Place: e("textlabel", { Text: place !== undefined ? tostring(place) : "–", FontFace: NUM, TextSize: phoneRow ? 18 : 22, TextColor3: P.muted, BackgroundTransparency: 1, TextXAlignment: Enum.TextXAlignment.Left, Position: UDim2.fromOffset(12, 0), Size: new UDim2(0, 44, 1, 0) }),
				Mark: mark({ row, guildBoard, accent, size: phoneRow ? 24 : 30, position: new UDim2(0, 12 + 44 + 12, 0.5, phoneRow ? -12 : -15) }),
				Name: e("textlabel", { Text: `${row.Name ?? "Unknown pilot"}${mine ? " (you)" : ""}${guildBoard && row.Tag ? ` [${row.Tag}]` : ""}`, FontFace: BODY_SEMI, TextSize: phoneRow ? 13 : 15, TextColor3: styled?.accent ?? P.cream, BackgroundTransparency: 1, TextXAlignment: Enum.TextXAlignment.Left, TextTruncate: Enum.TextTruncate.AtEnd, Position: UDim2.fromOffset(12 + 44 + 12 + (phoneRow ? 24 : 30) + 12, 0), Size: new UDim2(1, -(12 + 44 + 12 + (phoneRow ? 24 : 30) + 12 + 110), 1, 0) }),
				Value: e("textlabel", { Text: valueText(row.Value), FontFace: NUM, TextSize: phoneRow ? 15 : 17, TextColor3: P.mango, BackgroundTransparency: 1, TextXAlignment: Enum.TextXAlignment.Right, Position: new UDim2(1, -110, 0, 0), Size: new UDim2(0, 98, 1, 0) }),
			});
		}

		if (rows.size() === 0) {
			section("rank-empty", 96, {
				title: text(result.loading ? "…" : "—", 0, 0, 1, 30, 18),
			});
		} else {
			// Podium (design/17-leaderboards "Top three"): name, muted num value, then a plinth 150/210/110 tall,
			// medal colour fading to #1B151D, with the place in 40px title type
			const podium: Record<string, React.Element> = {};
			const podiumScale = narrow ? 0.6 : 1;
			const podiumH = math.floor(210 * podiumScale) + 10 + 22 + 10 + 18 + 10;
			for (const place of PODIUM_ORDER) {
				const row = rows[place - 1];
				if (row !== undefined) {
					const slot = PODIUM_ORDER.indexOf(place);
					const plinthH = math.floor((PODIUM_HEIGHT[place] ?? 110) * podiumScale);
					podium[`seat${place}`] = e("frame", { Name: `PodiumSeat${place}`, BackgroundTransparency: 1, Position: new UDim2(slot / 3, slot === 0 ? 0 : 7, 0, 0), Size: new UDim2(1 / 3, -10, 1, 0) }, {
						Name: e("textlabel", { Text: `${row.Name ?? "Unknown"}${isMine(row) ? " (you)" : ""}`, FontFace: BODY_BOLD, TextSize: narrow ? 14 : 18, TextColor3: rankRowStyle(row, guildBoard)?.accent ?? P.cream, BackgroundTransparency: 1, TextTruncate: Enum.TextTruncate.AtEnd, AnchorPoint: new Vector2(0, 1), Position: new UDim2(0, 0, 1, -(plinthH + 10 + 18 + 10)), Size: new UDim2(1, 0, 0, 22) }),
						Value: e("textlabel", { Text: valueText(row.Value), FontFace: NUM, TextSize: narrow ? 12 : 14, TextColor3: P.muted, BackgroundTransparency: 1, AnchorPoint: new Vector2(0, 1), Position: new UDim2(0, 0, 1, -(plinthH + 10)), Size: new UDim2(1, 0, 0, 18) }),
						Plinth: e("frame", { BackgroundColor3: P.white, BorderSizePixel: 0, AnchorPoint: new Vector2(0, 1), Position: UDim2.fromScale(0, 1), Size: new UDim2(1, 0, 0, plinthH) }, {
							Corner: e("uicorner", { CornerRadius: new UDim(0, 12) }),
							Fade: e("uigradient", { Rotation: 90, Color: new ColorSequence(MEDAL[place], Color3.fromRGB(27, 21, 29)) }),
							Place: e("textlabel", { Text: tostring(place), FontFace: TITLE_FACE, TextSize: narrow ? 28 : 40, TextColor3: Color3.fromRGB(12, 9, 14), BackgroundTransparency: 1, Position: UDim2.fromOffset(0, 12), Size: new UDim2(1, 0, 0, narrow ? 30 : 42) }),
						}),
					});
				}
			}
			section("rank-podium", podiumH + 44, { Heading: e(PanelHeading, { icon: "Leaderboard.2", title: "Top three", phone: narrow }), Seats: e("frame", { BackgroundTransparency: 1, Position: UDim2.fromOffset(0, 44), Size: new UDim2(1, 0, 0, podiumH) }, podium) }, P.brass);

			// Remaining rows: compact, with a share-of-leader bar.
			let shown = 0;
			const rankRows: Record<string, React.Element> = {};
			const start = query !== "" || mineOnly ? 0 : 3;
			for (let index = start; index < rows.size(); index++) {
				const row = rows[index];
				const mine = isMine(row);
				if (!matchesRank(row, query) || (mineOnly && !mine)) {
					continue;
				}
				shown += 1;
				rankRows[`rank-row-${index + 1}`] = e("frame", { Name: `rank-row-${index + 1}`, BackgroundTransparency: 1, Size: new UDim2(1, 0, 0, rankRowH), LayoutOrder: index }, { Row: rankRow(row, index + 1, false) });
			}
			if (shown > 0) {
				// design/17: ranked rows sit 12px apart inside one block (the page scaffold gap is 22)
				const rankRowGap = 12;
				sections.push({
					id: "rank-rows",
					height: shown * rankRowH + (shown - 1) * rankRowGap,
					element: e("frame", { BackgroundTransparency: 1, Size: UDim2.fromScale(1, 1) }, {
						List: e("uilistlayout", { Padding: new UDim(0, rankRowGap), SortOrder: Enum.SortOrder.LayoutOrder }),
						...rankRows,
					}),
				});
			}
			if (shown === 0 && (query !== "" || mineOnly)) {
				section("rank-no-match", 84, {
					title: text("—", 0, 0, 1, 28, 16),
				});
			}
		}
		// Your row, pinned under the list after a diamond rule (design/17-leaderboards).
		if (rows.size() > 0 && !mineOnly && query === "") {
			const you: RankRow = personalIndex !== undefined
				? rows[personalIndex - 1]
				: { Name: guildBoard ? "Your guild" : Players.LocalPlayer.DisplayName, UserId: guildBoard ? undefined : localId, Id: guildBoard ? guildId : undefined, Value: own };
			if (!guildBoard || guildId !== undefined) {
				// Find me: only when you're on the board below; jumps the list to your own row
				const findable = personalIndex !== undefined;
				sections.push({
					id: "rank-you",
					height: 9 + 12 + rankRowH + (findable ? theme.TapTarget + 8 : 0),
					element: e("frame", { Name: "RankPinnedYou", BackgroundTransparency: 1, Size: UDim2.fromScale(1, 1) }, {
						Rule: e("frame", { BackgroundTransparency: 1, Size: new UDim2(1, 0, 0, 9) }, { Rule: e(DiamondRule, {}) }),
						Row: e("frame", { BackgroundTransparency: 1, Position: UDim2.fromOffset(0, 21), Size: new UDim2(1, 0, 0, rankRowH) }, { Row: rankRow(you, personalIndex, true) }),
						Find: findable
							? e(ui.Button, {
									// with a pad connected, name the shortcut the way the hint bar does
									text: UserInputService.GamepadEnabled ? `Find me · ${KeyLabel(Enum.KeyCode.ButtonR3, "R3")}` : "Find me",
									icon: "Crew.12",
									color: P.mint,
									outline: true,
									reducedMotion,
									size: UDim2.fromOffset(UserInputService.GamepadEnabled ? 168 : 132, theme.TapTarget),
									position: new UDim2(1, UserInputService.GamepadEnabled ? -168 : -132, 0, 21 + rankRowH + 8),
									onClick: () => scrollToRankRow(personalIndex!, reducedMotion === true),
								})
							: undefined,
					}),
				});
			}
		}

		let planned = sections;
		if (plan.split) {
			const side = sections.filter((_, index) => index < sideEnd);
			const main = sections.filter((_, index) => index >= sideEnd);
			const rowH = math.max(stackHeight(side.map((entry) => entry.height), 22), stackHeight(main.map((entry) => entry.height), 22));
			planned = [
				{
					id: "rank-split",
					height: rowH,
					element: e(SplitColumns, {
						name: "RankSplit",
						height: rowH,
						plan,
						side: e(StackBlocks, { gap: 22, blocks: side as never }),
						main: e(StackBlocks, { gap: 22, blocks: main as never }),
					}),
				} as never,
			];
		}
		return e("frame", { Name: "RankDashboard", ref: hostRef, Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ClipsDescendants: false }, {
			Content: e(Scaffold, { sections: planned, gap: 22, tailPad: 80, scrollBarColor: P.brass, scrollBarThickness: 4 }),
		});
	};
}

export = RankDashboard;
