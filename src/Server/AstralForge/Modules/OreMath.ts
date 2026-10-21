import { T } from "../../../Shared/AstralForge/Shared/Locale";
interface OreType {
	Id: string;
	Name: string;
	YieldMin: number;
	YieldMax: number;
}

interface OreUpgrade {
	Id: string;
	Name: string;
	Description: string;
	Effect: string;
	PerLevel: number;
	MaxLevel: number;
	Cost: Record<string, number>;
	Scale: number;
}

interface OreConfig {
	Types: OreType[];
	Upgrades: OreUpgrade[];
}

function whole(value: unknown): number {
	const n = tonumber(value);
	if (n === undefined || n !== n || n === math.huge || n === -math.huge) {
		return 0;
	}
	return math.max(0, math.floor(n));
}

const OreMath = {
	SanitizeBalances(this: void, raw: unknown, config: OreConfig): Record<string, number> {
		const clean: Record<string, number> = {};
		const source = (typeIs(raw, "table") ? raw : {}) as Record<string, unknown>;
		for (const ore of config.Types) {
			clean[ore.Id] = whole(source[ore.Id]);
		}
		return clean;
	},

	SanitizeLevels(this: void, raw: unknown, config: OreConfig): Record<string, number> {
		const clean: Record<string, number> = {};
		const source = (typeIs(raw, "table") ? raw : {}) as Record<string, unknown>;
		for (const upgrade of config.Upgrades) {
			const level = math.min(whole(source[upgrade.Id]), upgrade.MaxLevel);
			if (level > 0) {
				clean[upgrade.Id] = level;
			}
		}
		return clean;
	},

	Upgrade(this: void, config: OreConfig, id: unknown): OreUpgrade | undefined {
		if (!typeIs(id, "string")) {
			return undefined;
		}
		for (const upgrade of config.Upgrades) {
			if (upgrade.Id === id) {
				return upgrade;
			}
		}
		return undefined;
	},

	Cost(this: void, upgrade: OreUpgrade, level: number): Record<string, number> {
		const cost: Record<string, number> = {};
		const factor = upgrade.Scale ** math.max(0, level);
		for (const [oreId, base] of pairs(upgrade.Cost)) {
			cost[oreId] = math.max(1, math.ceil(base * factor - 1e-9));
		}
		return cost;
	},

	CanAfford(this: void, balances: Record<string, number>, cost: Record<string, number>): boolean {
		for (const [oreId, amount] of pairs(cost)) {
			if ((balances[oreId] ?? 0) < amount) {
				return false;
			}
		}
		return true;
	},

	Effect(this: void, levels: unknown, effect: string, config: OreConfig): number {
		if (!typeIs(levels, "table")) {
			return 0;
		}
		const levelBag = levels as Record<string, unknown>;
		let total = 0;
		for (const upgrade of config.Upgrades) {
			if (upgrade.Effect === effect) {
				const level = math.min(whole(levelBag[upgrade.Id]), upgrade.MaxLevel);
				total += level * upgrade.PerLevel;
			}
		}
		return total;
	},

	Yield(
		this: void,
		config: OreConfig,
		oreId: string,
		yieldBonus: number,
		roll: (min: number, max: number) => number,
	): number {
		for (const ore of config.Types) {
			if (ore.Id === oreId) {
				const base = roll(ore.YieldMin, ore.YieldMax);
				return math.max(1, math.floor(base * (1 + math.max(0, yieldBonus)) + 0.5));
			}
		}
		return 0;
	},

	Purchase(
		this: void,
		config: OreConfig,
		balances: Record<string, number>,
		levels: Record<string, number>,
		id: unknown,
	): LuaTuple<[boolean, string]> {
		const upgrade = OreMath.Upgrade(config, id);
		if (upgrade === undefined) {
			return $tuple(false, T("OreMath.ThatFoundryUpgradeDoesnT"));
		}
		const owned = math.min(whole(levels[upgrade.Id]), upgrade.MaxLevel);
		if (owned >= upgrade.MaxLevel) {
			return $tuple(false, `${upgrade.Name} is already at its highest level.`);
		}
		const cost = OreMath.Cost(upgrade, owned);
		if (!OreMath.CanAfford(balances, cost)) {
			return $tuple(false, T("OreMath.NotEnoughOreForS", upgrade.Name));
		}
		for (const [oreId, amount] of pairs(cost)) {
			balances[oreId] = (balances[oreId] ?? 0) - amount;
		}
		levels[upgrade.Id] = owned + 1;
		return $tuple(true, `${upgrade.Name} is now level ${owned + 1}.`);
	},

	PublicState(this: void, rawBalances: unknown, rawLevels: unknown, config: OreConfig) {
		const balances = OreMath.SanitizeBalances(rawBalances, config);
		const levels = OreMath.SanitizeLevels(rawLevels, config);
		const types: { Id: string; Name: string; Amount: number }[] = [];
		for (const ore of config.Types) {
			types.push({ Id: ore.Id, Name: ore.Name, Amount: balances[ore.Id] });
		}
		const upgrades: Record<string, unknown>[] = [];
		for (const upgrade of config.Upgrades) {
			const level = levels[upgrade.Id] ?? 0;
			const maxed = level >= upgrade.MaxLevel;
			const cost: Record<string, number> = maxed ? {} : OreMath.Cost(upgrade, level);
			upgrades.push({
				Id: upgrade.Id,
				Name: upgrade.Name,
				Description: upgrade.Description,
				Effect: upgrade.Effect,
				Level: level,
				MaxLevel: upgrade.MaxLevel,
				Bonus: level * upgrade.PerLevel,
				NextBonus: maxed ? level * upgrade.PerLevel : (level + 1) * upgrade.PerLevel,
				Cost: cost,
				Affordable: !maxed && OreMath.CanAfford(balances, cost),
				Maxed: maxed,
			});
		}
		return { Types: types, Balances: balances, Upgrades: upgrades };
	},
};

export = table.freeze(OreMath);
