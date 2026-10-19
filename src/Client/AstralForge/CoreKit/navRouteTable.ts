export interface RouteDef {
	id: string;
	label: string;
	eyebrow: string;
	icon: string;
	accentKey: string;
}

export const PRIMARY_ROUTES: ReadonlyArray<RouteDef> = table.freeze([
	{ id: "Overview", label: "Overview", eyebrow: "Your vault", icon: "Overview.1", accentKey: "green" },
	{ id: "Workshop", label: "Workshop", eyebrow: "Buy machines", icon: "Forge.3", accentKey: "coral" },
	{ id: "Inventory", label: "Inventory", eyebrow: "Relics", icon: "Inventory.1", accentKey: "violet" },
	{ id: "Research", label: "Research", eyebrow: "Permanent bonuses", icon: "Research.1", accentKey: "cyan" },
	{ id: "Shop", label: "Shop", eyebrow: "Packs", icon: "Shop.1", accentKey: "mango" },
	{ id: "Settings", label: "Settings", eyebrow: "Options", icon: "Settings.1", accentKey: "violet" },
]);

export const MORE_ROUTES: ReadonlyArray<RouteDef> = table.freeze([
	{ id: "Missions", label: "Missions", eyebrow: "Jobs", icon: "Mission.1", accentKey: "cyan" },
	{ id: "Rewards", label: "Rewards", eyebrow: "Dailies", icon: "Rewards.1", accentKey: "pink" },
	{ id: "Wheel", label: "Wheel", eyebrow: "Spin", icon: "Wheel.1", accentKey: "mango" },
	{ id: "Bazaar", label: "Black Market", eyebrow: "Stock and supplies", icon: "Shop.2", accentKey: "violet" },
	{ id: "Boosts", label: "Boosts", eyebrow: "Power up", icon: "Boost.7", accentKey: "pink" },
	{ id: "Worlds", label: "Worlds", eyebrow: "Zones", icon: "World.2", accentKey: "mint" },
	{ id: "Lab", label: "Lab", eyebrow: "Orders", icon: "Lab.2", accentKey: "mint" },
	{ id: "StarGrid", label: "Specializations", eyebrow: "Forge builds", icon: "Forge.4", accentKey: "mango" },
	{ id: "Ascension", label: "Ascension", eyebrow: "Final rebirth", icon: "Rebirth.4", accentKey: "mango" },
	{ id: "Echoes", label: "Echoes", eyebrow: "Keep", icon: "Wave.3", accentKey: "cyan" },
	{ id: "Continuum", label: "Star Foundry", eyebrow: "Board", icon: "StarGrid.1", accentKey: "mango" },
	{ id: "ForgePath", label: "Forge Path", eyebrow: "Upgrades", icon: "Forge.5", accentKey: "violet" },
	{ id: "Milestones", label: "Milestones", eyebrow: "Goals", icon: "Milestone.1", accentKey: "mango" },
	{ id: "Story", label: "Story", eyebrow: "Read", icon: "Story.1", accentKey: "mint" },
	{ id: "Command", label: "Command", eyebrow: "Expeditions", icon: "Command.2", accentKey: "cyan" },
	{ id: "Convergence", label: "Converge", eyebrow: "Co-op", icon: "Domain.1", accentKey: "mango" },
	{ id: "Guild", label: "Guild", eyebrow: "Hall", icon: "Crew.2", accentKey: "violet" },
	{ id: "Crew", label: "Crew", eyebrow: "Online", icon: "Crew.3", accentKey: "blue" },
	{ id: "Chat", label: "Chat", eyebrow: "Talk", icon: "Chat.1", accentKey: "mint" },
	{ id: "Mail", label: "Mail", eyebrow: "Inbox", icon: "Mail.1", accentKey: "cyan" },
	{ id: "Trade", label: "Trade", eyebrow: "Swap", icon: "Send.1", accentKey: "mint" },
	{ id: "Leaderboards", label: "Ranks", eyebrow: "Top 25", icon: "Leaderboard.1", accentKey: "cyan" },
	{ id: "Credits", label: "Credits", eyebrow: "About", icon: "Credits.1", accentKey: "violet" },
	{ id: "Admin", label: "Admin", eyebrow: "Owner", icon: "Admin.1", accentKey: "coral" },
]);

// prettier-ignore
export const PAGE_ROUTES: ReadonlyArray<string> = table.freeze([
	"Overview", "Workshop", "Research", "StarGrid", "Ascension", "Echoes", "Continuum", "Convergence",
	"Lab", "Anomaly", "Worlds", "Missions", "Milestones", "Wheel", "Bazaar", "Rewards", "Boosts",
	"Command", "Story", "Mail", "Chat", "Crew", "Guild", "Leaderboards", "Shop", "Inventory", "Trade",
	"Settings", "Admin", "ForgePath",
]);

export interface NavGroup {
	key: string;
	label: string;
	routes: ReadonlyArray<string>;
}

export const NAV_GROUPS: ReadonlyArray<NavGroup> = table.freeze([
	{ key: "Home", label: "Home", routes: table.freeze(["Overview", "Workshop", "Inventory", "Research", "Shop", "Bazaar"]) },
	{ key: "Daily", label: "Daily", routes: table.freeze(["Missions", "Rewards", "Boosts", "Milestones", "Wheel"]) },
	{
		key: "Progress",
		label: "Progress",
		routes: table.freeze(["Worlds", "Lab", "StarGrid", "Echoes", "Continuum", "ForgePath", "Story", "Ascension"]),
	},
	{ key: "Social", label: "Social", routes: table.freeze(["Command", "Convergence", "Guild", "Crew", "Chat", "Mail", "Trade", "Leaderboards"]) },
	{ key: "System", label: "System", routes: table.freeze(["Settings", "Credits", "Admin"]) },
]);
for (const group of NAV_GROUPS) {
	table.freeze(group);
}

const GROUP_OF = new Map<string, string>();
for (const group of NAV_GROUPS) {
	for (const id of group.routes) {
		GROUP_OF.set(id, group.key);
	}
}

const ALL_BY_ID = new Map<string, RouteDef>();
for (const route of PRIMARY_ROUTES) {
	ALL_BY_ID.set(route.id, route);
}
for (const route of MORE_ROUTES) {
	ALL_BY_ID.set(route.id, route);
}
const continuum = ALL_BY_ID.get("Continuum");
if (continuum !== undefined && !ALL_BY_ID.has("Foundry")) {
	ALL_BY_ID.set("Foundry", continuum);
}

const PAGE_SET = new Set(PAGE_ROUTES);

export function groupOf(pageId: string): string | undefined {
	return GROUP_OF.get(pageId);
}

export const MOBILE_TAB_PRIORITY: ReadonlyArray<string> = table.freeze(["Overview", "Workshop", "Research", "Shop", "Inventory", "Missions", "Rewards"]);

export function mobileTabs(available: Record<string, boolean>, slots: number, page?: string): LuaTuple<[string[], boolean]> {
	const tabs = new Array<string>();
	const room = math.max(1, math.floor(slots) - 1);
	for (const id of MOBILE_TAB_PRIORITY) {
		if (tabs.size() >= room) {
			break;
		}
		if (available[id]) {
			tabs.push(id);
		}
	}
	const onBar = page !== undefined && tabs.includes(page);
	return $tuple(tabs, page !== undefined && available[page] === true && !onBar);
}

export function find(pageId: string): RouteDef | undefined {
	return ALL_BY_ID.get(pageId);
}

export function isNavRoute(pageId: string): boolean {
	return ALL_BY_ID.has(pageId);
}

export function isPageRoute(pageId: string): boolean {
	return PAGE_SET.has(pageId);
}

export function allNavIds(): string[] {
	return [...PRIMARY_ROUTES.map((route) => route.id), ...MORE_ROUTES.map((route) => route.id)];
}
