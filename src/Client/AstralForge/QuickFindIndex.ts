// Quick Find's index and ranking: every page, setting, machine, research, relic, world, boost,
// milestone, story chapter, letter and shop item, scored against what the player typed.
// Pure data in, sections out; the panel in QuickFind.tsx only draws what this returns.
import Model from "./BrowseModel";
import * as theme from "./CoreKit/theme";
import { AppHelpers } from "./CoreKit/appNav";
import * as NavRoutes from "../../Shared/AstralForge/Shared/NavRoutes";
import * as NavRouteTable from "./CoreKit/navRouteTable";
import ReadyBoard from "./ReadyBoard";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

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
export interface KindMetaEntry {
	label: string;
	group: string;
	weight: number;
	accent: string;
	route?: string;
	icon?: string;
}

export interface SearchEntry {
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

export interface Section {
	title: string;
	entries: SearchEntry[];
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
	Items?: {
		Definitions?: {
			Id: string;
			Name: string;
			Description: string;
			Rarity?: string;
			Slot?: string;
		}[];
	};
	Zones?: {
		Id: string | number;
		Name: string;
		Tagline?: string;
		Description?: string;
	}[];
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

export const KIND_META: Record<string, KindMetaEntry> = {
	Action: { label: "Action", group: "ACTIONS", weight: 1.35, accent: "mint" },
	Page: { label: "Page", group: "PAGES", weight: 1.3, accent: "cyan" },
	Setting: {
		label: "Setting",
		group: "SETTINGS",
		weight: 1.05,
		accent: "violet",
	},
	Machine: {
		label: "Machine",
		group: "MACHINES",
		weight: 1,
		accent: "coral",
		route: "Workshop",
		icon: "Forge.23",
	},
	Research: {
		label: "Research",
		group: "RESEARCH",
		weight: 1,
		accent: "cyan",
		route: "Research",
		icon: "Research.4",
	},
	Relic: {
		label: "Relic",
		group: "RELICS",
		weight: 0.95,
		accent: "violet",
		route: "Inventory",
		icon: "Inventory.7",
	},
	World: {
		label: "World",
		group: "WORLDS",
		weight: 0.95,
		accent: "mint",
		route: "Worlds",
		icon: "World.9",
	},
	Boost: {
		label: "Boost",
		group: "BOOSTS",
		weight: 0.95,
		accent: "pink",
		route: "Boosts",
		icon: "Boost.18",
	},
	Milestone: {
		label: "Milestone",
		group: "MILESTONES",
		weight: 0.85,
		accent: "mango",
		route: "Milestones",
		icon: "Milestone.5",
	},
	Story: {
		label: "Story",
		group: "STORY",
		weight: 0.85,
		accent: "mint",
		route: "Story",
		icon: "Story.6",
	},
	Letter: {
		label: "Letter",
		group: "MAIL",
		weight: 0.8,
		accent: "cyan",
		route: "Mail",
		icon: "Mail.5",
	},
	Section: {
		label: "Shop",
		group: "SHOP",
		weight: 1.15,
		accent: "mango",
		route: "Shop",
		icon: "Shop.14",
	},
	Deal: {
		label: "Black Market",
		group: "BLACK MARKET",
		weight: 1.1,
		accent: "violet",
		route: "Bazaar",
		icon: "Shop.15",
	},
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
	return (
		typeIs(entry, "table") &&
		typeIs((entry as { Name?: unknown }).Name, "string") &&
		!tostring((entry as { Id?: unknown }).Id ?? "").find("^Horizon")[0]
	);
}

// ── Static content index ────────────────────────────────────────────────────────

let staticIndex: SearchEntry[] | undefined;
function buildStatic(): SearchEntry[] {
	if (staticIndex !== undefined) {
		return staticIndex;
	}
	loadData();
	const list: SearchEntry[] = [];

	function add(
		kind: string,
		key: string,
		title: string,
		subtitle: string | undefined,
		extra: string | undefined,
		icon?: string,
		link?: LinkInfo,
	): void {
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
		add("Setting", entry.key, entry.label, entry.help, (section !== undefined ? section.label : "") + " settings", "Settings", {
			route: "Settings",
			query: entry.label,
		});
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
			add(
				"Relic",
				relic.Id,
				relic.Name,
				`${relic.Rarity ?? ""} · ${relic.Description ?? ""}`,
				`relic ${relic.Slot ?? ""} ${relic.Rarity ?? ""}`,
			);
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
		{
			id: "Daily",
			title: "Daily shop",
			body: "Daily offers",
			words: "deals daily offers rotation",
			icon: "Calendar.4",
		},
		{
			id: "Crates",
			title: "Crates",
			body: "Crates",
			words: "keys open loot boxes",
			icon: "Crate.13",
		},
		{
			id: "Skins",
			title: "Crate skins",
			body: "Crate skins",
			words: "cosmetics skins looks",
			icon: "Crate.14",
		},
		{
			id: "Codex",
			title: "Relic codex",
			body: "Relics",
			words: "collection codex fuse stars relics",
			icon: "Artifact.8",
		},
		{
			id: "Premium",
			title: "Premium shop",
			body: "Packs and codes",
			words: "robux gamepass passes packs codes redeem",
			icon: "Shop.16",
		},
	]) {
		add("Section", section.id, section.title, section.body, section.words, section.icon, {
			route: "Shop",
			query: "",
			category: section.id,
		});
	}

	for (const deal of [
		{
			id: "Resources",
			title: "Market resources",
			body: "Currencies",
			words: "materials supplies stock",
			icon: "Dust.12",
		},
		{
			id: "Keys",
			title: "Market keys",
			body: "Keys",
			words: "keys crates shipment",
			icon: "Crate.15",
		},
		{
			id: "Boosts",
			title: "Market boosts",
			body: "Cells",
			words: "boosts power overdrive",
			icon: "Boost.19",
		},
		{
			id: "Command",
			title: "Command supplies",
			body: "Signals",
			words: "command experience signals crew",
			icon: "Mission.8",
		},
	]) {
		add("Deal", deal.id, deal.title, deal.body, deal.words, deal.icon, {
			route: "Bazaar",
			query: "",
			category: deal.id,
		});
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
	for (const group of NavRouteTable.NAV_GROUPS as unknown as NavGroup[]) {
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
			return AppHelpers.navBadge(
				route as unknown as Parameters<typeof AppHelpers.navBadge>[0],
				state as unknown as Parameters<typeof AppHelpers.navBadge>[1],
				chatUnread ?? 0,
			);
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

export const MAX_RESULTS = 40;

export interface Results {
	sections: Section[];
	flat: SearchEntry[];
	total: number;
}

export function search(state: Record<string, unknown>, query: string, chatUnread: number | undefined): Results {
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
			for (const entry of ready as Array<{
				route: string;
				label: string;
				detail: string;
				icon: string;
				accent: Color3;
				count: number;
			}>) {
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
				sections.push({ title: "Ready now", entries: items });
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
			if ((a.badge ?? 0) > 0 !== (b.badge ?? 0) > 0) {
				return (a.badge ?? 0) > 0;
			}
			return (a.order ?? 0) < (b.order ?? 0);
		});
		sections.push({ title: "JUMP TO", entries: pages });
	} else {
		const scored: Array<{ entry: SearchEntry; score: number }> = [];
		// things you picked this session rank a little higher, newest most; an exact title wins outright
		const recentKeys = Model.recent();
		const plain = query.lower().gsub("^%s+", "")[0].gsub("%s+$", "")[0];
		const lift = (entry: SearchEntry) => {
			const at = recentKeys.indexOf(entry.key);
			const recentLift = at === -1 ? 1 : 1.25 - at * 0.03;
			const exact = entry.title.lower() === plain ? 1.6 : 1;
			return recentLift * exact;
		};
		const consider = (entry: SearchEntry) => {
			const value = Model.score(tokens, entry.fields);
			if (value > 0) {
				scored.push({
					entry,
					score: value * KIND_META[entry.kind].weight * (entry.locked ? 0.6 : 1) * lift(entry),
				});
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
