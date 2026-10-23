// Navigation route ids shared by the client nav and the server (phone tab pins are validated
// against these ids).
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
	{ id: "Wheel", label: "Wheel", eyebrow: "Daily spin", icon: "Wheel.1", accentKey: "mango" },
	{ id: "Bazaar", label: "Black Market", eyebrow: "Stock and supplies", icon: "Shop.2", accentKey: "violet" },
	{ id: "Boosts", label: "Boosts", eyebrow: "Timed multipliers", icon: "Boost.7", accentKey: "pink" },
	{ id: "Worlds", label: "Worlds", eyebrow: "Zones", icon: "World.2", accentKey: "mint" },
	{ id: "Lab", label: "Lab", eyebrow: "Orders", icon: "Lab.2", accentKey: "mint" },
	{ id: "StarGrid", label: "Specializations", eyebrow: "Forge builds", icon: "Forge.4", accentKey: "mango" },
	{ id: "Rebirth", label: "Rebirth", eyebrow: "Reset for cores", icon: "Rebirth.1", accentKey: "pink" },
	{ id: "Ascension", label: "Ascension", eyebrow: "Final rebirth", icon: "Rebirth.4", accentKey: "mango" },
	{ id: "Echoes", label: "Echoes", eyebrow: "Trait journal", icon: "Wave.3", accentKey: "cyan" },
	{ id: "Continuum", label: "Star Foundry", eyebrow: "Tile board", icon: "StarGrid.1", accentKey: "mango" },
	{ id: "ForgePath", label: "Forge Path", eyebrow: "Upgrades", icon: "Forge.5", accentKey: "violet" },
	{ id: "Milestones", label: "Milestones", eyebrow: "Goals", icon: "Milestone.1", accentKey: "mango" },
	{ id: "Story", label: "Story", eyebrow: "Chapters", icon: "Story.1", accentKey: "mint" },
	{ id: "Command", label: "Command", eyebrow: "Expeditions", icon: "Command.2", accentKey: "cyan" },
	{ id: "Convergence", label: "Converge", eyebrow: "Co-op", icon: "Domain.1", accentKey: "mango" },
	{ id: "Guild", label: "Guild", eyebrow: "Hall", icon: "Crew.2", accentKey: "violet" },
	{ id: "Crew", label: "Crew", eyebrow: "Your team", icon: "Crew.3", accentKey: "blue" },
	{ id: "Chat", label: "Chat", eyebrow: "Messages", icon: "Chat.1", accentKey: "mint" },
	{ id: "Mail", label: "Mail", eyebrow: "Inbox", icon: "Mail.1", accentKey: "cyan" },
	{ id: "Trade", label: "Trade", eyebrow: "With players", icon: "Send.1", accentKey: "mint" },
	{ id: "Leaderboards", label: "Ranks", eyebrow: "Top 25", icon: "Leaderboard.1", accentKey: "cyan" },
	{ id: "Credits", label: "Credits", eyebrow: "About", icon: "Credits.1", accentKey: "violet" },
	{ id: "Admin", label: "Admin", eyebrow: "Owner", icon: "Admin.1", accentKey: "coral" },
	{ id: "Season", label: "Season", eyebrow: "Tier track", icon: "Season.1", accentKey: "violet" },
	// ---- v8 C: Expedition Board ----
	{ id: "Expeditions", label: "Expeditions", eyebrow: "Send relics out", icon: "Command.2", accentKey: "cyan" },
	// ---- end v8 C: Expedition Board ----
	{ id: "Companions", label: "Companions", eyebrow: "Followers", icon: "Artifact.3", accentKey: "mint" },
	{ id: "Journal", label: "Journal", eyebrow: "Chapters", icon: "Story.2", accentKey: "mango" },
]);

const NAV_IDS = new Set<string>();
for (const route of PRIMARY_ROUTES) {
	NAV_IDS.add(route.id);
}
for (const route of MORE_ROUTES) {
	NAV_IDS.add(route.id);
}

export const MAX_MOBILE_TAB_PINS = 5;

export function isNavId(id: unknown): id is string {
	return typeIs(id, "string") && NAV_IDS.has(id);
}

/** Ordered phone bottom-bar pins: known nav ids only, no repeats, at most MAX_MOBILE_TAB_PINS. */
export function normalizeMobileTabPins(raw: unknown): string[] {
	const pins = new Array<string>();
	if (!typeIs(raw, "table")) {
		return pins;
	}
	for (const id of raw as unknown[]) {
		if (pins.size() >= MAX_MOBILE_TAB_PINS) {
			break;
		}
		if (isNavId(id) && !pins.includes(id)) {
			pins.push(id);
		}
	}
	return pins;
}

/** Strict wire check: an array of unique known nav ids, at most MAX_MOBILE_TAB_PINS long. */
export function validMobileTabPins(raw: unknown): boolean {
	if (!typeIs(raw, "table")) {
		return false;
	}
	const list = raw as unknown[];
	let count = 0;
	for (const [key] of pairs(list)) {
		if (!typeIs(key, "number")) {
			return false;
		}
		count += 1;
	}
	if (count > MAX_MOBILE_TAB_PINS || count !== list.size()) {
		return false;
	}
	return normalizeMobileTabPins(list).size() === count;
}
