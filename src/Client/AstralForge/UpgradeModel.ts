// Pure purchasing/read-model logic. Currency stays in OmegaMath at every tier.
import { OmegaMathApi, OmegaValue, truthy } from "./lua";

interface ItemConfig {
	Id: unknown;
	Name: string;
	Description?: string;
	BaseCost: unknown;
	CostScale: unknown;
	MaxLevel: number;
	BaseProduction?: unknown;
	Growth?: number;
	[key: string]: unknown;
}
interface UpgradeEntry {
	config: ItemConfig;
	level: number;
	unlocked?: boolean;
	maxed?: boolean;
	price?: unknown;
	[key: string]: unknown;
}
interface Quote {
	count: number;
	cost: OmegaValue;
	ready: boolean;
}
interface Order {
	Id: unknown;
	Amount: number;
	Cost: OmegaValue;
}

export = (Math: OmegaMathApi) => {
	// a price only depends on the item, its level and how many: boards re-quote every row on each
	// cash tick, so the geometric sums are remembered per item (weak, so old configs fall away)
	const costMemo = new Map<ItemConfig, { size: number; costs: Map<string, OmegaValue> }>();
	const costOf = (item: ItemConfig, level: number, count: number): OmegaValue => {
		let byItem = costMemo.get(item);
		if (byItem === undefined || byItem.size > 256) {
			byItem = { size: 0, costs: new Map() };
			costMemo.set(item, byItem);
		}
		const key = `${level}:${count}`;
		let cost = byItem.costs.get(key);
		if (cost === undefined) {
			cost =
				count > 0
					? Math.GeometricSum(item.BaseCost, item.CostScale, level, count)
					: Math.ScaledCost(item.BaseCost, item.CostScale, level);
			byItem.costs.set(key, cost);
			byItem.size += 1;
		}
		return cost;
	};

	const Model = {
		quote(this: void, entry: UpgradeEntry, amount: number, cash: unknown): Quote {
			const item = entry.config;
			const remaining = math.max(0, item.MaxLevel - entry.level);
			const count =
				amount === 0
					? Math.AffordableCount(item.BaseCost, item.CostScale, entry.level, cash, remaining)
					: math.min(amount, 50, remaining);
			const cost = costOf(item, entry.level, count);
			return {
				count,
				cost,
				ready: entry.unlocked === true && !entry.maxed && count > 0 && Math.Gte(cash, cost),
			};
		},

		returnScore(this: void, entry: UpgradeEntry): number {
			// Marginal raw production from the same level/growth formula as the server.
			// Global and machine-specific bonuses are intentionally excluded from this comparison.
			const item = entry.config;
			const gain = Math.Mul(item.BaseProduction ?? 0, 1 + 2 * (item.Growth ?? 0) * entry.level);
			return Math.Gt(gain, 0) ? Math.Log10(gain) - Math.Log10(entry.price) : -math.huge;
		},

		gainScore(this: void, entry: UpgradeEntry): number {
			const gain = Math.Mul(entry.config.BaseProduction ?? 0, 1 + 2 * (entry.config.Growth ?? 0) * entry.level);
			return Math.Gt(gain, 0) ? Math.Log10(gain) : -math.huge;
		},

		plan(this: void, entries: UpgradeEntry[], amount: number, cash: unknown): LuaTuple<[Order[], unknown]> {
			const quoteOrder = (entry: UpgradeEntry, budget: unknown) => {
				const quote = Model.quote(entry, amount, budget);
				// Explicit numeric amounts have the same 50-level ceiling as the server.
				// This prevents Max's shared-budget quote from promising unaccepted levels.
				if (quote.count > 50) {
					quote.count = 50;
					quote.cost = Math.GeometricSum(entry.config.BaseCost, entry.config.CostScale, entry.level, 50);
				}
				return quote;
			};
			const candidates: UpgradeEntry[] = [];
			for (const entry of entries) {
				if (Model.quote(entry, amount, cash).ready) {
					candidates.push(entry);
				}
			}
			// Bound a click to 24 requests. Max divides the budget rather than exhausting it on row one.
			const orders: Order[] = [];
			let remaining: unknown = cash;
			const limit = math.min(24, candidates.size());
			for (let index = 1; index <= limit; index++) {
				const entry = candidates[index - 1];
				const budget = amount === 0 ? Math.Div(remaining, limit - index + 1) : remaining;
				const quote = quoteOrder(entry, budget);
				if (quote.ready) {
					orders.push({ Id: entry.config.Id, Amount: quote.count, Cost: quote.cost });
					remaining = Math.Max(0, Math.Sub(remaining, quote.cost));
				}
			}
			// A costly first row can fail its share even though it is affordable overall.
			if (orders.size() === 0 && candidates.size() > 0) {
				const quote = quoteOrder(candidates[0], cash);
				orders.push({ Id: candidates[0].config.Id, Amount: quote.count, Cost: quote.cost });
				remaining = Math.Max(0, Math.Sub(cash, quote.cost));
			}
			return $tuple(orders, remaining);
		},

		// `matcher(query, name, description)` swaps in fuzzy matching; plain substring otherwise.
		filter(
			this: void,
			entries: UpgradeEntry[],
			query: string | undefined,
			filter: string,
			amount: number,
			cash: unknown,
			matcher?: (needle: string, name: string, description?: string) => unknown,
		): UpgradeEntry[] {
			const visible: UpgradeEntry[] = [];
			const needle = string.lower(string.match(query ?? "", "^%s*(.-)%s*$")[0] as string);
			for (const entry of entries) {
				const keep =
					filter === "Affordable"
						? Model.quote(entry, amount, cash).ready
						: filter === "Owned"
							? entry.level > 0
							: filter === "Next"
								? !entry.unlocked
								: filter === "Available"
									? entry.unlocked === true && !entry.maxed
									: true;
				let found: unknown = needle === "";
				if (!truthy(found)) {
					if (matcher !== undefined) {
						found = matcher(needle, entry.config.Name, entry.config.Description);
					} else {
						const haystack = string.lower(entry.config.Name + " " + (entry.config.Description ?? ""));
						found = string.find(haystack, needle, 1, true)[0] !== undefined;
					}
				}
				if (keep && truthy(found)) {
					visible.push(entry);
				}
			}
			return visible;
		},
	};
	return Model;
};
