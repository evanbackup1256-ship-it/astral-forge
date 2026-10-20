// "Ready now": everything claimable across the game in one list, with the page that claims it.
// Overview shows it as a strip of jump buttons; Quick Find lists it before you type.
import React from "@rbxts/react";
import * as theme from "./CoreKit/theme";
import CrewStore = require("./CrewStore");

const TextService = game.GetService("TextService");
const Players = game.GetService("Players");

interface PageReadyMathApi {
	CountReadyQuests(this: void, quests: unknown): number;
	CountReadyLabOrders(this: void, lab: unknown): number;
	ForgePathReady(this: void, state: Record<string, unknown>, config: unknown): boolean;
}
const LayoutKit = require(script.Parent!.FindFirstChild("LayoutKit")! as ModuleScript) as CallableFunction;
const PageReadyMath = LayoutKit("pageReadyMath") as PageReadyMathApi;

interface AudioApi {
	play(sound: string): void;
}
const AudioKit = require(script.Parent!.FindFirstChild("AudioKit")! as ModuleScript) as CallableFunction;
const Audio = (AudioKit("audio") as { Audio: AudioApi }).Audio;

const ArtKit = require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction;
const Icon = (ArtKit("Icon") as { Icon: unknown }).Icon;

const Palette = theme.Palette;
const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

interface ReadyEntry {
	route: string;
	label: string;
	detail: string;
	count: number;
	icon: string;
	accent: Color3;
}

interface StripProps {
	list: ReadyEntry[];
	pillHeight?: number;
	onOpen: (route: string) => void;
	onFind?: () => void;
	compact?: boolean;
}

interface PillProps {
	entry: ReadyEntry;
	height: number;
	layoutOrder: number;
	brief: boolean;
	onOpen: (route: string) => void;
}

interface BoardApi {
	collect(this: void, state: Record<string, unknown>, config: unknown): ReadyEntry[];
	total(this: void, list: ReadyEntry[]): number;
	pillWidth(this: void, entry: ReadyEntry, brief: boolean): number;
	plan(this: void, list: ReadyEntry[], room: number, widthOf?: (entry: ReadyEntry, brief: boolean) => number): [ReadyEntry[], boolean, number];
	Strip(this: void, props: StripProps): React.Element;
}

function readyCount(list: unknown): number {
	let count = 0;
	const actualList = typeIs(list, "table") ? list : {};
	for (const entry of actualList as unknown[]) {
		if (
			typeIs(entry, "table") &&
			!(entry as { Claimed?: boolean }).Claimed &&
			(tonumber((entry as { Progress?: unknown }).Progress) ?? 0) >= (tonumber((entry as { Target?: unknown }).Target) ?? math.huge)
		) {
			count += 1;
		}
	}
	return count;
}

function unlocked(state: Record<string, unknown>, id: string): boolean {
	const locks = state.FeatureUnlocks as Record<string, { Unlocked?: boolean }> | undefined;
	const lock = locks?.[id];
	return !(lock !== undefined && lock.Unlocked === false);
}

// { route, label, detail, count, icon, accent } for every page with something to claim
function collect(state: Record<string, unknown>, config: unknown): ReadyEntry[] {
	const list: ReadyEntry[] = [];
	function add(route: string, label: string, detail: string, count: number, icon: string, accent: Color3) {
		if (count > 0 && unlocked(state, route)) {
			list.push({ route, label, detail, count, icon, accent });
		}
	}
	const daily = state.Daily as { CanClaim?: boolean } | undefined;
	const timed = state.TimedRewards as { PlaySeconds?: unknown; Rewards?: unknown[] } | undefined;
	const played = tonumber(timed?.PlaySeconds) ?? 0;
	let timedReady = 0;
	for (const entry of timed?.Rewards ?? []) {
		if (
			typeIs(entry, "table") &&
			!(entry as { Claimed?: boolean }).Claimed &&
			played >= (tonumber((entry as { Seconds?: unknown }).Seconds) ?? math.huge)
		) {
			timedReady += 1;
		}
	}
	const rewards = (daily?.CanClaim === true ? 1 : 0) + timedReady;
	add("Rewards", "Rewards", daily?.CanClaim === true ? "Daily parcel is ready" : "Playtime drop ready", rewards, "Gift", Palette.pink);
	add("Missions", "Missions", "Finished missions", PageReadyMath.CountReadyQuests(state.Quests), "Mission", Palette.green);
	add("Milestones", "Milestones", "Goals reached", readyCount(state.Achievements), "Milestone", Palette.mango);
	const wheel = state.Wheel as { CanSpin?: boolean } | undefined;
	if (wheel !== undefined && wheel.CanSpin === true) {
		add("Wheel", "Wheel", "Free spin ready", 1, "Wheel", Palette.mango);
	}
	const mailbox = state.Mailbox as { Unread?: unknown } | undefined;
	const unread = tonumber(mailbox?.Unread) ?? 0;
	add("Mail", "Mail", "Unread letters", unread, "Mail", Palette.cyan);
	add("Lab", "Lab", "Finished orders", PageReadyMath.CountReadyLabOrders(state.Lab), "Lab", Palette.mint);
	const [okPath, pathReady] = pcall(() => PageReadyMath.ForgePathReady(state, config));
	add("ForgePath", "Forge Path", "Step ready", okPath && pathReady ? 1 : 0, "Forge", Palette.violet);
	const trade = state.Trade as { Invite?: unknown } | undefined;
	const invite = trade?.Invite;
	add("Trade", "Trade", "Trade invite waiting", invite !== undefined ? 1 : 0, "Send", Palette.mint);
	// crews: an invite to answer, or crew-goal tiers this player can claim
	const [okCrew, crewState] = pcall(() => CrewStore.get());
	if (okCrew && typeIs(crewState, "table")) {
		const typedCrewState = crewState as { crew?: { Members?: unknown[]; Tiers?: unknown[]; Pooled?: unknown; MinContribution?: unknown }; invite?: { ExpiresAt?: unknown } };
		const crew = typedCrewState.crew;
		let claimable = 0;
		if (crew !== undefined && typeIs(crew.Tiers, "table")) {
			let mine = 0;
			for (const member of crew.Members ?? []) {
				if (typeIs(member, "table")) {
					const typedMember = member as { UserId?: number; Collects?: unknown };
					if (typedMember.UserId === Players.LocalPlayer.UserId) {
						mine = tonumber(typedMember.Collects) ?? 0;
					}
				}
			}
			for (const tier of crew.Tiers) {
				if (typeIs(tier, "table")) {
					const typedTier = tier as { Claimed?: boolean; Target?: unknown };
					if (!typedTier.Claimed && (tonumber(crew.Pooled) ?? 0) >= (tonumber(typedTier.Target) ?? math.huge) && mine >= (tonumber(crew.MinContribution) ?? 0)) {
						claimable += 1;
					}
				}
			}
		}
		const pending = typedCrewState.invite !== undefined && (tonumber(typedCrewState.invite.ExpiresAt) ?? 0) > os.time();
		add("Crew", "Crew", pending ? "Crew invite waiting" : "Crew goal ready", claimable + (pending ? 1 : 0), "Crew", Palette.green);
	}
	return list;
}

function total(list: ReadyEntry[]): number {
	let totalCount = 0;
	for (const entry of list) {
		totalCount += entry.count;
	}
	return totalCount;
}

function Pill(props: PillProps): React.Element {
	const entry = props.entry;
	const [hovered, setHovered] = React.useState(false);
	return h(
		"textbutton",
		{
			Size: UDim2.fromOffset(0, props.height),
			AutomaticSize: Enum.AutomaticSize.X,
			LayoutOrder: props.layoutOrder,
			BackgroundColor3: hovered ? theme.darken(entry.accent, 0.45) : theme.darken(entry.accent, 0.62),
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			Event: {
				Activated: () => {
					Audio.play("tabSwitch");
					props.onOpen(entry.route);
				},
				MouseEnter: () => setHovered(true),
				MouseLeave: () => setHovered(false),
			},
		},
		h("uicorner", { CornerRadius: new UDim(0, 12) }),
		h("uistroke", {
			Color: entry.accent,
			Transparency: hovered ? 0.1 : 0.45,
			ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
		}),
		h("uipadding", {
			PaddingLeft: new UDim(0, 10),
			PaddingRight: new UDim(0, 12),
		}),
		h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, 8),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(20, 20),
				BackgroundTransparency: 1,
				LayoutOrder: 0,
			},
			h(Icon, { kind: entry.icon, color: entry.accent, accent: entry.accent, size: 20, spin: false }),
		),
		h("textlabel", {
			Size: UDim2.fromOffset(0, props.height),
			AutomaticSize: Enum.AutomaticSize.X,
			BackgroundTransparency: 1,
			LayoutOrder: 1,
			Text: props.brief ? `<b>${entry.label}</b>` : `<b>${entry.label}</b>  <font transparency="0.35">${entry.detail}</font>`,
			RichText: true,
			TextSize: 14,
			FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
			TextColor3: Palette.cream,
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(0, 22),
				AutomaticSize: Enum.AutomaticSize.X,
				BackgroundColor3: entry.accent,
				BorderSizePixel: 0,
				LayoutOrder: 2,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uipadding", {
				PaddingLeft: new UDim(0, 8),
				PaddingRight: new UDim(0, 8),
			}),
			h("textlabel", {
				Size: UDim2.fromOffset(0, 22),
				AutomaticSize: Enum.AutomaticSize.X,
				BackgroundTransparency: 1,
				Text: tostring(entry.count),
				TextSize: 13,
				FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
				TextColor3: Palette.ink,
			}),
		),
	);
}

// Width a pill takes: padding, icon, label (+ detail), count badge.
function textWidth(text: string, font: Enum.Font): number {
	const [ok, size] = pcall(() => TextService.GetTextSize(text, 14, font, new Vector2(2000, 40)));
	return ok ? (size as Vector2).X : text.size() * 7;
}

function pillWidth(entry: ReadyEntry, brief: boolean): number {
	const label = textWidth(entry.label, Enum.Font.BuilderSansBold);
	const detail = brief ? 0 : textWidth("  " + entry.detail, Enum.Font.BuilderSansMedium);
	const count = textWidth(tostring(entry.count), Enum.Font.BuilderSansExtraBold) + 16;
	return 10 + 20 + 8 + label + detail + 8 + count + 12;
}

// Fit pills into `room`: full pills if they all fit, else label-only pills, else as many label-only
// pills as fit beside a "+N" pill. Returns (shown, brief, hidden) so nothing is cut by the edge.
function plan(list: ReadyEntry[], room: number, widthOf?: (entry: ReadyEntry, brief: boolean) => number): [ReadyEntry[], boolean, number] {
	const width = widthOf ?? pillWidth;
	function calculateTotal(entries: ReadyEntry[], brief: boolean, extra?: number): number {
		let sum = extra ?? 0;
		for (let index = 0; index < entries.size(); index++) {
			sum += width(entries[index], brief) + (index > 0 || extra !== undefined ? 8 : 0);
		}
		return sum;
	}
	if (room <= 0 || calculateTotal(list, false) <= room) {
		return [list, false, 0];
	}
	if (calculateTotal(list, true) <= room) {
		return [list, true, 0];
	}
	const moreW = 64;
	let shown: ReadyEntry[] = [];
	for (const entry of list) {
		const candidate = [...shown];
		candidate.push(entry);
		if (calculateTotal(candidate, true, moreW) > room) {
			break;
		}
		shown = candidate;
	}
	return [shown, true, list.size() - shown.size()];
}

// One row of jump buttons plus a Find button; height is fixed by the caller.
function Strip(props: StripProps): React.Element {
	const list = props.list;
	const pillH = props.pillHeight ?? 44;
	const stripRef = React.useRef<ScrollingFrame>();
	const [room, setRoom] = React.useState(0);
	React.useEffect(() => {
		const strip = stripRef.current!;
		if (strip === undefined) {
			return undefined;
		}
		function sync() {
			setRoom(math.floor(strip.AbsoluteSize.X));
		}
		sync();
		const connection = strip.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
		return () => connection.Disconnect();
	}, []);
	const [shownList, brief, hidden] = plan(list, room);
	const children: Record<string, React.Element> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			VerticalAlignment: Enum.VerticalAlignment.Center,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, 8),
		}),
	};
	for (let index = 0; index < shownList.size(); index++) {
		const entry = shownList[index];
		children[entry.route] = h(Pill, { entry, layoutOrder: index, height: pillH, onOpen: props.onOpen, brief });
	}
	if (hidden > 0) {
		children.more = h("textbutton", {
			Size: UDim2.fromOffset(56, pillH),
			LayoutOrder: shownList.size() + 1,
			BackgroundColor3: Palette.panelSoft,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: `+${hidden}`,
			TextSize: 14,
			FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
			TextColor3: Palette.cream,
			Event: { Activated: () => { if (props.onFind) props.onFind(); } },
		}, h("uicorner", { CornerRadius: new UDim(0, 12) }), h("uistroke", {
			Color: Palette.lineSoft, Transparency: 0.4, ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
		}));
	}
	if (list.size() === 0) {
		children.none = h("textlabel", {
			Size: UDim2.fromOffset(0, pillH),
			AutomaticSize: Enum.AutomaticSize.X,
			BackgroundTransparency: 1,
			LayoutOrder: 1,
			Text: "Nothing waiting right now. Keep forging.",
			TextSize: 14,
			FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
			TextColor3: Palette.muted,
		});
	}
	const findW = props.onFind !== undefined ? (props.compact ? pillH : 132) : 0;
	return h("frame", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.panel,
		BackgroundTransparency: 0.15,
		BorderSizePixel: 0,
	}, h("uicorner", { CornerRadius: new UDim(0, 14) }), h("uistroke", {
		Color: Palette.lineSoft,
		Transparency: 0.6,
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
	}), h("textlabel", {
		Size: UDim2.fromOffset(props.compact ? 0 : 92, pillH),
		Position: new UDim2(0, 14, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundTransparency: 1,
		Visible: !props.compact,
		Text: list.size() > 0 ? `READY · ${total(list)}` : "READY",
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3: list.size() > 0 ? Palette.green : Palette.muted,
		TextXAlignment: Enum.TextXAlignment.Left,
	}), h("scrollingframe", {
		Name: "ReadyStrip",
		ref: stripRef,
		Size: new UDim2(1, -((props.compact ? 12 : 112) + findW + (findW > 0 ? 20 : 12)), 1, 0),
		Position: UDim2.fromOffset(props.compact ? 10 : 106, 0),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		CanvasSize: new UDim2(0, 0, 0, 0),
		AutomaticCanvasSize: Enum.AutomaticSize.X,
		ScrollingDirection: Enum.ScrollingDirection.X,
		ScrollBarThickness: 0,
		ClipsDescendants: true,
	}, children), findW > 0 && h("textbutton", {
		Size: UDim2.fromOffset(findW, pillH),
		Position: new UDim2(1, -10, 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundColor3: Palette.panelSoft,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Text: "",
		Event: {
			Activated: () => { if (props.onFind) props.onFind(); },
		},
	}, h("uicorner", { CornerRadius: new UDim(0, 12) }), h("uistroke", {
		Color: Palette.lineSoft,
		Transparency: 0.4,
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size: UDim2.fromOffset(18, 18),
		Position: new UDim2(0, props.compact ? (findW - 18) / 2 : 12, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundTransparency: 1,
	}, h(Icon, { kind: "Search.10", color: Palette.cream, accent: Palette.cyan, size: 18, spin: false })), !props.compact && h("textlabel", {
		Size: new UDim2(1, -40, 1, 0),
		Position: UDim2.fromOffset(36, 0),
		BackgroundTransparency: 1,
		Text: "Find  <font transparency=\"0.5\">Ctrl+K</font>",
		RichText: true,
		TextSize: 14,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: Palette.cream,
		TextXAlignment: Enum.TextXAlignment.Left,
	})));
}

const Board: BoardApi = {
	collect,
	total,
	pillWidth,
	plan,
	Strip,
};

export = Board;
