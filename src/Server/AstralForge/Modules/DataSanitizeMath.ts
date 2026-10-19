const DataSanitizeMath = {
	MAX_PERSISTED_NUMBER: 1e308,

	DeepCopy(this: void, value: unknown): unknown {
		if (!typeIs(value, "table")) {
			return value;
		}
		const copy: Record<string, unknown> = {};
		for (const [key, child] of pairs(value as object)) {
			copy[DataSanitizeMath.DeepCopy(key) as string] = DataSanitizeMath.DeepCopy(child);
		}
		return copy;
	},

	Reconcile(this: void, target: unknown, template: unknown): unknown {
		if (!typeIs(target, "table") || !typeIs(template, "table")) {
			return target;
		}
		const targetTable = target as Record<string, unknown>;
		for (const [key, defaultValue] of pairs(template as object)) {
			const currentValue = targetTable[key as string];
			if (typeIs(defaultValue, "table") && typeIs(currentValue, "table")) {
				DataSanitizeMath.Reconcile(currentValue, defaultValue);
			} else if (currentValue === undefined) {
				targetTable[key as string] = DataSanitizeMath.DeepCopy(defaultValue);
			} else if (typeIs(defaultValue, "number") && typeIs(currentValue, "string")) {
				// Economy fields use number|string persistence. Keep the original value
				// for the field-specific sanitizer; tonumber can overflow valid saves.
			} else if (typeOf(defaultValue) !== typeOf(currentValue)) {
				targetTable[key as string] = DataSanitizeMath.DeepCopy(defaultValue);
			}
		}
		return target;
	},

	NonNegative(this: void, value: unknown, ceiling?: number): number {
		const cap = typeIs(ceiling, "number") ? ceiling : DataSanitizeMath.MAX_PERSISTED_NUMBER;
		if (!typeIs(value, "number") || value !== value || value === math.huge || value === -math.huge) {
			return 0;
		}
		return math.clamp(value, 0, cap);
	},

	ScrubNonFinite(this: void, value: unknown, depth?: number, budget?: { nodes: number }): unknown {
		const d = depth ?? 0;
		const counter = budget ?? { nodes: 0 };
		if (counter.nodes > 24000 || d > 18) {
			return value;
		}
		if (typeIs(value, "number")) {
			if (value !== value || value === math.huge || value === -math.huge) {
				return 0;
			}
			return value;
		}
		if (!typeIs(value, "table")) {
			return value;
		}
		const valueTable = value as Record<string, unknown>;
		for (const [key, child] of pairs(value as object)) {
			counter.nodes += 1;
			if (typeIs(child, "number")) {
				if (child !== child || child === math.huge || child === -math.huge) {
					valueTable[key as string] = 0;
				}
			} else if (typeIs(child, "table")) {
				DataSanitizeMath.ScrubNonFinite(child, d + 1, counter);
			}
		}
		return value;
	},

	ClampLevelBag(this: void, bag: unknown, byId: unknown, nonNegative?: (value: unknown) => number): unknown {
		if (!typeIs(bag, "table")) {
			return bag;
		}
		const bagTable = bag as Record<string, unknown>;
		const catalog = (typeIs(byId, "table") ? byId : {}) as Record<string, unknown>;
		let clamp = nonNegative;
		if (!typeIs(clamp, "function")) {
			clamp = (value: unknown): number => DataSanitizeMath.NonNegative(value);
		}
		for (const [key, value] of pairs(bag as object)) {
			const item = catalog[key as string];
			const maxLevel =
				typeIs(item, "table") && tonumber((item as Record<string, unknown>).MaxLevel) !== undefined
					? tonumber((item as Record<string, unknown>).MaxLevel)
					: undefined;
			const nextValue =
				maxLevel !== undefined ? math.clamp(math.floor(clamp(value)), 0, maxLevel) : 0;
			bagTable[key as string] = nextValue > 0 ? nextValue : undefined;
		}
		return bag;
	},

	ClampAutoForge(
		this: void,
		autoForge: unknown,
		machineById: unknown,
		defaultMachineId: unknown,
		nonNegative?: (value: unknown) => number,
	): Record<string, unknown> {
		const catalog = (typeIs(machineById, "table") ? machineById : {}) as Record<string, unknown>;
		const fallback =
			typeIs(defaultMachineId, "string") && catalog[defaultMachineId] !== undefined
				? defaultMachineId
				: "StellarCore";
		let clamp = nonNegative;
		if (!typeIs(clamp, "function")) {
			clamp = (value: unknown): number => DataSanitizeMath.NonNegative(value);
		}
		const bag = (typeIs(autoForge, "table")
			? autoForge
			: {
					Enabled: false,
					MachineId: fallback,
					Reserve: 0.25,
					Bought: 0,
				}) as Record<string, unknown>;
		bag.Enabled = bag.Enabled === true;
		bag.MachineId =
			typeIs(bag.MachineId, "string") && catalog[bag.MachineId] !== undefined
				? bag.MachineId
				: fallback;
		bag.Reserve = math.clamp(clamp(bag.Reserve), 0, 0.9);
		bag.Bought = math.floor(clamp(bag.Bought));
		return bag;
	},
};

export = table.freeze(DataSanitizeMath);
