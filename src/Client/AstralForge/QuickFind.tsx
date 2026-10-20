// Quick Find: one search box over every page, setting, machine, research, relic, world,
// boost, milestone and story chapter. Ctrl+K opens it, the top bar has a button.
// Picking a result opens its page with that page's search already filled in.
// It opens out of a molten seam, results cascade in, one slab glides between rows and a
// spark flies off the caret with every keypress.
import React from "@rbxts/react";
import Model from "./BrowseModel";
import * as theme from "./CoreKit/theme";
import { AppHelpers } from "./CoreKit/appNav";
import * as NavRoutes from "./CoreKit/navRouteTable";
import { useViewport, useFlipperSpring } from "./MotionKit/motion";
import ReadyBoard from "./ReadyBoard";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");
const GuiService = game.GetService("GuiService");
const RunService = game.GetService("RunService");
const TextService = game.GetService("TextService");

interface AudioApi {
	play(sound: string): void;
}
const AudioKit = require(script.Parent!.FindFirstChild("AudioKit")! as ModuleScript) as CallableFunction;
const Audio = (AudioKit("audio") as { Audio: AudioApi }).Audio;

const ArtKit = require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as CallableFunction;
const Icon = (ArtKit("Icon") as { Icon: unknown }).Icon;

interface JuiceApi {
	spark(this: void, at: Vector2, color: Color3, size: number): void;
}

const Palette = theme.Palette as Record<string, Color3> & {
	cyan: Color3;
	mint: Color3;
	violet: Color3;
	coral: Color3;
	pink: Color3;
	mango: Color3;
	cream: Color3;
	creamSoft: Color3;
	muted: Color3;
	ink: Color3;
	void: Color3;
	white: Color3;
	ember: Color3;
	panel: Color3;
	panelSoft: Color3;
	panelRaised: Color3;
	lineSoft: Color3;
};
const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

// ── Interfaces ──────────────────────────────────────────────────────────────────

interface KindMetaEntry {
	label: string;
	group: string;
	weight: number;
	accent: string;
	route?: string;
	icon?: string;
}

interface SearchEntry {
	key: string;
	kind: string;
	title: string;
	subtitle?: string;
	icon?: string;
	accent: Color3;
	route?: string;
	query?: string;
	category?: string;
	fields: string[];
	locked?: boolean;
	badge?: number;
	order?: number;
	run?: string;
}

interface Section {
	title: string;
	entries: SearchEntry[];
}

interface RowProps {
	entry: SearchEntry;
	selected: boolean;
	index: number;
	rightW: number;
	query: string;
	layoutOrder: number;
	onPick: (entry: SearchEntry) => void;
	onHover: (index: number) => void;
	tick: React.Binding<number>;
	appearAt: number | undefined;
}

interface HeaderProps {
	text: string;
	labelW: number;
	layoutOrder: number;
	tick: React.Binding<number>;
	appearAt: number | undefined;
}

interface QuickFindComponentProps {
	state: Record<string, unknown>;
	enabled?: boolean;
	reducedMotion?: boolean;
	chatUnread?: number;
	dispatch: (action: string) => void;
	navigate: (route: string) => void;
}

interface SettingsEntry {
	key: string;
	label: string;
	help: string;
	section: string;
}

interface SettingsSection {
	id: string;
	label: string;
}

interface SettingsSchemaType {
	ENTRIES: SettingsEntry[];
	SECTIONS: SettingsSection[];
}

interface GameConfigType {
	Machines?: { Id: string; Name: string; Description: string; Icon: string }[];
	Research?: { Id: string; Name: string; Description: string }[];
	Items?: { Definitions?: { Id: string; Name: string; Description: string; Rarity?: string; Slot?: string }[] };
	Zones?: { Id: string | number; Name: string; Tagline?: string; Description?: string }[];
	Boosts?: Record<string, { Name: string; Description: string }>;
	Achievements?: { Id: string; Name: string; Description: string }[];
	Story?: { Id?: string; Title: string; Chapter?: string; Summary?: string }[];
	Mail?: { Id?: string; Subject: string; Sender?: string }[];
}

interface LinkInfo {
	route: string;
	query?: string;
	category?: string;
}

// ── Module state ────────────────────────────────────────────────────────────────

// open requests from anywhere (top bar button, menu, keyboard)
const openers: Array<() => void> = [];

// extra words for each page so "money", "pets" or "spin" land somewhere useful
const PAGE_WORDS: Record<string, string> = {
	Overview: "home vault collect production summary dashboard",
	Workshop: "machines buy build production upgrade forge",
	Inventory: "relics items equip codex crates keys pets essence",
	Research: "upgrades bonuses permanent study",
	Shop: "store buy packs gamepass robux crates codes",
	Settings: "options audio sound music graphics controls mobile accessibility",
	Missions: "quests jobs tasks daily weekly",
	Rewards: "daily login streak claim free timed gifts",
	Wheel: "spin prize tokens cooldown",
	Bazaar: "black market supplies stock deals restock materials keys boosts",
	Boosts: "potions buffs multiplier overdrive surge",
	Worlds: "zones maps travel expedition",
	Lab: "orders cells power",
	StarGrid: "forge specializations builds handcraft deep reserves night shift preserved bonuses",
	Ascension: "ascension ascend final rebirth aether sigils harmony prestige",
	Echoes: "echo forge keep",
	ForgePath: "path pass track xp chests",
	Milestones: "achievements goals badges",
	Story: "chapters lore read vale",
	Command: "crew titles officers",
	Convergence: "co op event together",
	Guild: "clan team charter members",
	Crew: "friends online players",
	Chat: "talk messages",
	Mail: "inbox letters gifts parcels",
	Trade: "swap exchange offers",
	Leaderboards: "ranks top players best",
	Credits: "about thanks team",
	Admin: "owner moderation tools",
};

const KIND_META: Record<string, KindMetaEntry> = {
	Action: { label: "Action", group: "ACTIONS", weight: 1.35, accent: "mint" },
	Page: { label: "Page", group: "PAGES", weight: 1.3, accent: "cyan" },
	Setting: { label: "Setting", group: "SETTINGS", weight: 1.05, accent: "violet" },
	Machine: { label: "Machine", group: "MACHINES", weight: 1, accent: "coral", route: "Workshop", icon: "Forge.23" },
	Research: { label: "Research", group: "RESEARCH", weight: 1, accent: "cyan", route: "Research", icon: "Research.4" },
	Relic: { label: "Relic", group: "RELICS", weight: 0.95, accent: "violet", route: "Inventory", icon: "Inventory.7" },
	World: { label: "World", group: "WORLDS", weight: 0.95, accent: "mint", route: "Worlds", icon: "World.9" },
	Boost: { label: "Boost", group: "BOOSTS", weight: 0.95, accent: "pink", route: "Boosts", icon: "Boost.18" },
	Milestone: { label: "Milestone", group: "MILESTONES", weight: 0.85, accent: "mango", route: "Milestones", icon: "Milestone.5" },
	Story: { label: "Story", group: "STORY", weight: 0.85, accent: "mint", route: "Story", icon: "Story.6" },
	Letter: { label: "Letter", group: "MAIL", weight: 0.8, accent: "cyan", route: "Mail", icon: "Mail.5" },
	Section: { label: "Shop", group: "SHOP", weight: 1.15, accent: "mango", route: "Shop", icon: "Shop.14" },
	Deal: { label: "Black Market", group: "BLACK MARKET", weight: 1.1, accent: "violet", route: "Bazaar", icon: "Shop.15" },
};

function accentOf(key: string): Color3 {
	return Palette[key] ?? Palette.cyan;
}

let GameConfig: GameConfigType | undefined;
let SettingsSchema: SettingsSchemaType | undefined;
function loadData(): void {
	if (GameConfig === undefined) {
		const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");
		GameConfig = require(shared.WaitForChild("GameConfig") as ModuleScript) as GameConfigType;
		const SharedData = require(shared.WaitForChild("SharedData") as ModuleScript) as CallableFunction;
		SettingsSchema = SharedData("SettingsSchema") as SettingsSchemaType;
	}
}

function authored(entry: unknown): boolean {
	return typeIs(entry, "table") && typeIs((entry as { Name?: unknown }).Name, "string") && !tostring((entry as { Id?: unknown }).Id ?? "").find("^Horizon")[0];
}

// ── Static content index ────────────────────────────────────────────────────────

let staticIndex: SearchEntry[] | undefined;
function buildStatic(): SearchEntry[] {
	if (staticIndex !== undefined) {
		return staticIndex;
	}
	loadData();
	const list: SearchEntry[] = [];

	function add(kind: string, key: string, title: string, subtitle: string | undefined, extra: string | undefined, icon?: string, link?: LinkInfo): void {
		const meta = KIND_META[kind];
		list.push({
			key: kind + ":" + key,
			kind: kind,
			title: title,
			subtitle: subtitle,
			icon: icon ?? meta.icon,
			accent: accentOf(meta.accent),
			route: link !== undefined ? link.route : meta.route,
			query: link !== undefined ? link.query : title,
			category: link !== undefined ? link.category : undefined,
			fields: [Model.normalize(title), Model.normalize(subtitle ?? ""), Model.normalize(extra ?? "")],
		});
	}

	for (const entry of SettingsSchema!.ENTRIES) {
		let section: SettingsSection | undefined;
		for (const s of SettingsSchema!.SECTIONS) {
			if (s.id === entry.section) {
				section = s;
			}
		}
		add("Setting", entry.key, entry.label, entry.help, (section !== undefined ? section.label : "") + " settings", "Settings", { route: "Settings", query: entry.label });
	}

	for (const machine of GameConfig!.Machines ?? []) {
		if (authored(machine)) {
			add("Machine", machine.Id, machine.Name, machine.Description, "machine workshop", machine.Icon);
		}
	}

	for (const study of GameConfig!.Research ?? []) {
		if (authored(study)) {
			add("Research", study.Id, study.Name, study.Description, "research upgrade", "Research");
		}
	}

	const items = GameConfig!.Items;
	for (const relic of (items !== undefined ? items.Definitions : undefined) ?? []) {
		if (authored(relic)) {
			add("Relic", relic.Id, relic.Name, `${relic.Rarity ?? ""} · ${relic.Description ?? ""}`, `relic ${relic.Slot ?? ""} ${relic.Rarity ?? ""}`);
		}
	}

	for (const [index, zone] of ipairs(GameConfig!.Zones ?? [])) {
		if (authored(zone) && index <= 24) {
			add("World", tostring(zone.Id), zone.Name, zone.Tagline ?? zone.Description, "world zone travel");
		}
	}

	for (const [id, boost] of pairs(GameConfig!.Boosts ?? {})) {
		if (typeIs(boost, "table") && typeIs((boost as { Name?: unknown }).Name, "string")) {
			add("Boost", tostring(id), boost.Name, boost.Description, "boost potion");
		}
	}

	for (const achievement of GameConfig!.Achievements ?? []) {
		if (authored(achievement)) {
			add("Milestone", achievement.Id, achievement.Name, achievement.Description, "milestone achievement goal");
		}
	}

	for (const chapter of GameConfig!.Story ?? []) {
		if (typeIs(chapter, "table") && typeIs((chapter as { Title?: unknown }).Title, "string")) {
			add("Story", chapter.Id ?? chapter.Title, chapter.Title, `${chapter.Chapter ?? ""} · ${chapter.Summary ?? ""}`, "story chapter lore");
		}
	}

	for (const section of [
		{ id: "Daily", title: "Daily shop", body: "Today's rotating offers", words: "deals daily offers rotation", icon: "Calendar.4" },
		{ id: "Crates", title: "Crates", body: "Open crates with your keys", words: "keys open loot boxes", icon: "Crate.13" },
		{ id: "Skins", title: "Crate skins", body: "Change how your crates look", words: "cosmetics skins looks", icon: "Crate.14" },
		{ id: "Codex", title: "Relic codex", body: "Every relic, fusing and stars", words: "collection codex fuse stars relics", icon: "Artifact.8" },
		{ id: "Premium", title: "Premium shop", body: "Packs, passes and codes", words: "robux gamepass passes packs codes redeem", icon: "Shop.16" },
	]) {
		add("Section", section.id, section.title, section.body, section.words, section.icon, { route: "Shop", query: "", category: section.id });
	}

	for (const deal of [
		{ id: "Resources", title: "Market resources", body: "Stardust, cores, essence and fragments", words: "materials supplies stock", icon: "Dust.12" },
		{ id: "Keys", title: "Market keys", body: "Keys from Forge to Echo", words: "keys crates shipment", icon: "Crate.15" },
		{ id: "Boosts", title: "Market boosts", body: "Production cells and upgrades", words: "boosts power overdrive", icon: "Boost.19" },
		{ id: "Command", title: "Command supplies", body: "Signals, field notes and streak shields", words: "command experience signals crew", icon: "Mission.8" },
	]) {
		add("Deal", deal.id, deal.title, deal.body, deal.words, deal.icon, { route: "Bazaar", query: "", category: deal.id });
	}

	for (const letter of GameConfig!.Mail ?? []) {
		if (typeIs(letter, "table") && typeIs((letter as { Subject?: unknown }).Subject, "string")) {
			add("Letter", letter.Id ?? letter.Subject, letter.Subject, `From ${letter.Sender ?? "the forge"}`, "mail letter inbox");
		}
	}

	staticIndex = list;
	return list;
}

// ── Live index (depends on player state) ────────────────────────────────────────

interface RouteEntry {
	id: string;
	label: string;
	eyebrow: string;
	icon: string;
	accentKey: string;
}

interface NavGroup {
	label: string;
	routes: string[];
}

function buildLive(state: Record<string, unknown>, chatUnread?: number): SearchEntry[] {
	const list: SearchEntry[] = [];
	const routes: RouteEntry[] = [];
	for (const route of NavRoutes.PRIMARY_ROUTES) {
		routes.push(route as unknown as RouteEntry);
	}
	for (const route of NavRoutes.MORE_ROUTES) {
		routes.push(route as unknown as RouteEntry);
	}

	const groupLabel: Record<string, string> = {};
	for (const group of NavRoutes.NAV_GROUPS as unknown as NavGroup[]) {
		for (const id of group.routes) {
			groupLabel[id] = group.label;
		}
	}

	for (const [orderIdx, route] of ipairs(routes)) {
		const order = orderIdx;
		if (route.id === "Admin" && !((state.Admin as { Access?: boolean } | undefined)?.Access === true)) {
			continue;
		}
		const featureUnlocks = state.FeatureUnlocks as Record<string, { Unlocked?: boolean; Requirement?: string; Level?: number }> | undefined;
		const lock = featureUnlocks !== undefined ? featureUnlocks[route.id] : undefined;
		const locked = route.id !== "Trade" && lock !== undefined && lock.Unlocked === false;
		let badge = 0;
		const [ok, value] = pcall(() => {
			return AppHelpers.navBadge(route as unknown as Parameters<typeof AppHelpers.navBadge>[0], state as unknown as Parameters<typeof AppHelpers.navBadge>[1], chatUnread ?? 0);
		});
		if (ok && typeIs(value, "number")) {
			badge = value;
		}

		const lockSubtitle = locked
			? `Locked · ${lock!.Requirement ?? (lock!.Level !== undefined ? "Level " + lock!.Level : "not open yet")}`
			: `${groupLabel[route.id] ?? "Page"} · ${route.eyebrow}`;

		list.push({
			key: "Page:" + route.id,
			kind: "Page",
			title: route.label,
			subtitle: lockSubtitle,
			icon: route.icon,
			accent: accentOf(route.accentKey),
			route: route.id,
			locked: locked,
			badge: badge,
			order: order,
			fields: [
				Model.normalize(route.label),
				Model.normalize(route.eyebrow + " " + (groupLabel[route.id] ?? "")),
				Model.normalize((PAGE_WORDS[route.id] ?? "") + " " + route.id),
			],
		});
	}

	function action(id: string, title: string, subtitle: string, icon: string, words: string, run: string): void {
		list.push({
			key: "Action:" + id,
			kind: "Action",
			title: title,
			subtitle: subtitle,
			icon: icon,
			accent: Palette.mint,
			run: run,
			fields: [Model.normalize(title), Model.normalize(subtitle), Model.normalize(words)],
		});
	}

	action("Collect", "Collect vault", "Bank everything your machines made", "Vault", "collect bank vault cash flux claim", "CollectVault");
	action("Tour", "Replay the tour", "Walk through the basics again", "Guide", "tutorial help guide tour how to play", "ReplayTutorial");
	action("Notes", "Patch notes", "See what changed in this update", "Gift", "update changes news release version", "OpenRelease");

	return list;
}

// ── Constants ───────────────────────────────────────────────────────────────────

const WHITE_HOT = Color3.fromRGB(255, 244, 222);
const MAX_RESULTS = 40;
const ROW_H = 52;
const HEADER_H = 28;
const ROW_GAP = 2;
const CASCADE_ROWS = 14;

function easeOut(t: number): number {
	const u = 1 - math.clamp(t, 0, 1);
	return 1 - u * u * u;
}

// y of every row inside the list (headers, rows and the gap between them)
function rowOffsets(sections: Section[]): LuaTuple<[Record<number, number>, number]> {
	const ys: Record<number, number> = {};
	let y = 0;
	let index = 0;
	for (const [s, section] of ipairs(sections)) {
		if (s > 1) {
			y += ROW_GAP;
		}
		y += HEADER_H + ROW_GAP;
		for (let r = 1; r <= section.entries.size(); r++) {
			index += 1;
			if (r > 1) {
				y += ROW_GAP;
			}
			ys[index] = y;
			y += ROW_H;
		}
	}
	return $tuple(ys, y);
}

// ── Row component ───────────────────────────────────────────────────────────────

function Row(props: RowProps): React.Element {
	const entry = props.entry;
	const meta = KIND_META[entry.kind];
	const appearAt = props.appearAt;
	const arrive = props.tick.map((now: number) => {
		return appearAt === undefined ? 1 : easeOut((now - appearAt) / 0.24);
	});
	const selected = props.selected;

	return h("textbutton", {
		Size: new UDim2(1, 0, 0, ROW_H),
		LayoutOrder: props.layoutOrder,
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Text: "",
		ZIndex: 504,
		Event: {
			Activated: () => {
				props.onPick(entry);
			},
			MouseEnter: () => {
				props.onHover(props.index);
			},
		},
	}, h("frame", {
		// everything in the row rides in together
		Size: UDim2.fromScale(1, 1),
		Position: arrive.map((a: number) => {
			return UDim2.fromOffset((1 - a) * 14, 0);
		}),
		BackgroundTransparency: 1,
		ZIndex: 504,
	}, h("frame", {
		Size: UDim2.fromOffset(34, 34),
		Position: new UDim2(0, 12, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundColor3: theme.darken(entry.accent, 0.62),
		BackgroundTransparency: arrive.map((a: number) => {
			return 1 - a;
		}),
		BorderSizePixel: 0,
		ZIndex: 505,
	}, h("uicorner", { CornerRadius: new UDim(0, 9) }), h("uiscale", {
		Scale: props.tick.map((now: number) => {
			if (!selected) {
				return 1;
			}
			return 1 + math.sin(now * 5) * 0.035;
		}),
	}), h("frame", {
		Size: UDim2.fromOffset(20, 20),
		Position: UDim2.fromScale(0.5, 0.5),
		AnchorPoint: new Vector2(0.5, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 506,
	}, h(Icon, {
		kind: entry.locked ? "Lock.18" : entry.icon,
		color: entry.locked ? Palette.muted : entry.accent,
		accent: entry.accent,
		size: 20,
		spin: false,
	}))), h("textlabel", {
		Size: new UDim2(1, -(60 + props.rightW), 0, 20),
		Position: UDim2.fromOffset(58, 7),
		BackgroundTransparency: 1,
		Text: Model.highlight(entry.title, props.query, "#" + entry.accent.ToHex()),
		RichText: true,
		TextSize: 15,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: entry.locked ? Palette.creamSoft : selected ? WHITE_HOT : Palette.cream,
		TextTransparency: arrive.map((a: number) => {
			return 1 - a;
		}),
		TextXAlignment: Enum.TextXAlignment.Left,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 506,
	}), h("textlabel", {
		Size: new UDim2(1, -(60 + props.rightW), 0, 16),
		Position: UDim2.fromOffset(58, 28),
		BackgroundTransparency: 1,
		Text: entry.subtitle ?? "",
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3: Palette.muted,
		TextTransparency: arrive.map((a: number) => {
			return 1 - a;
		}),
		TextXAlignment: Enum.TextXAlignment.Left,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 506,
	}), props.rightW > 0 && h("frame", {
		Size: UDim2.fromOffset(props.rightW - 12, 22),
		Position: new UDim2(1, -12, 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 506,
	}, h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		HorizontalAlignment: Enum.HorizontalAlignment.Right,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 6),
		SortOrder: Enum.SortOrder.LayoutOrder,
	}), (entry.badge ?? 0) > 0 && h("textlabel", {
		Size: UDim2.fromOffset(0, 18),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: 1,
		BackgroundColor3: Palette.mango,
		Text: tostring(entry.badge),
		TextSize: 11,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3: Palette.ink,
		ZIndex: 507,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uipadding", { PaddingLeft: new UDim(0, 6), PaddingRight: new UDim(0, 6) })), h("textlabel", {
		Size: UDim2.fromOffset(0, 18),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: 2,
		BackgroundTransparency: 1,
		Text: meta.label,
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: selected ? entry.accent : Palette.muted,
		TextTransparency: arrive.map((a: number) => {
			return 1 - a;
		}),
		ZIndex: 507,
	}))));
}

// ── Header component ────────────────────────────────────────────────────────────

function Header(props: HeaderProps): React.Element {
	const appearAt = props.appearAt;
	const arrive = props.tick.map((now: number) => {
		return appearAt === undefined ? 1 : easeOut((now - appearAt) / 0.4);
	});

	return h("frame", {
		Size: new UDim2(1, 0, 0, HEADER_H),
		LayoutOrder: props.layoutOrder,
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h("textlabel", {
		Size: new UDim2(0, 0, 0, 14),
		AutomaticSize: Enum.AutomaticSize.X,
		Position: new UDim2(0, 12, 1, -8),
		AnchorPoint: new Vector2(0, 1),
		BackgroundTransparency: 1,
		Text: props.text,
		TextSize: 11,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Heavy),
		TextColor3: Palette.mango,
		TextTransparency: arrive.map((a: number) => {
			return 1 - a;
		}),
		ZIndex: 504,
	}), h("frame", {
		Size: arrive.map((a: number) => {
			return new UDim2(a, -(24 + props.labelW), 0, 1);
		}),
		Position: new UDim2(0, 20 + props.labelW, 1, -14),
		BackgroundColor3: Palette.lineSoft,
		BackgroundTransparency: 0.3,
		BorderSizePixel: 0,
		ZIndex: 504,
	}));
}

// ── Main component ──────────────────────────────────────────────────────────────

function QuickFindComponent(props: QuickFindComponentProps): React.Element {
	const state = props.state;
	const [open, setOpen] = React.useState(false);
	const [query, setQuery] = React.useState("");
	const [selected, setSelected] = React.useState(1);
	const boxRef = React.useRef<TextBox>();
	const listRef = React.useRef<ScrollingFrame>();
	const viewport = useViewport();
	const reduced = props.reducedMotion === true;
	const show = useFlipperSpring(open ? 1 : 0, reduced, 420, 30);
	const enabled = props.enabled !== false;
	const [tick, setTick] = React.useBinding(os.clock());
	// when the current results arrived (rows cascade from here) and when a row was picked
	const resultsAt = React.useRef(os.clock());
	const pickedAt = React.useRef(-10);

	const close = React.useCallback(() => {
		setOpen(false);
		const box = boxRef.current;
		if (box !== undefined) {
			box.ReleaseFocus();
		}
	}, []);

	React.useEffect(() => {
		const request = () => {
			if (enabled) {
				setQuery("");
				setSelected(1);
				resultsAt.current = os.clock() + 0.12;
				setOpen(true);
				Audio.play("open");
			}
		};
		openers.push(request);
		return () => {
			const at = openers.indexOf(request);
			if (at !== -1) {
				openers.remove(at);
			}
		};
	}, [enabled]);

	React.useEffect(() => {
		if (!enabled && open) {
			setOpen(false);
		}
	}, [enabled]);

	// one clock while it is on screen (and a little after, for the fold-away)
	React.useEffect(() => {
		const closingUntil = os.clock() + 0.6;
		const connection = RunService.RenderStepped.Connect(() => {
			const now = os.clock();
			setTick(now);
			if (!open && now > closingUntil) {
				connection.Disconnect();
			}
		});
		return () => {
			connection.Disconnect();
		};
	}, [open]);

	// keyboard: Ctrl+K opens, Escape closes, arrows move, Enter picks
	const resultsRef = React.useRef<SearchEntry[]>([]);
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input: InputObject, processed: boolean) => {
			if (input.UserInputType !== Enum.UserInputType.Keyboard) {
				return;
			}
			const key = input.KeyCode;
			if (!open) {
				if (!enabled || UserInputService.GetFocusedTextBox() !== undefined) {
					return;
				}
				const ctrl = UserInputService.IsKeyDown(Enum.KeyCode.LeftControl)
					|| UserInputService.IsKeyDown(Enum.KeyCode.RightControl)
					|| UserInputService.IsKeyDown(Enum.KeyCode.LeftMeta)
					|| UserInputService.IsKeyDown(Enum.KeyCode.RightMeta);
				// "/" belongs to Roblox chat, so only Ctrl/Cmd+K opens it from the keyboard
				if (key === Enum.KeyCode.K && ctrl) {
					QuickFind.open();
				}
				return;
			}
			if (key === Enum.KeyCode.Escape) {
				close();
				Audio.play("close");
			} else if (key === Enum.KeyCode.Down) {
				Audio.play("tick");
				setSelected((current: number) => {
					return math.min(resultsRef.current!.size(), current + 1);
				});
			} else if (key === Enum.KeyCode.Up) {
				Audio.play("tick");
				setSelected((current: number) => {
					return math.max(1, current - 1);
				});
			}
		});
		return () => {
			connection.Disconnect();
		};
	}, [open, enabled]);

	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const job = task.defer(() => {
			const box = boxRef.current;
			if (box !== undefined && box.Parent !== undefined) {
				box.CaptureFocus();
			}
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [open]);

	// build and rank
	let sections: Section[] = [];
	let flat: SearchEntry[] = [];
	let totalMatches = 0;
	if (open) {
		const live = buildLive(state, props.chatUnread);
		const byKey: Record<string, SearchEntry> = {};
		for (const entry of live) {
			byKey[entry.key] = entry;
		}
		const staticEntries = buildStatic();
		for (const entry of staticEntries) {
			byKey[entry.key] = entry;
		}
		const tokens = Model.tokens(query);
		if (tokens.size() === 0) {
			const [okReady, ready] = pcall(() => ReadyBoard.collect(state, GameConfig));
			if (okReady && (ready as unknown[]).size() > 0) {
				const items: SearchEntry[] = [];
				for (const entry of ready as Array<{ route: string; label: string; detail: string; icon: string; accent: Color3; count: number }>) {
					const page = byKey["Page:" + entry.route];
					if (page !== undefined) {
						items.push({
							key: page.key,
							kind: "Page",
							title: entry.label,
							subtitle: entry.detail,
							icon: entry.icon,
							accent: entry.accent,
							route: entry.route,
							badge: entry.count,
							fields: page.fields,
						});
					}
				}
				sections.push({ title: "READY NOW", entries: items });
			}
			const recent: SearchEntry[] = [];
			for (const key of Model.recent()) {
				if (byKey[key] !== undefined) {
					recent.push(byKey[key]);
				}
			}
			if (recent.size() > 0) {
				sections.push({ title: "RECENT", entries: recent });
			}
			const pages: SearchEntry[] = [];
			for (const entry of live) {
				if (entry.kind === "Page" && !entry.locked) {
					pages.push(entry);
				}
			}
			pages.sort((a, b) => {
				if (((a.badge ?? 0) > 0) !== ((b.badge ?? 0) > 0)) {
					return (a.badge ?? 0) > 0;
				}
				return (a.order ?? 0) < (b.order ?? 0);
			});
			sections.push({ title: "JUMP TO", entries: pages });
		} else {
			const scored: Array<{ entry: SearchEntry; score: number }> = [];
			const consider = (entry: SearchEntry) => {
				const value = Model.score(tokens, entry.fields);
				if (value > 0) {
					const weight = KIND_META[entry.kind].weight * (entry.locked ? 0.6 : 1);
					scored.push({ entry: entry, score: value * weight });
				}
			};
			for (const entry of live) {
				consider(entry);
			}
			for (const entry of staticEntries) {
				consider(entry);
			}
			scored.sort((a, b) => {
				if (a.score !== b.score) {
					return a.score > b.score;
				}
				return a.entry.title < b.entry.title;
			});
			totalMatches = scored.size();
			// best match first, then the rest grouped by what they are
			const byKind: Record<string, Section> = {};
			const kinds: Section[] = [];
			for (let i = 0; i < math.min(MAX_RESULTS, scored.size()); i++) {
				const entry = scored[i].entry;
				if (i === 0) {
					sections.push({ title: "BEST MATCH", entries: [entry] });
				} else {
					const label = KIND_META[entry.kind].group;
					if (byKind[label] === undefined) {
						byKind[label] = { title: label, entries: [] };
						kinds.push(byKind[label]);
					}
					byKind[label].entries.push(entry);
				}
			}
			for (const section of kinds) {
				sections.push(section);
			}
		}
		for (const section of sections) {
			for (const entry of section.entries) {
				flat.push(entry);
			}
		}
	}

	resultsRef.current = flat;
	const pickIndex = math.clamp(selected, 1, math.max(1, flat.size()));
	const [rowYs, listHeight] = rowOffsets(sections);

	// a new set of results cascades in
	const signature = query + "#" + tostring(flat.size());
	const lastSignature = React.useRef(signature);
	if (lastSignature.current !== signature) {
		lastSignature.current = signature;
		resultsAt.current = os.clock();
	}

	const pick = (entry: SearchEntry | undefined) => {
		if (entry === undefined) {
			return;
		}
		pickedAt.current = os.clock();
		Model.pushRecent(entry.key);
		close();
		if (entry.kind === "Action") {
			Audio.play("confirm");
			props.dispatch(entry.run!);
			return;
		}
		if (entry.kind !== "Page" && entry.route !== undefined) {
			Model.link(entry.route, { query: entry.query ?? entry.title, category: entry.category });
		}
		props.navigate(entry.route!);
	};

	// keep the highlighted row in view while arrowing
	React.useEffect(() => {
		const list = listRef.current;
		const top = rowYs[pickIndex];
		if (list === undefined || !open || top === undefined) {
			return;
		}
		const bottom = top + ROW_H;
		const view = list.AbsoluteWindowSize.Y;
		if (top - HEADER_H < list.CanvasPosition.Y) {
			list.CanvasPosition = new Vector2(0, math.max(0, top - HEADER_H));
		} else if (bottom > list.CanvasPosition.Y + view) {
			list.CanvasPosition = new Vector2(0, bottom - view);
		}
	}, [pickIndex, open, query]);

	// the selection slab glides to the highlighted row
	const slabY = useFlipperSpring(rowYs[pickIndex] ?? 0, reduced, 760, 44);
	const slabAccent = (flat[pickIndex - 1] !== undefined ? flat[pickIndex - 1].accent : undefined) ?? Palette.mango;

	const rows: Record<string, React.Element | undefined> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, ROW_GAP),
		}),
	};
	let order = 0;
	let index = 0;
	const width = math.min(680, viewport.width - 24);
	const rightW = width >= 520 ? 120 : 0;
	const cascadeFrom = reduced ? undefined : resultsAt.current;

	for (const [s, section] of ipairs(sections)) {
		order += 1;
		let labelW = 0;
		pcall(() => {
			labelW = TextService.GetTextSize(section.title, 11, Enum.Font.BuilderSansExtraBold, new Vector2(400, 20)).X;
		});
		rows["h" + s] = h(Header, {
			text: section.title,
			labelW: labelW,
			layoutOrder: order,
			tick: tick,
			appearAt: cascadeFrom !== undefined ? cascadeFrom + math.min(index, CASCADE_ROWS) * 0.02 : undefined,
		});
		for (const entry of section.entries) {
			order += 1;
			index += 1;
			const rowIndex = index;
			rows[entry.key + "#" + s] = h(Row, {
				entry: entry,
				selected: rowIndex === pickIndex,
				index: rowIndex,
				rightW: rightW,
				query: query,
				layoutOrder: order,
				onPick: pick,
				onHover: setSelected,
				tick: tick,
				appearAt: cascadeFrom !== undefined && rowIndex <= CASCADE_ROWS ? cascadeFrom + rowIndex * 0.022 : undefined,
			});
		}
	}

	const empty = open && flat.size() === 0 && h("frame", {
		Size: new UDim2(1, 0, 0, 120),
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h("textlabel", {
		Size: new UDim2(1, -24, 0, 22),
		Position: UDim2.fromOffset(12, 26),
		BackgroundTransparency: 1,
		Text: `Nothing matches "${query}"`,
		TextSize: 16,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: Palette.cream,
		TextXAlignment: Enum.TextXAlignment.Left,
		ZIndex: 504,
	}), h("textlabel", {
		Size: new UDim2(1, -24, 0, 40),
		Position: UDim2.fromOffset(12, 52),
		BackgroundTransparency: 1,
		Text: "Search works on page names, settings, relics, machines and research. Try \"music\", \"vault\" or a relic" + "'s name.",
		TextSize: 13,
		TextWrapped: true,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3: Palette.muted,
		TextXAlignment: Enum.TextXAlignment.Left,
		TextYAlignment: Enum.TextYAlignment.Top,
		ZIndex: 504,
	}));

	const [inset] = GuiService.GetGuiInset();
	const height = math.min(560, viewport.height - inset.Y - 48);
	const touch = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
	// the seam ignites first, then the panel unfolds down out of it
	const seam = show.map((amount: number) => {
		return math.clamp(amount * 1.8, 0, 1);
	});
	const unfold = show.map((amount: number) => {
		return math.clamp((amount - 0.3) / 0.7, 0, 1);
	});
	const shownCount = React.useRef(0);
	const countText = tick.map(() => {
		const target = query === "" ? flat.size() : totalMatches;
		shownCount.current! += (target - shownCount.current!) * 0.35;
		if (math.abs(target - shownCount.current!) < 0.5) {
			shownCount.current = target;
		}
		if (query === "") {
			return "";
		}
		const n = math.floor(shownCount.current! + 0.5);
		return `${n} found`;
	});

	return h("frame", {
		Size: UDim2.fromScale(1, 1),
		BackgroundTransparency: 1,
		Visible: show.map((amount: number) => {
			return amount > 0.01;
		}),
		ZIndex: 500,
	}, h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.void,
		BackgroundTransparency: show.map((amount: number) => {
			return 1 - math.clamp(amount, 0, 1) * 0.5;
		}),
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Selectable: false,
		Active: open,
		ZIndex: 500,
		Event: {
			Activated: () => {
				close();
				Audio.play("close");
			},
		},
	}), h("frame", {
		// the seam: a molten line the palette opens out of
		Size: seam.map((a: number) => {
			return UDim2.fromOffset(width * a, 2);
		}),
		Position: new UDim2(0.5, 0, 0, inset.Y + 24),
		AnchorPoint: new Vector2(0.5, 0.5),
		BackgroundColor3: Palette.white,
		BackgroundTransparency: show.map((amount: number) => {
			return 1 - math.clamp(amount * 2, 0, 1);
		}),
		BorderSizePixel: 0,
		ZIndex: 510,
	}, h("uigradient", {
		Color: new ColorSequence([
			new ColorSequenceKeypoint(0, Palette.ember),
			new ColorSequenceKeypoint(0.5, WHITE_HOT),
			new ColorSequenceKeypoint(1, Palette.ember),
		]),
		Offset: tick.map((now: number) => {
			return new Vector2(math.sin(now * 1.7) * 0.35, 0);
		}),
	})), h("frame", {
		Name: "QuickFind",
		Size: unfold.map((a: number) => {
			return UDim2.fromOffset(width, math.max(2, height * a));
		}),
		Position: new UDim2(0.5, 0, 0, inset.Y + 24),
		AnchorPoint: new Vector2(0.5, 0),
		BackgroundColor3: Palette.panel,
		BorderSizePixel: 0,
		ZIndex: 501,
		ClipsDescendants: true,
	}, h("uicorner", { CornerRadius: new UDim(0, 16) }), h("uistroke", {
		Color: Palette.lineSoft,
		Transparency: 0.3,
		Thickness: 1,
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size: new UDim2(1, -24, 0, 50),
		Position: UDim2.fromOffset(12, 12),
		BackgroundColor3: Palette.panelSoft,
		BorderSizePixel: 0,
		ZIndex: 502,
	}, h("uicorner", { CornerRadius: new UDim(0, 12) }), h("uistroke", {
		Color: Palette.mango,
		Thickness: 1,
		Transparency: tick.map((now: number) => {
			return 0.55 + math.sin(now * 2.2) * 0.15;
		}),
	}), h("frame", {
		Size: UDim2.fromOffset(22, 22),
		Position: new UDim2(0, 14, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h(Icon, { kind: "Search.9", color: Palette.mango, accent: Palette.mango, size: 22, spin: false })), h("textbox", {
		ref: boxRef,
		Size: new UDim2(1, -(48 + (touch ? 52 : 70) + 80), 1, 0),
		Position: UDim2.fromOffset(46, 0),
		BackgroundTransparency: 1,
		Text: query,
		PlaceholderText: "Pages, settings, relics, machines…",
		PlaceholderColor3: Palette.muted,
		TextColor3: Palette.cream,
		TextSize: 17,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextXAlignment: Enum.TextXAlignment.Left,
		ClearTextOnFocus: false,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 503,
		Change: {
			Text: (box: TextBox) => {
				if (box.Text !== query) {
					if (box.IsFocused() && box.Text.size() > query.size()) {
						Audio.play("searchType");
						// every keypress throws a spark off the end of the text
						if (!reduced) {
							pcall(() => {
								const Juice = require(script.Parent!.FindFirstChild("JuiceFx")! as ModuleScript) as JuiceApi;
								const at = box.AbsolutePosition.add(new Vector2(math.min(box.TextBounds.X, box.AbsoluteSize.X) + 2, box.AbsoluteSize.Y / 2));
								Juice.spark(at, Palette.mango, 9 + math.random() * 5);
							});
						}
					}
					setQuery(box.Text);
					setSelected(1);
				}
			},
		},
		Event: {
			FocusLost: (_box: TextBox, enterPressed: boolean) => {
				if (enterPressed && open) {
					pick(resultsRef.current![pickIndex - 1]);
				}
			},
		},
	}), h("textlabel", {
		Size: UDim2.fromOffset(76, 30),
		Position: new UDim2(1, -(touch ? 60 : 76), 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundTransparency: 1,
		Text: countText,
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: Palette.muted,
		TextXAlignment: Enum.TextXAlignment.Right,
		ZIndex: 503,
	}), h("textbutton", {
		Size: UDim2.fromOffset(touch ? 44 : 58, 30),
		Position: new UDim2(1, -10, 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundColor3: Palette.panelRaised,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Text: touch ? "Close" : "Esc",
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
		TextColor3: Palette.muted,
		ZIndex: 503,
		Event: {
			Activated: () => {
				close();
				Audio.play("close");
			},
		},
	}, h("uicorner", { CornerRadius: new UDim(0, 8) }))), h("scrollingframe", {
		ref: listRef,
		Size: new UDim2(1, -16, 1, -(74 + (touch ? 8 : 30))),
		Position: UDim2.fromOffset(8, 70),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		CanvasSize: UDim2.fromOffset(0, flat.size() === 0 ? 120 : listHeight + 6),
		ScrollBarThickness: 3,
		ScrollBarImageColor3: Palette.muted,
		ScrollingDirection: Enum.ScrollingDirection.Y,
		ZIndex: 502,
	}, flat.size() > 0 && h("frame", {
		// the selection slab: one plate that glides between rows, its edge glowing in the row's colour
		Size: new UDim2(1, -4, 0, ROW_H),
		Position: slabY.map((y: number) => {
			return UDim2.fromOffset(0, y);
		}),
		BackgroundColor3: tick.map((now: number) => {
			const flash = 1 - math.clamp((now - pickedAt.current!) / 0.25, 0, 1);
			return Palette.panelRaised.Lerp(WHITE_HOT, flash * 0.7);
		}),
		BorderSizePixel: 0,
		ZIndex: 502,
	}, h("uicorner", { CornerRadius: new UDim(0, 10) }), h("uistroke", {
		Color: slabAccent,
		Transparency: 0.5,
		ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
	}), h("frame", {
		Size: new UDim2(0, 3, 1, -16),
		Position: new UDim2(0, 0, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundColor3: slabAccent,
		BorderSizePixel: 0,
		ZIndex: 504,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uigradient", {
		Rotation: 90,
		Color: new ColorSequence(slabAccent, WHITE_HOT),
		Offset: tick.map((now: number) => {
			return new Vector2(0, math.sin(now * 3) * 0.4);
		}),
	}))), h("frame", {
		Size: new UDim2(1, 0, 0, flat.size() === 0 ? 120 : listHeight),
		BackgroundTransparency: 1,
		ZIndex: 504,
	}, rows, empty)), !touch && h("textlabel", {
		Size: new UDim2(1, -24, 0, 22),
		Position: new UDim2(0, 12, 1, -26),
		BackgroundTransparency: 1,
		Text: "Up and Down to move  ·  Enter to open  ·  Ctrl+K from anywhere",
		TextSize: 12,
		FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
		TextColor3: Palette.muted,
		TextXAlignment: Enum.TextXAlignment.Left,
		ZIndex: 502,
	})));
}

// ── Module export ───────────────────────────────────────────────────────────────

const QuickFind = {
	open(): void {
		for (const fn of table.clone(openers)) {
			fn();
		}
	},
	rowOffsets,
	QuickFind: QuickFindComponent,
};

export = QuickFind;
