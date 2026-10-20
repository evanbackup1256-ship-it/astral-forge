// Quick Find: one search box over every page, setting, machine, research, relic, world,
// boost, milestone and story chapter. Ctrl+K opens it, the top bar has a button.
// Picking a result opens its page with that page's search already filled in.
// A centered glass panel springs open, results stagger in by section and one highlight glides
// between rows. Keyboard (Ctrl+K, arrows, Enter, Esc) and gamepad (DPad, A, B) both drive it.
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

// ── Layout and motion ───────────────────────────────────────────────────────────

const MAX_RESULTS = 40;
const ROW_H = 48;
const ROW_H_TOUCH = 44;
const HEADER_H = 26;
const ROW_GAP = 2;
const CASCADE_ROWS = 12;
const STAGGER = 0.025;
const ROW_IN = 0.2;
const FONT_BOLD = Font.fromName("BuilderSans", Enum.FontWeight.Bold);
const FONT_MED = Font.fromName("BuilderSans", Enum.FontWeight.Medium);
const FONT_HEAVY = Font.fromName("BuilderSans", Enum.FontWeight.Heavy);

function easeOut(t: number): number {
	const u = 1 - math.clamp(t, 0, 1);
	return 1 - u * u * u;
}

// y of every row inside the list (headers, rows and the gaps between them)
function rowOffsets(sections: Section[], rowH: number = ROW_H): LuaTuple<[Record<number, number>, number]> {
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
			y += rowH;
		}
	}
	return $tuple(ys, y);
}

// ── Search ──────────────────────────────────────────────────────────────────────

interface Results {
	sections: Section[];
	flat: SearchEntry[];
	total: number;
}

function search(state: Record<string, unknown>, query: string, chatUnread: number | undefined): Results {
	const sections: Section[] = [];
	const live = buildLive(state, chatUnread);
	const staticEntries = buildStatic();
	const byKey: Record<string, SearchEntry> = {};
	for (const entry of live) {
		byKey[entry.key] = entry;
	}
	for (const entry of staticEntries) {
		byKey[entry.key] = entry;
	}
	let total = 0;
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
			if (items.size() > 0) {
				sections.push({ title: "READY NOW", entries: items });
			}
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
		const pages = live.filter((entry) => entry.kind === "Page" && !entry.locked);
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
				scored.push({ entry, score: value * KIND_META[entry.kind].weight * (entry.locked ? 0.6 : 1) });
			}
		};
		live.forEach(consider);
		staticEntries.forEach(consider);
		scored.sort((a, b) => (a.score !== b.score ? a.score > b.score : a.entry.title < b.entry.title));
		total = scored.size();
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
	const flat: SearchEntry[] = [];
	for (const section of sections) {
		for (const entry of section.entries) {
			flat.push(entry);
		}
	}
	return { sections, flat, total };
}

// ── Row ─────────────────────────────────────────────────────────────────────────

function Row(props: RowProps & { rowH: number }): React.Element {
	const entry = props.entry;
	const meta = KIND_META[entry.kind];
	const appearAt = props.appearAt;
	const selected = props.selected;
	const arrive = props.tick.map((now: number) => (appearAt === undefined ? 1 : easeOut((now - appearAt) / ROW_IN)));
	const fadeText = arrive.map((a: number) => 1 - a);
	const compact = props.rowH < ROW_H;
	const textLeft = 56;
	const rightPad = props.rightW + 12;

	return h("textbutton", {
		Size: new UDim2(1, 0, 0, props.rowH),
		LayoutOrder: props.layoutOrder,
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Selectable: false,
		Text: "",
		ZIndex: 504,
		Event: {
			Activated: () => props.onPick(entry),
			MouseEnter: () => props.onHover(props.index),
		},
	}, h("frame", {
		Size: UDim2.fromScale(1, 1),
		Position: arrive.map((a: number) => UDim2.fromOffset(0, (1 - a) * 8)),
		BackgroundTransparency: 1,
		ZIndex: 504,
	},
	// icon tile
	h("frame", {
		Size: UDim2.fromOffset(32, 32),
		Position: new UDim2(0, 12, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundColor3: theme.darken(entry.accent, selected ? 0.45 : 0.68),
		BackgroundTransparency: arrive.map((a: number) => 1 - a),
		BorderSizePixel: 0,
		ZIndex: 505,
	}, h("uicorner", { CornerRadius: new UDim(0, 9) }),
	h("uistroke", { Color: entry.accent, Transparency: selected ? 0.35 : 0.8, Thickness: 1 }),
	h("frame", {
		Size: UDim2.fromOffset(18, 18),
		Position: UDim2.fromScale(0.5, 0.5),
		AnchorPoint: new Vector2(0.5, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 506,
	}, h(Icon, {
		kind: entry.locked ? "Lock.18" : entry.icon,
		color: entry.locked ? Palette.muted : entry.accent,
		accent: entry.accent,
		size: 18,
		spin: false,
	}))),
	// title + subtitle
	h("textlabel", {
		Size: new UDim2(1, -(textLeft + rightPad), 0, 18),
		Position: new UDim2(0, textLeft, 0.5, compact ? -17 : -18),
		BackgroundTransparency: 1,
		Text: Model.highlight(entry.title, props.query, "#" + entry.accent.ToHex()),
		RichText: true,
		TextSize: 15,
		FontFace: FONT_BOLD,
		TextColor3: entry.locked ? Palette.creamSoft : selected ? Palette.white : Palette.cream,
		TextTransparency: fadeText,
		TextXAlignment: Enum.TextXAlignment.Left,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 506,
	}), h("textlabel", {
		Size: new UDim2(1, -(textLeft + rightPad), 0, 15),
		Position: new UDim2(0, textLeft, 0.5, compact ? 1 : 2),
		BackgroundTransparency: 1,
		Text: entry.subtitle ?? "",
		TextSize: 12,
		FontFace: FONT_MED,
		TextColor3: Palette.muted,
		TextTransparency: fadeText,
		TextXAlignment: Enum.TextXAlignment.Left,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 506,
	}),
	// badge + kind chip
	props.rightW > 0 && h("frame", {
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
		FontFace: FONT_HEAVY,
		TextColor3: Palette.ink,
		ZIndex: 507,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uipadding", { PaddingLeft: new UDim(0, 6), PaddingRight: new UDim(0, 6) })),
	h("textlabel", {
		Size: UDim2.fromOffset(0, 20),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: 2,
		BackgroundColor3: selected ? theme.darken(entry.accent, 0.6) : Palette.panelSoft,
		BackgroundTransparency: arrive.map((a: number) => 1 - a * (selected ? 0.9 : 0.6)),
		Text: meta.label,
		TextSize: 11,
		FontFace: FONT_BOLD,
		TextColor3: selected ? entry.accent : Palette.muted,
		TextTransparency: fadeText,
		ZIndex: 507,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("uipadding", { PaddingLeft: new UDim(0, 8), PaddingRight: new UDim(0, 8) })))));
}

// ── Section header ──────────────────────────────────────────────────────────────

function Header(props: HeaderProps): React.Element {
	const appearAt = props.appearAt;
	const arrive = props.tick.map((now: number) => (appearAt === undefined ? 1 : easeOut((now - appearAt) / 0.3)));
	return h("frame", {
		Size: new UDim2(1, 0, 0, HEADER_H),
		LayoutOrder: props.layoutOrder,
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h("textlabel", {
		Size: new UDim2(0, 0, 0, 14),
		AutomaticSize: Enum.AutomaticSize.X,
		Position: new UDim2(0, 14, 1, -6),
		AnchorPoint: new Vector2(0, 1),
		BackgroundTransparency: 1,
		Text: props.text,
		TextSize: 11,
		FontFace: FONT_HEAVY,
		TextColor3: Palette.muted,
		TextTransparency: arrive.map((a: number) => 1 - a),
		ZIndex: 504,
	}), h("frame", {
		Size: arrive.map((a: number) => new UDim2(a, -(30 + props.labelW), 0, 1)),
		Position: new UDim2(0, 22 + props.labelW, 1, -12),
		BackgroundColor3: Palette.lineSoft,
		BackgroundTransparency: 0.5,
		BorderSizePixel: 0,
		ZIndex: 504,
	}));
}

// ── Footer key hint ─────────────────────────────────────────────────────────────

function KeyHint(props: { keys: string; label: string; order: number }): React.Element {
	return h("frame", {
		Size: UDim2.fromOffset(0, 20),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: props.order,
		BackgroundTransparency: 1,
	}, h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 5),
		SortOrder: Enum.SortOrder.LayoutOrder,
	}), h("textlabel", {
		Size: UDim2.fromOffset(0, 18),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: 1,
		BackgroundColor3: Palette.panelRaised,
		Text: props.keys,
		TextSize: 11,
		FontFace: FONT_BOLD,
		TextColor3: Palette.creamSoft,
		ZIndex: 503,
	}, h("uicorner", { CornerRadius: new UDim(0, 5) }), h("uipadding", { PaddingLeft: new UDim(0, 6), PaddingRight: new UDim(0, 6) }),
	h("uistroke", { Color: Palette.lineSoft, Transparency: 0.4, ApplyStrokeMode: Enum.ApplyStrokeMode.Border })),
	h("textlabel", {
		Size: UDim2.fromOffset(0, 18),
		AutomaticSize: Enum.AutomaticSize.X,
		LayoutOrder: 2,
		BackgroundTransparency: 1,
		Text: props.label,
		TextSize: 12,
		FontFace: FONT_MED,
		TextColor3: Palette.muted,
		ZIndex: 503,
	}));
}

// ── Hooks ───────────────────────────────────────────────────────────────────────

// a per-frame clock binding, live only while `active` (plus a short tail for the close fade)
function useFrameClock(active: boolean): React.Binding<number> {
	const [tick, setTick] = React.useBinding(os.clock());
	React.useEffect(() => {
		const stopAt = os.clock() + 0.4;
		const connection = RunService.RenderStepped.Connect(() => {
			const now = os.clock();
			setTick(now);
			if (!active && now > stopAt) {
				connection.Disconnect();
			}
		});
		return () => connection.Disconnect();
	}, [active]);
	return tick;
}

const NAV_DOWN = new Set<Enum.KeyCode>([Enum.KeyCode.Down, Enum.KeyCode.DPadDown]);
const NAV_UP = new Set<Enum.KeyCode>([Enum.KeyCode.Up, Enum.KeyCode.DPadUp]);

// ── Main component ──────────────────────────────────────────────────────────────

function QuickFindComponent(props: QuickFindComponentProps): React.Element {
	const [open, setOpen] = React.useState(false);
	const [query, setQuery] = React.useState("");
	const [selected, setSelected] = React.useState(1);
	const boxRef = React.useRef<TextBox>();
	const listRef = React.useRef<ScrollingFrame>();
	const viewport = useViewport();
	const reduced = props.reducedMotion === true || GuiService.ReducedMotionEnabled === true;
	const enabled = props.enabled !== false;
	// panel spring: scale 0.96 -> 1 with a fade, ~0.18s
	const show = useFlipperSpring(open ? 1 : 0, reduced, 520, 34);
	const tick = useFrameClock(open);
	const resultsAt = React.useRef(os.clock());
	const resultsRef = React.useRef<SearchEntry[]>([]);
	const pickRef = React.useRef<() => void>(() => {});

	const close = React.useCallback(() => {
		setOpen(false);
		const box = boxRef.current;
		if (box !== undefined) {
			box.ReleaseFocus();
		}
	}, []);
	const dismiss = React.useCallback(() => {
		close();
		Audio.play("close");
	}, [close]);

	// open requests from anywhere (top bar, overview, keyboard)
	React.useEffect(() => {
		const request = () => {
			if (enabled) {
				setQuery("");
				setSelected(1);
				resultsAt.current = os.clock() + 0.06;
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

	// keyboard + gamepad: Ctrl/Cmd+K opens; Escape/B closes; Up/Down/DPad move; Enter/A picks
	React.useEffect(() => {
		const connection = UserInputService.InputBegan.Connect((input: InputObject) => {
			const kind = input.UserInputType;
			const pad = kind === Enum.UserInputType.Gamepad1;
			if (kind !== Enum.UserInputType.Keyboard && !pad) {
				return;
			}
			const key = input.KeyCode;
			if (!open) {
				if (pad || !enabled || UserInputService.GetFocusedTextBox() !== undefined) {
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
			if (key === Enum.KeyCode.Escape || key === Enum.KeyCode.ButtonB) {
				dismiss();
			} else if (NAV_DOWN.has(key)) {
				Audio.play("tick");
				setSelected((current: number) => math.min(math.max(1, resultsRef.current.size()), current + 1));
			} else if (NAV_UP.has(key)) {
				Audio.play("tick");
				setSelected((current: number) => math.max(1, current - 1));
			} else if (key === Enum.KeyCode.ButtonA) {
				pickRef.current();
			}
		});
		return () => connection.Disconnect();
	}, [open, enabled, dismiss]);

	// focus the search box once open
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

	const results = React.useMemo<Results>(
		() => (open ? search(props.state, query, props.chatUnread) : { sections: [], flat: [], total: 0 }),
		[open, query, props.state, props.chatUnread],
	);
	const sections = results.sections;
	const flat = results.flat;
	resultsRef.current = flat;
	const pickIndex = math.clamp(selected, 1, math.max(1, flat.size()));

	// layout: centered glass panel; full width with 44px rows on phones
	const touch = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
	const phone = viewport.width < 600;
	const rowH = touch || phone ? ROW_H_TOUCH : ROW_H;
	const [rowYs, listHeight] = rowOffsets(sections, rowH);
	const [inset] = GuiService.GetGuiInset();
	const width = phone ? viewport.width - 16 : math.min(640, viewport.width - 48);
	const height = phone ? viewport.height - inset.Y - 24 : math.min(520, viewport.height - inset.Y - 96);
	const rightW = width >= 480 ? 124 : 0;
	const footerH = touch ? 0 : 34;

	// a new set of results staggers in
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
	pickRef.current = () => pick(resultsRef.current[pickIndex - 1]);

	// keep the highlighted row in view while arrowing
	React.useEffect(() => {
		const list = listRef.current;
		const top = rowYs[pickIndex];
		if (list === undefined || !open || top === undefined) {
			return;
		}
		const bottom = top + rowH;
		const view = list.AbsoluteWindowSize.Y;
		if (top - HEADER_H < list.CanvasPosition.Y) {
			list.CanvasPosition = new Vector2(0, math.max(0, top - HEADER_H));
		} else if (bottom > list.CanvasPosition.Y + view) {
			list.CanvasPosition = new Vector2(0, bottom - view);
		}
	}, [pickIndex, open, query]);

	// the highlight glides between rows
	const highlightY = useFlipperSpring(rowYs[pickIndex] ?? 0, reduced, 700, 42);
	const current = flat[pickIndex - 1];
	const accent = current !== undefined ? current.accent : Palette.mango;

	const rows: Record<string, React.Element | undefined> = {
		layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, ROW_GAP),
		}),
	};
	let order = 0;
	let index = 0;
	const cascadeFrom = reduced ? undefined : resultsAt.current;
	for (const [s, section] of ipairs(sections)) {
		order += 1;
		let labelW = 0;
		pcall(() => {
			labelW = TextService.GetTextSize(section.title, 11, Enum.Font.BuilderSansExtraBold, new Vector2(400, 20)).X;
		});
		rows["h" + s] = h(Header, {
			text: section.title,
			labelW,
			layoutOrder: order,
			tick,
			appearAt: cascadeFrom !== undefined ? cascadeFrom + math.min(index, CASCADE_ROWS) * STAGGER : undefined,
		});
		for (const entry of section.entries) {
			order += 1;
			index += 1;
			const rowIndex = index;
			rows[entry.key + "#" + s] = h(Row, {
				entry,
				selected: rowIndex === pickIndex,
				index: rowIndex,
				rightW,
				query,
				layoutOrder: order,
				onPick: pick,
				onHover: setSelected,
				tick,
				rowH,
				appearAt: cascadeFrom !== undefined && rowIndex <= CASCADE_ROWS ? cascadeFrom + rowIndex * STAGGER : undefined,
			});
		}
	}

	const empty = open && flat.size() === 0 && h("frame", {
		Size: new UDim2(1, 0, 0, 160),
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h("frame", {
		Size: UDim2.fromOffset(44, 44),
		Position: new UDim2(0.5, 0, 0, 18),
		AnchorPoint: new Vector2(0.5, 0),
		BackgroundColor3: Palette.panelSoft,
		ZIndex: 504,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }), h("frame", {
		Size: UDim2.fromOffset(22, 22),
		Position: UDim2.fromScale(0.5, 0.5),
		AnchorPoint: new Vector2(0.5, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 505,
	}, h(Icon, { kind: "Search.9", color: Palette.muted, accent: Palette.muted, size: 22, spin: false }))),
	h("textlabel", {
		Size: new UDim2(1, -32, 0, 22),
		Position: UDim2.fromOffset(16, 70),
		BackgroundTransparency: 1,
		Text: `Nothing matches "${query}"`,
		TextSize: 16,
		FontFace: FONT_BOLD,
		TextColor3: Palette.cream,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 504,
	}), h("textlabel", {
		Size: new UDim2(1, -32, 0, 40),
		Position: UDim2.fromOffset(16, 96),
		BackgroundTransparency: 1,
		// kept as two literals (a single long string tripped a compiler bug)
		Text: "Search works on page names, settings, relics, machines and research. Try \"music\", \"vault\" or a relic" + "'s name.",
		TextSize: 13,
		TextWrapped: true,
		FontFace: FONT_MED,
		TextColor3: Palette.muted,
		TextYAlignment: Enum.TextYAlignment.Top,
		ZIndex: 504,
	}));

	const countLabel = query === "" ? "" : `${results.total} found`;
	const fade = (base: number) => show.map((a: number) => 1 - (1 - base) * math.clamp(a, 0, 1));

	return h("frame", {
		Size: UDim2.fromScale(1, 1),
		BackgroundTransparency: 1,
		Visible: show.map((a: number) => a > 0.01),
		ZIndex: 500,
	},
	// dim backdrop; tap outside closes
	h("imagebutton", {
		Size: UDim2.fromScale(1, 1),
		BackgroundColor3: Palette.void,
		BackgroundTransparency: fade(0.45),
		BorderSizePixel: 0,
		AutoButtonColor: false,
		Selectable: false,
		Active: open,
		ZIndex: 500,
		Event: { Activated: dismiss },
	}),
	// the glass panel
	h("canvasgroup", {
		Name: "QuickFind",
		Size: UDim2.fromOffset(width, height),
		Position: phone ? new UDim2(0.5, 0, 0, inset.Y + 12) : new UDim2(0.5, 0, 0.5, inset.Y / 2),
		AnchorPoint: phone ? new Vector2(0.5, 0) : new Vector2(0.5, 0.5),
		BackgroundColor3: Palette.panel,
		BackgroundTransparency: 0.08,
		GroupTransparency: fade(0),
		BorderSizePixel: 0,
		ZIndex: 501,
	}, h("uiscale", { Scale: show.map((a: number) => 0.96 + 0.04 * math.clamp(a, 0, 1)) }),
	h("uicorner", { CornerRadius: new UDim(0, 16) }),
	h("uistroke", { Color: Palette.lineSoft, Transparency: 0.35, Thickness: 1, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
	h("uigradient", {
		Rotation: 90,
		Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.06)]),
		Color: new ColorSequence(Palette.panelRaised, Palette.panel),
	}),
	// search bar
	h("frame", {
		Size: new UDim2(1, -24, 0, 48),
		Position: UDim2.fromOffset(12, 12),
		BackgroundColor3: Palette.panelSoft,
		BorderSizePixel: 0,
		ZIndex: 502,
	}, h("uicorner", { CornerRadius: new UDim(0, 12) }),
	h("uistroke", { Color: accent, Thickness: 1, Transparency: 0.55, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
	h("frame", {
		Size: UDim2.fromOffset(20, 20),
		Position: new UDim2(0, 14, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h(Icon, { kind: "Search.9", color: Palette.creamSoft, accent: Palette.mango, size: 20, spin: false })),
	h("textbox", {
		ref: boxRef,
		Size: new UDim2(1, -(44 + 44 + 80), 1, 0),
		Position: UDim2.fromOffset(44, 0),
		BackgroundTransparency: 1,
		Text: query,
		PlaceholderText: "Search pages, settings, relics, machines…",
		PlaceholderColor3: Palette.muted,
		TextColor3: Palette.cream,
		TextSize: 17,
		FontFace: FONT_MED,
		TextXAlignment: Enum.TextXAlignment.Left,
		ClearTextOnFocus: false,
		TextTruncate: Enum.TextTruncate.AtEnd,
		ZIndex: 503,
		Change: {
			Text: (box: TextBox) => {
				if (box.Text !== query) {
					if (box.IsFocused() && box.Text.size() > query.size()) {
						Audio.play("searchType");
					}
					setQuery(box.Text);
					setSelected(1);
				}
			},
		},
		Event: {
			FocusLost: (_box: TextBox, enterPressed: boolean) => {
				if (enterPressed && open) {
					pick(resultsRef.current[pickIndex - 1]);
				}
			},
		},
	}), h("textlabel", {
		Size: UDim2.fromOffset(72, 30),
		Position: new UDim2(1, -48, 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundTransparency: 1,
		Text: countLabel,
		TextSize: 12,
		FontFace: FONT_BOLD,
		TextColor3: Palette.muted,
		TextXAlignment: Enum.TextXAlignment.Right,
		ZIndex: 503,
	}),
	// clear (with text) or close (empty) button, 44px tap target
	h("textbutton", {
		Size: UDim2.fromOffset(40, 40),
		Position: new UDim2(1, -4, 0.5, 0),
		AnchorPoint: new Vector2(1, 0.5),
		BackgroundColor3: Palette.panelRaised,
		BackgroundTransparency: 0.2,
		BorderSizePixel: 0,
		AutoButtonColor: true,
		Text: query !== "" ? "✕" : touch ? "Close" : "Esc",
		TextSize: query !== "" ? 14 : 11,
		FontFace: FONT_BOLD,
		TextColor3: Palette.creamSoft,
		ZIndex: 503,
		Event: {
			Activated: () => {
				if (query !== "") {
					setQuery("");
					setSelected(1);
					const box = boxRef.current;
					if (box !== undefined) {
						box.CaptureFocus();
					}
				} else {
					dismiss();
				}
			},
		},
	}, h("uicorner", { CornerRadius: new UDim(0, 10) }))),
	// results
	h("scrollingframe", {
		ref: listRef,
		Size: new UDim2(1, -16, 1, -(72 + footerH + 6)),
		Position: UDim2.fromOffset(8, 68),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		CanvasSize: UDim2.fromOffset(0, flat.size() === 0 ? 160 : listHeight + 6),
		ScrollBarThickness: 3,
		ScrollBarImageColor3: Palette.muted,
		ScrollingDirection: Enum.ScrollingDirection.Y,
		ZIndex: 502,
	}, flat.size() > 0 && h("frame", {
		// the selection highlight: one plate that glides between rows
		Size: new UDim2(1, -4, 0, rowH),
		Position: highlightY.map((y: number) => UDim2.fromOffset(0, y)),
		BackgroundColor3: theme.darken(accent, 0.72),
		BackgroundTransparency: 0.1,
		BorderSizePixel: 0,
		ZIndex: 502,
	}, h("uicorner", { CornerRadius: new UDim(0, 10) }),
	h("uistroke", { Color: accent, Transparency: 0.55, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
	h("frame", {
		Size: new UDim2(0, 3, 1, -18),
		Position: new UDim2(0, 2, 0.5, 0),
		AnchorPoint: new Vector2(0, 0.5),
		BackgroundColor3: accent,
		BorderSizePixel: 0,
		ZIndex: 503,
	}, h("uicorner", { CornerRadius: new UDim(1, 0) }))),
	h("frame", {
		Size: new UDim2(1, 0, 0, flat.size() === 0 ? 160 : listHeight),
		BackgroundTransparency: 1,
		ZIndex: 504,
	}, rows, empty)),
	// footer key hints
	footerH > 0 && h("frame", {
		Size: new UDim2(1, 0, 0, footerH),
		Position: new UDim2(0, 0, 1, -footerH),
		BackgroundColor3: Palette.panelSoft,
		BackgroundTransparency: 0.4,
		BorderSizePixel: 0,
		ZIndex: 502,
	}, h("frame", {
		Size: new UDim2(1, 0, 0, 1),
		BackgroundColor3: Palette.lineSoft,
		BackgroundTransparency: 0.5,
		BorderSizePixel: 0,
		ZIndex: 503,
	}), h("frame", {
		Size: new UDim2(1, -28, 1, 0),
		Position: UDim2.fromOffset(14, 0),
		BackgroundTransparency: 1,
		ZIndex: 503,
	}, h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 14),
		SortOrder: Enum.SortOrder.LayoutOrder,
	}), h(KeyHint, { keys: "↑ ↓", label: "Move", order: 1 }),
	h(KeyHint, { keys: "Enter", label: "Open", order: 2 }),
	h(KeyHint, { keys: "Esc", label: "Close", order: 3 }),
	!phone && h(KeyHint, { keys: "Ctrl+K", label: "From anywhere", order: 4 })))));
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
