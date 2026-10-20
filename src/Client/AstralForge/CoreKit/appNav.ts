import { truthy } from "../lua";
import { Flux, gteFlux, scaledCost } from "./format";
import * as NavRouteTable from "./navRouteTable";
import * as NavRoutes from "../../../Shared/AstralForge/Shared/NavRoutes";
import { Palette } from "./theme";

export interface NavEntry {
	id: string;
	label: string;
	eyebrow: string;
	icon: string;
	accent: Color3;
	disabled?: boolean;
}

function withAccent(route: NavRoutes.RouteDef): NavEntry {
	return {
		id: route.id,
		label: route.label,
		eyebrow: route.eyebrow,
		icon: route.icon,
		accent: Palette[route.accentKey] ?? Palette.green,
	};
}

export const PRIMARY_NAV = NavRoutes.PRIMARY_ROUTES.map(withAccent);
export const MORE_NAV = NavRoutes.MORE_ROUTES.map(withAccent);
export const NAV = [...PRIMARY_NAV, ...MORE_NAV];
export const NAV_GROUPS = NavRouteTable.NAV_GROUPS;
export const navGroupOf = NavRouteTable.groupOf;

const PASSIVE_REQUESTS = ["SyncShop", "MeasureLatency", "ReportClientIntegrity", "ReportPerformance"];
const SIGNATURE_FIELDS = ["Id", "Key", "Index", "Code", "Channel", "Target", "Uid", "ChoiceId", "Slot", "Tier", "Level", "Role", "UserId", "MachineId"];

// the parts of the session snapshot the nav reads
export interface NavState {
	FeatureUnlocks?: Record<string, { Unlocked?: boolean } | undefined>;
	Flags?: { TutorialDone?: boolean; MobileTabPins?: unknown };
	Admin?: { Access?: boolean };
	Trade?: { Invite?: unknown };
	Items?: { Keys?: Record<string, unknown> };
	Mailbox?: { Unread?: number };
	ForgeEchoes?: { Ready?: boolean; Draft?: unknown[] };
	Convergence?: { Tiers?: Array<{ CanClaim?: boolean }> };
	Story?: Array<{ Unlocked?: boolean; Read?: boolean; Claimed?: boolean }>;
	Command?: {
		ClaimableCommanderLevels: unknown[];
		Weekly: Array<{ Claimed?: boolean; Progress: number; Target: number }>;
		ActiveExpedition?: { Id: string; EndsAt: number };
	};
	Zone?: unknown;
	Rebirths?: unknown;
	Cash?: Flux;
}

export interface UpgradeConfig {
	Id: string;
	Name: string;
	BaseCost: number;
	CostScale: number;
	MaxLevel: number;
	RequiredZone?: number;
	RequiredRebirths?: number;
	PreviousId?: string;
	PreviousLevel?: number;
	[key: string]: unknown;
}

export interface UpgradeEntry<C extends UpgradeConfig = UpgradeConfig> {
	config: C;
	level: number;
	price: Flux;
	maxed: boolean;
	unlocked: boolean;
	lockReason: string;
	lockShort: string;
	affordable: boolean;
	order: number;
}

export const AppHelpers = {
	isPassiveRequest(action: string): boolean {
		return action.sub(1, 3) === "Get" || PASSIVE_REQUESTS.includes(action);
	},
	actionSignature(action: string, value: Record<string, unknown>): string {
		const parts = SIGNATURE_FIELDS.filter((f) => value[f] !== undefined).map((f) => `${f}=${tostring(value[f])}`);
		return `${action}:${parts.join("|")}`;
	},
	pageAccent(page: string): Color3 {
		const entry = NAV.find((e) => e.id === page);
		return entry ? entry.accent : Palette.green;
	},
	pageEntry(page: string): NavEntry {
		return NAV.find((e) => e.id === page) ?? NAV[0];
	},
	boostEffectText(boost: { Multiplier?: number; CapacityMultiplier?: number }): string {
		if (boost.Multiplier !== undefined && boost.CapacityMultiplier !== undefined) {
			return `${boost.Multiplier}x output + ${boost.CapacityMultiplier}x vault`;
		}
		if (boost.Multiplier !== undefined) {
			return `${boost.Multiplier}x output`;
		}
		if (boost.CapacityMultiplier !== undefined) {
			return `${boost.CapacityMultiplier}x vault capacity`;
		}
		return "Temporary production perk";
	},
	featureUnlocked(state: NavState, featureId: string): boolean {
		return state.FeatureUnlocks?.[featureId]?.Unlocked !== false;
	},
	navUnlocked(state: NavState, pageId: string, tutorialPage?: string): boolean {
		if (pageId === "Trade") {
			return true;
		}
		const entry = AppHelpers.pageEntry(pageId);
		if (entry.disabled) {
			return false;
		}
		const unlocked = state.FeatureUnlocks?.[pageId]?.Unlocked !== false;
		const tutorialOverride = state.Flags?.TutorialDone !== true && tutorialPage === pageId;
		return unlocked || tutorialOverride;
	},
	filterNav(entries: ReadonlyArray<NavEntry>, state: NavState, tutorialPage?: string): NavEntry[] {
		const visible = new Array<NavEntry>();
		const seen = new Set<string>();
		for (const entry of entries) {
			const id = entry.id;
			if (seen.has(id)) {
				continue;
			}
			if (id === "Admin" && state.Admin?.Access !== true) {
				continue;
			}
			const lock = state.FeatureUnlocks?.[id];
			const tutorialOverride = state.Flags?.TutorialDone !== true && tutorialPage === id;
			const unlocked = id === "Trade" || lock?.Unlocked !== false || tutorialOverride;
			if (unlocked) {
				seen.add(id);
				visible.push(entry);
			}
		}
		return visible;
	},
	visibleNav(state: NavState, tutorialPage?: string): NavEntry[] {
		return AppHelpers.filterNav([...PRIMARY_NAV, ...MORE_NAV], state, tutorialPage);
	},
	navBadge(entry: NavEntry, state: NavState, chatUnread: number): number {
		const id = entry.id;
		if (id === "Trade") {
			return truthy(state.Trade?.Invite) ? 1 : 0;
		}
		if (id === "Inventory") {
			const keys = state.Items?.Keys;
			if (!keys) {
				return 0;
			}
			let count = 0;
			for (const [, value] of pairs(keys)) {
				if (typeIs(value, "number") && value > 0) {
					count += 1;
				}
			}
			return count;
		}
		if (id === "Chat") {
			return chatUnread;
		}
		if (id === "Mail") {
			return state.Mailbox?.Unread ?? 0;
		}
		if (id === "Echoes") {
			const echoes = state.ForgeEchoes;
			if (echoes?.Ready === true) {
				return 1;
			}
			const choiceCount = echoes?.Draft?.size() ?? 0;
			return choiceCount > 0 ? 1 : 0;
		}
		if (id === "Convergence") {
			let count = 0;
			for (const tier of state.Convergence?.Tiers ?? []) {
				if (tier.CanClaim) {
					count += 1;
				}
			}
			return count;
		}
		if (id === "Story") {
			let claimable = 0;
			let unreadTeaser = 0;
			for (const chapter of state.Story ?? []) {
				if (!chapter.Unlocked) {
					continue;
				}
				if (chapter.Read && !chapter.Claimed) {
					claimable += 1;
				} else if (!chapter.Read && unreadTeaser === 0) {
					unreadTeaser = 1;
				}
			}
			return claimable + unreadTeaser;
		}
		if (id === "Command") {
			const cmd = state.Command;
			if (!cmd) {
				return 0;
			}
			let count = cmd.ClaimableCommanderLevels.size() > 0 ? 1 : 0;
			for (const directive of cmd.Weekly) {
				if (!directive.Claimed && directive.Progress >= directive.Target) {
					count += 1;
				}
			}
			const expedition = cmd.ActiveExpedition;
			if (expedition && expedition.Id !== "" && game.GetService("Workspace").GetServerTimeNow() >= expedition.EndsAt) {
				count += 1;
			}
			return count;
		}
		return 0;
	},
	worldWindow: {
		chunk: 5,
		maxMounted: 15,
	},
	formatWorldMultiplier(value: number): string {
		const rounded = math.floor(value * 100 + 0.5) / 100;
		if (rounded % 1 === 0) {
			return tostring(math.floor(rounded));
		}
		if ((rounded * 10) % 1 === 0) {
			return "%.1f".format(rounded);
		}
		return "%.2f".format(rounded);
	},
	worldWindowAround(currentIdx: number, total: number, count = 5): { start: number; count: number } {
		if (total <= 0) {
			return { start: 0, count: 0 };
		}
		const size = math.clamp(count, 1, math.min(total, 15));
		const start = math.clamp(currentIdx - math.floor((size - 1) / 2), 0, math.max(0, total - size));
		return { start, count: size };
	},
	trimFarLockedUpgrades<E extends { unlocked: boolean; level: number }>(entries: ReadonlyArray<E>): E[] {
		const out = new Array<E>();
		let lockedShown = 0;
		for (const entry of entries) {
			if (entry.unlocked || entry.level > 0) {
				out.push(entry);
			} else if (lockedShown < 12) {
				out.push(entry);
				lockedShown += 1;
			}
		}
		return out;
	},
	buildUpgradeEntries<C extends UpgradeConfig>(
		configs: ReadonlyArray<C>,
		levels: Record<string, number | undefined>,
		state: NavState,
		_buyAmount?: number,
		limit?: number,
	): UpgradeEntry<C>[] {
		const names = new Map<string, string>();
		for (const item of configs) {
			names.set(item.Id, item.Name);
		}
		const entries = new Array<UpgradeEntry<C>>();
		for (let index = 0; index < configs.size(); index++) {
			if (limit !== undefined && index >= limit) {
				break;
			}
			const item = configs[index];
			const level = levels[item.Id] ?? 0;
			const price = scaledCost(item.BaseCost, item.CostScale, level);
			const maxed = level >= item.MaxLevel;
			let lockReason = "";
			let lockShort = "";
			const requiredZone = item.RequiredZone ?? 1;
			const zone = typeIs(state.Zone, "number") ? state.Zone : 0;
			if (zone < requiredZone) {
				lockReason = `Reach World ${requiredZone}`;
			} else {
				const requiredRebirths = item.RequiredRebirths ?? 0;
				const rebirths = typeIs(state.Rebirths, "number") ? state.Rebirths : 0;
				if (rebirths < requiredRebirths) {
					lockReason = `Complete ${requiredRebirths} rebirth${requiredRebirths === 1 ? "" : "s"}`;
				} else if (item.PreviousId !== undefined) {
					const prevLevel = levels[item.PreviousId] ?? 0;
					const needLevel = item.PreviousLevel ?? 1;
					if (prevLevel < needLevel) {
						const prevName = names.get(item.PreviousId) ?? item.PreviousId;
						lockReason = `Get ${prevName} to level ${needLevel}. You have ${prevLevel}.`;
						lockShort = `Need level ${needLevel}`;
					}
				}
			}
			const unlocked = lockReason === "";
			entries.push({
				config: item,
				level,
				price,
				maxed,
				unlocked,
				lockReason,
				lockShort,
				affordable: unlocked && !maxed && gteFlux(state.Cash as Flux, price),
				order: index,
			});
		}
		return entries;
	},
	reserveId(value: number): "HIGH" | "HALF" | "SAFE" | "NONE" {
		if (value >= 0.625) {
			return "HIGH";
		}
		if (value >= 0.375) {
			return "HALF";
		}
		if (value >= 0.125) {
			return "SAFE";
		}
		return "NONE";
	},
	reserveValue(id: string): number {
		if (id === "HIGH") {
			return 0.75;
		}
		if (id === "HALF") {
			return 0.5;
		}
		if (id === "SAFE") {
			return 0.25;
		}
		return 0;
	},
};
