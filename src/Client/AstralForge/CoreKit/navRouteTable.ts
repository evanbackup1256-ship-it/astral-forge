import { MORE_ROUTES, PRIMARY_ROUTES, RouteDef } from "../../../Shared/AstralForge/Shared/NavRoutes";

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

/** Bar tabs: saved pins first (in their order), then filled from MOBILE_TAB_PRIORITY. */
export function mobileTabs(
	available: Record<string, boolean>,
	slots: number,
	page?: string,
	pins?: ReadonlyArray<string>,
): LuaTuple<[string[], boolean]> {
	const tabs = new Array<string>();
	const room = math.max(1, math.floor(slots) - 1);
	for (const list of [pins ?? [], MOBILE_TAB_PRIORITY]) {
		for (const id of list) {
			if (tabs.size() >= room) {
				break;
			}
			if (available[id] && !tabs.includes(id)) {
				tabs.push(id);
			}
		}
	}
	const onBar = page !== undefined && tabs.includes(page);
	return $tuple(tabs, page !== undefined && available[page] === true && !onBar);
}

export function find(pageId: string): RouteDef | undefined {
	return ALL_BY_ID.get(pageId);
}

export function allNavIds(): string[] {
	return [...PRIMARY_ROUTES.map((route) => route.id), ...MORE_ROUTES.map((route) => route.id)];
}
