--!strict

local OreMath = {}

type OreConfig = {
	Types: { { Id: string, Name: string, YieldMin: number, YieldMax: number } },
	Upgrades: { {
		Id: string,
		Name: string,
		Description: string,
		Effect: string,
		PerLevel: number,
		MaxLevel: number,
		Cost: { [string]: number },
		Scale: number,
	} },
}

local function whole(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

function OreMath.SanitizeBalances(raw: any, config: OreConfig): { [string]: number }
	local clean = {}
	local source = if type(raw) == "table" then raw else {}
	for _, ore in config.Types do
		clean[ore.Id] = whole(source[ore.Id])
	end
	return clean
end

function OreMath.SanitizeLevels(raw: any, config: OreConfig): { [string]: number }
	local clean = {}
	local source = if type(raw) == "table" then raw else {}
	for _, upgrade in config.Upgrades do
		local level = math.min(whole(source[upgrade.Id]), upgrade.MaxLevel)
		if level > 0 then
			clean[upgrade.Id] = level
		end
	end
	return clean
end

function OreMath.Upgrade(config: OreConfig, id: any)
	if type(id) ~= "string" then
		return nil
	end
	for _, upgrade in config.Upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

function OreMath.Cost(upgrade, level: number): { [string]: number }
	local cost = {}
	local factor = upgrade.Scale ^ math.max(0, level)
	for oreId, base in upgrade.Cost do
		cost[oreId] = math.max(1, math.ceil(base * factor - 1e-9))
	end
	return cost
end

function OreMath.CanAfford(balances: { [string]: number }, cost: { [string]: number }): boolean
	for oreId, amount in cost do
		if (balances[oreId] or 0) < amount then
			return false
		end
	end
	return true
end

function OreMath.Effect(levels: any, effect: string, config: OreConfig): number
	if type(levels) ~= "table" then
		return 0
	end
	local total = 0
	for _, upgrade in config.Upgrades do
		if upgrade.Effect == effect then
			local level = math.min(whole(levels[upgrade.Id]), upgrade.MaxLevel)
			total += level * upgrade.PerLevel
		end
	end
	return total
end

function OreMath.Yield(config: OreConfig, oreId: string, yieldBonus: number, roll: (number, number) -> number): number
	for _, ore in config.Types do
		if ore.Id == oreId then
			local base = roll(ore.YieldMin, ore.YieldMax)
			return math.max(1, math.floor(base * (1 + math.max(0, yieldBonus)) + 0.5))
		end
	end
	return 0
end

function OreMath.Purchase(config: OreConfig, balances: { [string]: number }, levels: { [string]: number }, id: any): (boolean, string)
	local upgrade = OreMath.Upgrade(config, id)
	if upgrade == nil then
		return false, "That foundry upgrade doesn't exist."
	end
	local owned = math.min(whole(levels[upgrade.Id]), upgrade.MaxLevel)
	if owned >= upgrade.MaxLevel then
		return false, `{upgrade.Name} is already at its highest level.`
	end
	local cost = OreMath.Cost(upgrade, owned)
	if not OreMath.CanAfford(balances, cost) then
		return false, `Not enough ore for {upgrade.Name} yet.`
	end
	for oreId, amount in cost do
		balances[oreId] = (balances[oreId] or 0) - amount
	end
	levels[upgrade.Id] = owned + 1
	return true, `{upgrade.Name} is now level {owned + 1}.`
end

function OreMath.PublicState(rawBalances: any, rawLevels: any, config: OreConfig)
	local balances = OreMath.SanitizeBalances(rawBalances, config)
	local levels = OreMath.SanitizeLevels(rawLevels, config)
	local types = {}
	for _, ore in config.Types do
		table.insert(types, { Id = ore.Id, Name = ore.Name, Amount = balances[ore.Id] })
	end
	local upgrades = {}
	for _, upgrade in config.Upgrades do
		local level = levels[upgrade.Id] or 0
		local maxed = level >= upgrade.MaxLevel
		local cost = if maxed then {} else OreMath.Cost(upgrade, level)
		table.insert(upgrades, {
			Id = upgrade.Id,
			Name = upgrade.Name,
			Description = upgrade.Description,
			Effect = upgrade.Effect,
			Level = level,
			MaxLevel = upgrade.MaxLevel,
			Bonus = level * upgrade.PerLevel,
			NextBonus = if maxed then level * upgrade.PerLevel else (level + 1) * upgrade.PerLevel,
			Cost = cost,
			Affordable = not maxed and OreMath.CanAfford(balances, cost),
			Maxed = maxed,
		})
	end
	return { Types = types, Balances = balances, Upgrades = upgrades }
end

return table.freeze(OreMath)
