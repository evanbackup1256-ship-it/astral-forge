// Ranks: grouped categories, podium, your-standing card and scaled rows.
import React from "@rbxts/react";
import * as ProfileStyle from "../../Shared/AstralForge/Shared/ProfileStyle";
import { frameStroke } from "./CoreKit/profileFrame";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import { useViewport } from "./MotionKit/motion";
import { FocusClaim } from "./CoreKit/GamepadNavigationService";
import { OmegaMathApi } from "./lua";

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
	{ id: "Economy", label: "ECONOMY", icon: "Flux.17" },
	{ id: "Progression", label: "PROGRESSION", icon: "Rebirth.7" },
	{ id: "Activity", label: "ACTIVITY", icon: "Forge.24" },
	{ id: "Collection", label: "COLLECTION", icon: "Crate.16" },
	{ id: "Social", label: "GUILDS", icon: "Guild.2" },
];

const GUILD_META: BoardMeta = { id: "Guilds", short: "GUILDS", label: "Guild Halls", icon: "Guild.3", accent: P.violet, group: "Social", description: "Guild activity earned by banking and building together." };
const PODIUM_ORDER = [2, 1, 3];
const PODIUM_LIFT: Record<number, number> = { [1]: 1, [2]: 0.74, [3]: 0.56 };
const MEDAL: Record<number, Color3> = {
	[1]: Color3.fromRGB(255, 196, 92),
	[2]: Color3.fromRGB(196, 212, 230),
	[3]: Color3.fromRGB(214, 146, 98),
};

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
	return e("frame", { BackgroundColor3: Color3.fromRGB(20, 24, 38), BackgroundTransparency: 0.2, BorderSizePixel: 0, Position: position, Size: size }, {
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
	const scene = React.useRef<{ camera: Camera; target: Vector3; size: Vector3 } | undefined>(undefined);
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
		const camera = new Instance("Camera");
		camera.FieldOfView = 34;
		camera.Parent = viewport;
		viewport.CurrentCamera = camera;
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
			scene.current = { camera, target: bounds.Position, size };
			setStatus(undefined);
		});
		return () => {
			alive = false;
			task.cancel(timeout);
			scene.current = undefined;
			viewport.CurrentCamera = undefined;
			world.Destroy();
			camera.Destroy();
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
			if (tween !== undefined) {
				tween.Cancel();
			}
			const aspect = math.max(viewport.AbsoluteSize.X, 1) / math.max(viewport.AbsoluteSize.Y, 1);
			const size = current.size;
			const distance = (math.max(size.Y, size.X / math.max(aspect, 0.1)) * 0.56) / math.tan(math.rad(current.camera.FieldOfView / 2)) + size.Z / 2;
			const yaw = math.rad(angle);
			const eye = current.target.add(new Vector3(math.sin(yaw) * distance, distance * 0.08, -math.cos(yaw) * distance));
			const target = CFrame.lookAt(eye, current.target);
			if (animate && !props.reducedMotion) {
				tween = TweenService.Create(current.camera, new TweenInfo(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame: target });
				tween.Play();
			} else {
				current.camera.CFrame = target;
			}
		}
		fit(previousAngle.current !== angle);
		previousAngle.current = angle;
		const connection = viewport.GetPropertyChangedSignal("AbsoluteSize").Connect(() => fit(false));
		return () => {
			connection.Disconnect();
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
		Status: status !== undefined ? e(ui.Text, { value: status, size: 11, color: P.creamSoft, wrap: true, align: Enum.TextXAlignment.Center, position: UDim2.fromOffset(0, 8), sizeConstraint: new UDim2(1, 0, 1, -62) }) : undefined,
		Turn: e(ui.Button, {
			text: status !== undefined && status !== "Loading avatar…" ? "RETRY" : "TURN",
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
			Tag: e(ui.Text, { value: string.upper(tostring(row.Tag ?? "?")), size: math.max(11, math.floor(size * 0.3)), weight: Enum.FontWeight.Bold, align: Enum.TextXAlignment.Center, sizeConstraint: UDim2.fromScale(1, 1) }),
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

		const narrow = measuredWidth < 620;
		// phones: one-line rows (place, mark, name, value) with the share bar along the bottom edge
		const phoneRow = measuredWidth < 420;
		const rankRowH = phoneRow ? 46 : 58;
		const reducedMotion = props.reducedMotion;
		const [selected, setSelected] = React.useState("Flux");
		const [scope, setScope] = React.useState("Global");
		const [revision, reload] = React.useState(0);
		const [query, setQuery] = React.useState("");

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
					finish({ ok: false, error: "Rankings connection interrupted." });
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
			sections.push({ id, height, element: e(ui.Panel, { size: UDim2.fromScale(1, 1), padding: 16, accent: accent ?? meta.accent }, children) });
		}

		// Standing card: your rank, your score and the climb to the next seat.
		const nextRatio = ahead !== undefined ? share(own, ahead.Value) : personalIndex === 1 ? 1 : share(own, top);
		const standing = personalIndex !== undefined ? `#${personalIndex}` : "—";
		section("rank-standing", narrow ? 220 : 190, {
			Icon: e(Art.Icon, { kind: meta.icon ?? "Leaderboard.2", color: meta.accent, accent: meta.accent, size: 28, spin: false, position: UDim2.fromOffset(0, 2) }),
			Eyebrow: text(`RANKS · ${string.upper(group)} · ${guildBoard ? "GUILD HALLS" : string.upper(scope)}`, 40, 0, 1, 16, 11, meta.accent, { weight: Enum.FontWeight.Bold }),
			Title: text(meta.label, 40, 16, 1, 28, 22, P.cream, { weight: Enum.FontWeight.Bold }),
			About: text(meta.description, 0, 50, narrow ? 1 : 0.62, 34, 12, P.creamSoft),
			Seat: text(standing, 0, narrow ? 92 : 50, 1, 40, 34, personalIndex === 1 ? MEDAL[1] : P.cream, { weight: Enum.FontWeight.Heavy, align: Enum.TextXAlignment.Right }),
			Score: text(`${guildBoard ? "Your hall" : "You"} · ${valueText(own)}`, 0, narrow ? 96 : 92, 0.7, 18, 13, P.cream, { weight: Enum.FontWeight.SemiBold }),
			Climb: bar(nextRatio, personalIndex === 1 ? MEDAL[1] : meta.accent, new UDim2(0, 0, 0, narrow ? 124 : 118), new UDim2(1, 0, 0, 6)),
			Gap: text(Math.ToNumber(gap) > 0 ? `${format.compactNumber(gap)} more to pass #${personalIndex! - 1} ${ahead!.Name ?? ""}` : personalIndex === 1 ? "You're ranked #1." : personalIndex === undefined && rows.size() > 0 ? `Outside the top ${rows.size()}. Reach ${valueText(rows[rows.size() - 1].Value)} to enter the board.` : "No standings yet for this board.", 0, narrow ? 136 : 130, 1, 18, 11, P.creamSoft),
		});

		// Category picker: group strip, then the boards inside the group.
		const groupKids: Record<string, React.Element> = {};
		const groupCols = measuredWidth < 480 ? 2 : measuredWidth < 1000 ? 3 : 6;
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
		groupKids.Divider = e("frame", { BackgroundColor3: meta.accent, BackgroundTransparency: 0.75, BorderSizePixel: 0, Position: new UDim2(0, 0, 0, groupRows * 56 + 5), Size: new UDim2(1, 0, 0, 1) });
		section("rank-categories", groupRows * 56 + 14 + math.ceil(inGroup.size() / boardCols) * 56 + 32, groupKids);

		// Scope, refresh and search in one card.
		const controls: Record<string, React.Element> = { Status: text(result.status ?? "Rankings unavailable.", 0, 0, 1, 18, 11, P.creamSoft) };
		for (let index = 0; index < 2; index++) {
			const id = (["Global", "Server"] as const)[index];
			controls[id] = chip({
				text: id === "Global" ? "GLOBAL" : "THIS SERVER", icon: id === "Global" ? "World.10" : "Command.5", accent: meta.accent, active: scope === id && !guildBoard,
				position: new UDim2((index) / 3, 2, 0, 24), size: new UDim2(1 / 3, -8, 0, 48), disabled: guildBoard, reducedMotion,
				onClick: () => {
					if (!guildBoard) {
						setScope(id);
					}
				},
			});
		}
		controls.Refresh = e(ui.Button, { text: result.loading ? "LOADING…" : "REFRESH", position: new UDim2(2 / 3, 2, 0, 24), size: new UDim2(1 / 3, -8, 0, 48), disabled: result.loading, reducedMotion, onClick: () => reload((v) => v + 1), color: P.mint });
		controls.Search = e(ui.SearchField, { value: query, onChange: setQuery, placeholder: guildBoard ? "Find a guild or tag" : "Find a player or user ID", accent: meta.accent, reducedMotion, position: new UDim2(0, 2, 0, 84), size: narrow ? new UDim2(1, -8, 0, 48) : new UDim2(2 / 3, -8, 0, 48) });
		controls.Mine = e(ui.Button, { text: mineOnly ? "SHOW EVERYONE" : "ONLY ME", icon: "Crew.12", color: P.mint, outline: !mineOnly, reducedMotion, position: narrow ? new UDim2(0, 2, 0, 140) : new UDim2(2 / 3, 2, 0, 84), size: narrow ? new UDim2(1, -8, 0, 48) : new UDim2(1 / 3, -8, 0, 48), onClick: () => setMineOnly((v) => !v) });
		section("rank-controls", narrow ? 220 : 164, controls);

		function rankRow(row: RankRow, place: number | undefined, pinned: boolean): React.Element {
			const mine = isMine(row);
			const styled = rankRowStyle(row, guildBoard);
			const accent = styled?.accent ?? (mine ? P.mint : meta.accent);
			// same frame treatment as the player list card (thickness, gradient frames, a bit more opaque)
			const ring = frameStroke(styled?.frame, accent, pinned ? 2 : 1);
			return e("frame", {
				BackgroundColor3: mine ? Color3.fromRGB(22, 48, 44) : Color3.fromRGB(22, 26, 40),
				BackgroundTransparency: 0.08, BorderSizePixel: 0, Size: UDim2.fromScale(1, 1),
			}, {
				Corner: e("uicorner", { CornerRadius: new UDim(0, 14) }),
				Stroke: e("uistroke", { Color: ring.color, Transparency: mine ? 0.2 : ring.framed ? 0.45 : 0.8, Thickness: ring.thickness }, ring.gradient !== undefined ? { Gradient: e("uigradient", { Color: ring.gradient, Rotation: 35 }) } : undefined),
				...(phoneRow
					? {
							Place: e(ui.Text, { value: place !== undefined ? tostring(place) : "–", size: 13, weight: Enum.FontWeight.Bold, color: mine ? P.mint : P.muted, align: Enum.TextXAlignment.Center, fit: true, minSize: 9, position: UDim2.fromOffset(2, 0), sizeConstraint: new UDim2(0, 28, 1, -4) }),
							Mark: mark({ row, guildBoard, accent, size: 26, position: new UDim2(0, 44, 0.5, -15) }),
							Name: e(ui.Text, { value: `${row.Name ?? "Unknown pilot"}${mine ? " · YOU" : ""}${guildBoard && row.Tag ? ` [${row.Tag}]` : ""}`, size: 13, fit: true, minSize: 9, weight: Enum.FontWeight.SemiBold, color: styled?.accent ?? (mine ? P.mint : P.cream), position: UDim2.fromOffset(64, 12), sizeConstraint: new UDim2(1, -64 - 92, 0, 18) }),
							Value: e(ui.Text, { value: valueText(row.Value), size: 13, fit: true, minSize: 9, weight: Enum.FontWeight.Bold, color: P.cream, align: Enum.TextXAlignment.Right, position: new UDim2(1, -90, 0, 12), sizeConstraint: UDim2.fromOffset(80, 18) }),
							Share: bar(share(row.Value, top), accent, new UDim2(0, 64, 1, -7), new UDim2(1, -76, 0, 3)),
						}
					: {
						Place: e(ui.Text, { value: place !== undefined ? tostring(place) : "–", size: 15, weight: Enum.FontWeight.Bold, color: mine ? P.mint : P.muted, align: Enum.TextXAlignment.Center, fit: true, minSize: 9, position: UDim2.fromOffset(4, 0), sizeConstraint: new UDim2(0, 40, 1, 0) }),
						Mark: mark({ row, guildBoard, accent, size: 34, position: new UDim2(0, 62, 0.5, -17) }),
						Name: e(ui.Text, { value: `${row.Name ?? "Unknown pilot"}${mine ? " · YOU" : ""}${guildBoard && row.Tag ? ` [${row.Tag}]` : ""}`, size: 14, fit: true, minSize: 9, weight: Enum.FontWeight.SemiBold, color: styled?.accent ?? (mine ? P.mint : P.cream), position: UDim2.fromOffset(90, 9), sizeConstraint: new UDim2(narrow ? 1 : 0.6, narrow ? -104 : -90, 0, 18) }),
						Value: e(ui.Text, { value: valueText(row.Value), size: 13, fit: true, minSize: 9, weight: Enum.FontWeight.Bold, color: P.cream, align: Enum.TextXAlignment.Right, position: narrow ? UDim2.fromOffset(90, 29) : new UDim2(0.6, 0, 0, 9), sizeConstraint: new UDim2(narrow ? 1 : 0.4, narrow ? -104 : -14, 0, 18) }),
						Share: bar(share(row.Value, top), accent, new UDim2(0, 90, 0, narrow ? 51 : 36), new UDim2(1, -104, 0, 4)),
						}),
			});
		}

		// Pinned "you" row: always visible above the podium so you never scroll to find yourself.
		if (rows.size() > 0 && !mineOnly && query === "") {
			const you: RankRow = personalIndex !== undefined
				? rows[personalIndex - 1]
				: { Name: guildBoard ? "Your guild" : Players.LocalPlayer.DisplayName, UserId: guildBoard ? undefined : localId, Id: guildBoard ? guildId : undefined, Value: own };
			if (!guildBoard || guildId !== undefined) {
				// Find me: only when you're on the board below; jumps the list to your own row
				const findable = personalIndex !== undefined;
				sections.push({
					id: "rank-you",
					height: rankRowH + (findable ? theme.TapTarget + 8 : 0),
					element: e("frame", { Name: "RankPinnedYou", BackgroundTransparency: 1, Size: UDim2.fromScale(1, 1) }, {
						Row: e("frame", { BackgroundTransparency: 1, Size: new UDim2(1, 0, 0, rankRowH) }, { Row: rankRow(you, personalIndex, true) }),
						Find: findable
							? e(ui.Button, {
									text: "FIND ME",
									icon: "Crew.12",
									color: P.mint,
									outline: true,
									reducedMotion,
									size: UDim2.fromOffset(132, theme.TapTarget),
									position: new UDim2(1, -132, 0, rankRowH + 8),
									onClick: () => scrollToRankRow(personalIndex!, reducedMotion === true),
								})
							: undefined,
					}),
				});
			}
		}

		if (rows.size() === 0) {
			section("rank-empty", 120, {
				title: text(result.loading ? "Finding the current leaders…" : "No one has scored here yet", 0, 0, 1, 30, 18),
				sub: text("Try another category, switch scope or refresh. Boards sync every few seconds while you play.", 0, 36, 1, 40, 12, P.creamSoft),
			});
		} else {
			// Podium: second, first, third, with stepped plinths.
			const podium: Record<string, React.Element> = {};
			const podiumOrder = narrow ? [1, 2, 3] : PODIUM_ORDER;
			for (const place of podiumOrder) {
				const row = rows[place - 1];
				if (row !== undefined) {
					const lift = PODIUM_LIFT[place];
					const color = MEDAL[place];
					const plinth = math.floor(64 * lift);
					const seatHeight = narrow ? 230 : 352;
					const infoX = narrow ? 0.5 : 0;
					const infoWidth = narrow ? 0.5 : 1;
					const slot = podiumOrder.indexOf(place) + 1;
					podium[`seat${place}`] = e("frame", { Name: `PodiumSeat${place}`, BackgroundTransparency: 1, Position: narrow ? UDim2.fromOffset(0, (slot - 1) * 242) : new UDim2((slot - 1) / 3, 4, 0, 0), Size: new UDim2(narrow ? 1 : 1 / 3, narrow ? 0 : -8, 0, seatHeight) }, {
						Avatar: !guildBoard ? e(AvatarView, { userId: row.UserId!, accent: color, reducedMotion, position: UDim2.fromOffset(4, 0), size: new UDim2(narrow ? 0.46 : 1, -8, 0, narrow ? 222 : 230) }) : undefined,
						Mark: guildBoard ? mark({ row, guildBoard: true, accent: color, size: 70, position: narrow ? new UDim2(0.23, 0, 0, 58) : new UDim2(0.5, 0, 0, 90) }) : undefined,
						Name: text(`${row.Name ?? "Unknown"}${isMine(row) ? " · YOU" : ""}`, 0, 0, 1, 36, 14, rankRowStyle(row, guildBoard)?.accent ?? (isMine(row) ? P.mint : P.cream), { weight: Enum.FontWeight.Bold, align: Enum.TextXAlignment.Center, fit: true, minSize: 10, position: new UDim2(infoX, 0, 0, narrow ? 34 : 236), sizeConstraint: new UDim2(infoWidth, 0, 0, 36) }),
						Value: text(valueText(row.Value), 0, 0, 1, 28, 12, P.creamSoft, { align: Enum.TextXAlignment.Center, fit: true, minSize: 9, position: new UDim2(infoX, 0, 0, narrow ? 80 : 273), sizeConstraint: new UDim2(infoWidth, 0, 0, 28) }),
						Share: bar(share(row.Value, top), color, new UDim2(infoX, 8, 0, narrow ? 118 : 307), new UDim2(infoWidth, -16, 0, 4)),
						Plinth: e("frame", { BackgroundColor3: color, BackgroundTransparency: 0.72, BorderSizePixel: 0, AnchorPoint: new Vector2(0, 1), Position: new UDim2(infoX, 0, 1, 0), Size: new UDim2(infoWidth, 0, 0, narrow ? plinth : 32) }, {
							Corner: e("uicorner", { CornerRadius: new UDim(0, 10) }),
							Stroke: e("uistroke", { Color: color, Transparency: 0.35, Thickness: 1 }),
							Shade: e("uigradient", { Rotation: 90, Transparency: new NumberSequence(0, 0.65) }),
							Place: e(ui.Text, { value: tostring(place), size: place === 1 ? 26 : 20, weight: Enum.FontWeight.Heavy, color, align: Enum.TextXAlignment.Center, sizeConstraint: UDim2.fromScale(1, 1) }),
						}),
					});
				}
			}
			section("rank-podium", narrow ? math.min(rows.size(), 3) * 242 + 24 : 384, podium, MEDAL[1]);

			// Remaining rows: compact, with a share-of-leader bar.
			let shown = 0;
			const start = query !== "" || mineOnly ? 0 : 3;
			for (let index = start; index < rows.size(); index++) {
				const row = rows[index];
				const mine = isMine(row);
				if (!matchesRank(row, query) || (mineOnly && !mine)) {
					continue;
				}
				shown += 1;
				sections.push({ id: `rank-row-${index + 1}`, height: rankRowH, element: rankRow(row, index + 1, false) });
			}
			if (shown === 0 && (query !== "" || mineOnly)) {
				section("rank-no-match", 106, {
					title: text(mineOnly && personalIndex === undefined ? "Your entry is outside this board." : "No matching entries.", 0, 0, 1, 28, 16),
					sub: text("Clear the search or show everyone. The podium remains the current three.", 0, 34, 1, 40, 12, P.creamSoft),
				});
			}
		}
		return e("frame", { Name: "RankDashboard", ref: hostRef, Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ClipsDescendants: false }, {
			Content: e(Scaffold, { sections, gap: 10, tailPad: 80, scrollBarColor: meta.accent, scrollBarThickness: 4 }),
		});
	};
}

export = RankDashboard;
