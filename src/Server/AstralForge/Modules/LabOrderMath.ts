interface OrderDefinition {
	Id: string;
	Kind: string;
	BaseTarget: number;
	PerRebirth?: number;
	ProductionSeconds?: number;
	Reward?: unknown;
}

interface OrderState {
	Id: string;
	Progress: number;
	Target: number;
	Claimed: boolean;
}

interface LabBag {
	Day: number;
	Orders: OrderState[];
	Routing: Record<string, number>;
}

function progressPair(state: unknown): LuaTuple<[number, number]> {
	const bag = state as { Progress?: unknown; Target?: unknown } | undefined;
	const progress = math.max(0, math.floor(tonumber(bag !== undefined ? bag.Progress : undefined) ?? 0));
	const target = math.max(0, math.floor(tonumber(bag !== undefined ? bag.Target : undefined) ?? 0));
	return $tuple(progress, target);
}

const LabOrderMath = {
	CHANNEL_ORDER: ["Production", "Storage", "Tap"],

	Ensure(this: void, lab: unknown, baseCells?: number): LabBag {
		const cells = math.max(3, math.floor(tonumber(baseCells) ?? 12));
		const per = math.max(1, math.floor(cells / 3));
		if (!typeIs(lab, "table")) {
			return {
				Day: -1,
				Orders: [],
				Routing: { Production: per, Storage: per, Tap: per },
			};
		}
		const bag = lab as LabBag;
		if (!typeIs(bag.Orders, "table")) {
			bag.Orders = [];
		}
		if (!typeIs(bag.Routing, "table")) {
			bag.Routing = { Production: per, Storage: per, Tap: per };
		}
		bag.Day = typeIs(bag.Day, "number") ? bag.Day : -1;
		return bag;
	},

	NormalizeRouting(this: void, routing: Record<string, number>, channelOrder: string[], totalCells: number): boolean {
		let changed = false;
		const total = math.max(0, math.floor(tonumber(totalCells) ?? 0));
		let used = 0;
		for (const channelId of channelOrder) {
			let value = routing[channelId];
			if (
				!typeIs(value, "number") ||
				value !== value ||
				value === math.huge ||
				value === -math.huge
			) {
				value = 0;
			}
			const clean = math.clamp(math.floor(value), 0, total);
			if (routing[channelId] !== clean) {
				routing[channelId] = clean;
				changed = true;
			}
			used += clean;
		}
		if (used > total) {
			let overflow = used - total;
			for (let index = channelOrder.size(); index >= 1; index--) {
				const channelId = channelOrder[index - 1];
				const current = routing[channelId] ?? 0;
				const removed = math.min(current, overflow);
				if (removed > 0) {
					routing[channelId] = current - removed;
					overflow -= removed;
					changed = true;
				}
				if (overflow <= 0) {
					break;
				}
			}
		}
		return changed;
	},

	TotalCells(this: void, rebirths: number, baseCells: number, rebirthsPerCell: number, maxCells: number): number {
		const safeRebirths = math.max(0, math.floor(tonumber(rebirths) ?? 0));
		const per = math.max(1, math.floor(tonumber(rebirthsPerCell) ?? 1));
		return math.clamp(baseCells + math.floor(safeRebirths / per), baseCells, maxCells);
	},

	OrderTarget(this: void, order: OrderDefinition, rebirths: number, bankFluxTarget?: number): number {
		if (order.Kind === "BankFlux") {
			return math.max(order.BaseTarget, math.floor(tonumber(bankFluxTarget) ?? 0));
		}
		const per = tonumber(order.PerRebirth) ?? 0;
		return math.max(1, math.floor(order.BaseTarget + math.max(0, rebirths) * per));
	},

	IsReady(this: void, state: OrderState): boolean {
		if (!typeIs(state, "table") || state.Claimed === true) {
			return false;
		}
		const [progress, target] = progressPair(state);
		return progress >= target && target > 0;
	},

	CountReady(this: void, orders: OrderState[]): number {
		let ready = 0;
		for (const state of orders) {
			if (LabOrderMath.IsReady(state)) {
				ready += 1;
			}
		}
		return ready;
	},

	ApplyProgress(
		this: void,
		orders: OrderState[],
		orderById: Record<string, OrderDefinition>,
		kind: string,
		amount: number,
	): boolean {
		const gain = math.max(0, math.floor(tonumber(amount) ?? 0));
		if (gain !== gain || gain === math.huge || gain === -math.huge) {
			return false;
		}
		if (gain <= 0) {
			return false;
		}
		let changed = false;
		for (const state of orders) {
			const definition = orderById[state.Id];
			if (definition && definition.Kind === kind && !state.Claimed) {
				const [progress, target] = progressPair(state);
				if (progress < target) {
					state.Progress = math.min(target, progress + gain);
					changed = true;
				}
			}
		}
		return changed;
	},

	TryClaim(
		this: void,
		orders: OrderState[],
		orderById: Record<string, OrderDefinition>,
		orderId: string,
	): LuaTuple<[boolean, string, unknown]> {
		const definition = orderById[orderId];
		if (!definition) {
			return $tuple(false, "That order is no longer on the board.", undefined);
		}
		for (const state of orders) {
			if (state.Id === orderId) {
				if (state.Claimed) {
					return $tuple(false, "That order has already been paid.", undefined);
				}
				const [progress, target] = progressPair(state);
				if (progress < target) {
					return $tuple(false, "That order is not finished yet.", undefined);
				}
				state.Claimed = true;
				state.Progress = progress;
				state.Target = math.max(1, target);
				return $tuple(true, "Order paid.", definition.Reward);
			}
		}
		return $tuple(false, "That order is no longer on the board.", undefined);
	},
};

export = table.freeze(LabOrderMath);
