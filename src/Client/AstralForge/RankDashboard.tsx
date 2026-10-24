// Ranks (design/17-leaderboards): group + board tabs, Top three podium beside the board rows, your row pinned under the rule.
import React from "@rbxts/react";
import * as ProfileStyle from "../../Shared/AstralForge/Shared/ProfileStyle";
import * as theme from "./CoreKit/theme";
import * as format from "./CoreKit/format";
import { useViewport } from "./MotionKit/motion";
import { KeyLabel } from "./CoreKit/GamepadNavigationService";
import { useFocusOrder } from "./CoreKit/focusOrder";
import { OmegaMathApi } from "./lua";
import { kitMember, LuauComponent } from "./pages/luauKits";
import { useHeroShown, useHeroSlot } from "./UiCore/heroSlot";

import { BODY_BOLD, BODY_SEMI, DiamondRule, MockPanel, NUM, PanelHeading, RowSurface, TITLE_FACE } from "./UiCore/mockKit";
// generated from design/17-leaderboards by scripts/gen_from_layout.js (scripts/layout/leaderboards.spec.json)
import { LeaderboardsLayout as L } from "./pages/generated/LeaderboardsLayout";
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
}
const UiCore = require(script.Parent!.FindFirstChild("UiCore")! as ModuleScript) as CallableFunction;
const ui = UiCore("ui") as UiApi;


interface ScaffoldApi {
	PageScaffold: unknown;
}
const LayoutKit = require(script.Parent!.FindFirstChild("LayoutKit")! as ModuleScript) as CallableFunction;
const Scaffold = (LayoutKit("pageScaffold") as ScaffoldApi).PageScaffold;

const P = theme.Palette;
const { SegmentedTabs } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
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

		// phones: one-line rows (place, mark, name, value) with the share bar along the bottom edge
		const phoneRow = measuredWidth < 420;
		const rankRowH = phoneRow ? 44 : L.Row.h;
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
				regions: ["rank-tabs", "rank-controls", "rank-podium", "rank-row-*", "rank-no-match", "rank-empty", "rank-you"],
				first: ["rank-tabs", "rank-controls"],
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
		// wide desktop: the board tabs sit in the shell .hero (kicker = group, line = what the board counts)
		const heroShown = useHeroShown();
		const heroBoards = boardsIn(group);
		useHeroSlot("Leaderboards", {
			kicker: GROUPS.find((entry) => entry.id === group)?.label ?? group,
			line: meta.description,
			tabs: { options: heroBoards.map((board) => ({ id: board.id, label: board.short ?? board.label })), value: selected, onChange: (id: string) => setSelected(id), accent: meta.accent, width: math.min(760, heroBoards.size() * 104 + 8) },
		});

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
		// design/17-leaderboards: .tabs strip (hero row), then .flexr [Top three .pn 640 | board .pn.f1];
		// phone.html: tabs, then one .pn of rows with the top three's numbers in medal colours
		const phone = measuredWidth < 1060;
		const pad = phone ? { x: 12, y: 10, gap: 8 } : { x: L.Board.pad.left, y: L.Board.pad.top, gap: L.Board.gap };
		const headH = phone ? 18 : 22;
		const ctlH = phone ? theme.TapTarget : 48;
		const nameOf = (row: RankRow) => `${row.Name ?? "Unknown pilot"}${isMine(row) ? " (you)" : ""}${guildBoard && row.Tag ? ` [${row.Tag}]` : ""}`;

		function rankRow(row: RankRow, place: number | undefined): React.Element {
			const mine = isMine(row);
			const styled = rankRowStyle(row, guildBoard);
			const numColor = phone && place !== undefined && place <= 3 ? MEDAL[place] : L.RowNum.text.color;
			return (
				<frame BackgroundColor3={P.white} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)}>
					<RowSurface />
					{mine && <uistroke Color={P.mango} Thickness={2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
					<uipadding PaddingLeft={new UDim(0, L.Row.pad.left)} PaddingRight={new UDim(0, L.Row.pad.right)} />
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, L.Row.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<textlabel LayoutOrder={0} Text={place !== undefined ? tostring(place) : "–"} FontFace={NUM} TextSize={L.RowNum.text.size} TextColor3={numColor} BackgroundTransparency={1} TextXAlignment={Enum.TextXAlignment.Left} Size={UDim2.fromOffset(L.RowNum.w, L.RowNum.h)} />
					<frame LayoutOrder={1} BackgroundTransparency={1} Size={new UDim2(0, 0, 0, L.RowName.h)}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						<textlabel Text={nameOf(row)} FontFace={BODY_SEMI} TextSize={phone ? 13 : L.RowName.text.size} TextColor3={styled?.accent ?? L.RowName.text.color} BackgroundTransparency={1} TextXAlignment={Enum.TextXAlignment.Left} TextTruncate={Enum.TextTruncate.AtEnd} Size={UDim2.fromScale(1, 1)} />
					</frame>
					<textlabel LayoutOrder={2} Text={valueText(row.Value)} FontFace={NUM} TextSize={phone ? 15 : L.RowValue.text.size} TextColor3={L.RowValue.text.color} BackgroundTransparency={1} AutomaticSize={Enum.AutomaticSize.X} TextXAlignment={Enum.TextXAlignment.Right} Size={UDim2.fromOffset(0, L.RowValue.h)} />
				</frame>
			);
		}
		const rowSlot = (key: string, order: number, child: React.Element) => (
			<frame key={key} LayoutOrder={order} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, rankRowH)}>
				{child}
			</frame>
		);

		// .tabs: board groups, then the boards of the group (the mockup's Cash/Rebirths/Crates/Friends slot)
		const groupOptions = GROUPS.map((entry) => ({ id: entry.id, label: entry.label }));
		const inGroup = boardsIn(group);
		const boardOptions = inGroup.map((board) => ({ id: board.id, label: board.short ?? board.label }));
		const pickGroup = (id: string) => {
			const first = boardsIn(id)[0];
			if (first !== undefined) setSelected(first.id);
		};
		const groupsW = GROUPS.size() * (phone ? 84 : 112);
		const boardsW = math.min(phone ? measuredWidth : 900, math.max(200, inGroup.size() * (phone ? 84 : 104)));
		const boardsInBody = !heroShown;
		const tabsH = phone ? ctlH * (boardsInBody ? 2 : 1) + (boardsInBody ? 8 : 0) : 48;
		const tabs = (
			<frame BackgroundTransparency={1} Size={UDim2.fromScale(1, 1)}>
				<uilistlayout FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal} HorizontalAlignment={phone ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Right} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame LayoutOrder={0} BackgroundTransparency={1} Size={phone ? new UDim2(1, 0, 0, ctlH) : UDim2.fromOffset(groupsW, 48)}>
					<SegmentedTabs options={groupOptions} value={group} onChange={pickGroup} accent={meta.accent} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
				</frame>
				{boardsInBody && (
					<frame LayoutOrder={1} BackgroundTransparency={1} Size={phone ? new UDim2(1, 0, 0, ctlH) : UDim2.fromOffset(boardsW, 48)}>
						<SegmentedTabs options={boardOptions} value={selected} onChange={(id: string) => setSelected(id)} accent={meta.accent} size={UDim2.fromScale(1, 1)} reducedMotion={reducedMotion} />
					</frame>
				)}
			</frame>
		);

		// board .pn: heading (board name, status note), scope / search / only-me / refresh row, rows, .rule, your row
		const boardKids: React.Element[] = [];
		boardKids.push(<PanelHeading key="head" icon={meta.icon ?? "Leaderboard.2"} title={meta.label} note={result.status} phone={phone} layoutOrder={0} />);
		const ctlKids: React.Element[] = [];
		const scopes = ["Global", "Server"] as const;
		scopes.forEach((id, index) => {
			ctlKids.push(
				<frame key={id} LayoutOrder={index} BackgroundTransparency={1} Size={new UDim2(0, phone ? 0 : 140, 1, 0)}>
					{phone && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
					{chip({ text: id === "Global" ? "Global" : "This server", icon: id === "Global" ? "World.10" : "Command.5", accent: meta.accent, active: scope === id && !guildBoard, size: UDim2.fromScale(1, 1), disabled: guildBoard, reducedMotion, onClick: () => { if (!guildBoard) setScope(id); } })}
				</frame>,
			);
		});
		const search = e(ui.SearchField, { value: query, onChange: setQuery, placeholder: guildBoard ? "Find a guild or tag" : "Find a player or user ID", accent: meta.accent, reducedMotion, size: UDim2.fromScale(1, 1) });
		const mineBtn = e(ui.Button, { text: mineOnly ? "Show everyone" : "Only me", icon: "Crew.12", color: P.mint, outline: !mineOnly, reducedMotion, size: UDim2.fromScale(1, 1), onClick: () => setMineOnly((v) => !v) });
		const refreshBtn = e(ui.Button, { text: result.loading ? "Loading…" : "Refresh", size: UDim2.fromScale(1, 1), disabled: result.loading, reducedMotion, onClick: () => reload((v) => v + 1), color: P.mint });
		if (!phone) {
			ctlKids.push(<frame key="search" LayoutOrder={2} BackgroundTransparency={1} Size={new UDim2(0, 0, 1, 0)}><uiflexitem FlexMode={Enum.UIFlexMode.Fill} />{search}</frame>);
			ctlKids.push(<frame key="mine" LayoutOrder={3} BackgroundTransparency={1} Size={new UDim2(0, 150, 1, 0)}>{mineBtn}</frame>);
			ctlKids.push(<frame key="refresh" LayoutOrder={4} BackgroundTransparency={1} Size={new UDim2(0, 120, 1, 0)}>{refreshBtn}</frame>);
		} else {
			ctlKids.push(<frame key="refresh" LayoutOrder={2} BackgroundTransparency={1} Size={new UDim2(0, 0, 1, 0)}><uiflexitem FlexMode={Enum.UIFlexMode.Fill} />{refreshBtn}</frame>);
		}
		const ctlRow = (key: string, order: number, kids: React.Element[]) => (
			<frame key={key === "ctl" ? "rank-controls" : key} LayoutOrder={order} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, ctlH)}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, pad.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{kids}
			</frame>
		);
		boardKids.push(ctlRow("ctl", 1, ctlKids));
		let boardContent = headH + pad.gap + ctlH;
		if (phone) {
			boardKids.push(ctlRow("ctl2", 2, [
				<frame key="search" LayoutOrder={0} BackgroundTransparency={1} Size={new UDim2(0, 0, 1, 0)}><uiflexitem FlexMode={Enum.UIFlexMode.Fill} />{search}</frame>,
				<frame key="mine" LayoutOrder={1} BackgroundTransparency={1} Size={new UDim2(0, 130, 1, 0)}>{mineBtn}</frame>,
			]));
			boardContent += pad.gap + ctlH;
		}
		const start = phone || query !== "" || mineOnly ? 0 : 3;
		let shown = 0;
		for (let index = start; index < rows.size(); index++) {
			const row = rows[index];
			if (!matchesRank(row, query) || (mineOnly && !isMine(row))) continue;
			shown += 1;
			boardKids.push(rowSlot(`rank-row-${index + 1}`, 10 + index, rankRow(row, index + 1)));
			boardContent += pad.gap + rankRowH;
		}
		if (shown === 0) {
			const empty = rows.size() === 0 ? (result.loading ? "…" : "—") : "No match";
			boardKids.push(
				<textlabel key={rows.size() === 0 ? "rank-empty" : "rank-no-match"} LayoutOrder={9} Text={empty} FontFace={BODY_SEMI} TextSize={15} TextColor3={P.muted} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, rankRowH)} />,
			);
			boardContent += pad.gap + rankRowH;
		}
		// your row, pinned under the diamond rule; the gap to the seat above and Find me share the line under it
		if (rows.size() > 0 && !mineOnly && query === "" && (!guildBoard || guildId !== undefined)) {
			const you: RankRow = personalIndex !== undefined
				? rows[personalIndex - 1]
				: { Name: guildBoard ? "Your guild" : Players.LocalPlayer.DisplayName, UserId: guildBoard ? undefined : localId, Id: guildBoard ? guildId : undefined, Value: own };
			const findable = personalIndex !== undefined;
			const gapLine = Math.ToNumber(gap) > 0 ? `+${format.compactNumber(gap)} to #${personalIndex! - 1}` : personalIndex === undefined ? `${valueText(rows[rows.size() - 1].Value)} to #${rows.size()}` : "";
			boardKids.push(<DiamondRule key="rule" layoutOrder={100000} />);
			boardKids.push(
				<frame key="RankPinnedYou" LayoutOrder={100001} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, rankRowH)}>
					{rankRow(you, personalIndex)}
				</frame>,
			);
			boardContent += pad.gap + L.Rule.h + pad.gap + rankRowH;
			if (findable || gapLine !== "") {
				const findW = UserInputService.GamepadEnabled ? 168 : 132;
				boardKids.push(
					<frame key="rank-you" LayoutOrder={100002} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, theme.TapTarget)}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, pad.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<frame LayoutOrder={0} BackgroundTransparency={1} Size={new UDim2(0, 0, 1, 0)}>
							<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
							<textlabel Text={gapLine} FontFace={BODY_SEMI} TextSize={12} TextColor3={P.muted} BackgroundTransparency={1} TextXAlignment={Enum.TextXAlignment.Left} Size={UDim2.fromScale(1, 1)} />
						</frame>
						{findable && (
							<frame LayoutOrder={1} BackgroundTransparency={1} Size={UDim2.fromOffset(findW, theme.TapTarget)}>
								{e(ui.Button, {
									// with a pad connected, name the shortcut the way the hint bar does
									text: UserInputService.GamepadEnabled ? `Find me · ${KeyLabel(Enum.KeyCode.ButtonR3, "R3")}` : "Find me",
									icon: "Crew.12", color: P.mint, outline: true, reducedMotion, size: UDim2.fromScale(1, 1),
									onClick: () => scrollToRankRow(personalIndex!, reducedMotion === true),
								})}
							</frame>
						)}
					</frame>,
				);
				boardContent += pad.gap + theme.TapTarget;
			}
		}
		const boardH = boardContent + pad.y * 2;

		// Top three .pn: name / muted num value / plinth 150-210-110, medal colour fading to #1B151D, seats on the floor
		const podiumH = 210 + L.Seat.gap * 2 + L.SeatName.h + L.SeatValue.h;
		const seats: React.Element[] = [];
		for (const place of PODIUM_ORDER) {
			const row = rows[place - 1];
			const slot = PODIUM_ORDER.indexOf(place);
			const plinthH = PODIUM_HEIGHT[place] ?? 110;
			seats.push(
				<frame key={`PodiumSeat${place}`} LayoutOrder={slot} BackgroundTransparency={1} Size={new UDim2(1 / 3, -((2 * L.PodiumSeats.gap) / 3), 1, 0)}>
					{row !== undefined && (
						<>
							<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalAlignment={Enum.VerticalAlignment.Bottom} HorizontalAlignment={Enum.HorizontalAlignment.Center} Padding={new UDim(0, L.Seat.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<textlabel LayoutOrder={0} Text={nameOf(row)} FontFace={BODY_BOLD} TextSize={L.SeatName.text.size} TextColor3={rankRowStyle(row, guildBoard)?.accent ?? L.SeatName.text.color} BackgroundTransparency={1} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, L.SeatName.h)} />
							<textlabel LayoutOrder={1} Text={valueText(row.Value)} FontFace={NUM} TextSize={L.SeatValue.text.size} TextColor3={L.SeatValue.text.color} BackgroundTransparency={1} Size={new UDim2(1, 0, 0, L.SeatValue.h)} />
							<frame LayoutOrder={2} BackgroundColor3={P.white} BorderSizePixel={0} Size={new UDim2(1, 0, 0, plinthH)}>
								<uicorner CornerRadius={new UDim(0, L.Plinth3.radius)} />
								<uigradient Rotation={90} Color={new ColorSequence(MEDAL[place], Color3.fromRGB(27, 21, 29))} />
								<textlabel Text={tostring(place)} FontFace={TITLE_FACE} TextSize={L.Plinth3.text.size} TextColor3={L.Plinth3.text.color} BackgroundTransparency={1} Position={UDim2.fromOffset(0, L.Plinth3.pad.top)} Size={new UDim2(1, 0, 0, L.Plinth3.text.size + 2)} />
							</frame>
						</>
					)}
				</frame>,
			);
		}
		const podiumPanelH = headH + pad.gap + podiumH + pad.y * 2;
		const bodyH = phone ? boardH : math.max(boardH, podiumPanelH);

		const board = (
			<MockPanel name="RankBoard" size={phone ? UDim2.fromScale(1, 1) : new UDim2(0, 0, 1, 0)} flex={!phone} phone={phone} layoutOrder={1} accent={meta.accent}>
				{boardKids}
			</MockPanel>
		);
		const body = phone ? (
			board
		) : (
			<frame BackgroundTransparency={1} Size={UDim2.fromScale(1, 1)}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.Body.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<MockPanel name="rank-podium" size={new UDim2(0, L.Podium.w, 1, 0)} phone={false} layoutOrder={0}>
					<PanelHeading icon="Leaderboard.2" title="Top three" phone={false} layoutOrder={0} />
					<frame LayoutOrder={1} BackgroundTransparency={1} Size={new UDim2(1, 0, 1, -(headH + pad.gap))}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.PodiumSeats.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{seats}
					</frame>
				</MockPanel>
				{board}
			</frame>
		);
		const planned: Section[] = [
			{ id: "rank-tabs", height: tabsH, element: tabs },
			{ id: "rank-body", height: bodyH, element: body },
		];
		return e("frame", { Name: "RankDashboard", ref: hostRef, Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ClipsDescendants: false }, {
			Content: e(Scaffold, { sections: planned, gap: phone ? 8 : L.Main.gap, tailPad: 80, scrollBarColor: P.brass, scrollBarThickness: 4 }),
		});
	};
}

export = RankDashboard;
