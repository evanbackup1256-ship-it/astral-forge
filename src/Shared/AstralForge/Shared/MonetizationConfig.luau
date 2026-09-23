--!strict


export type RewardTable = {
	Cash: number?,
	CashMinutes: number?,
	Stardust: number?,
	Cores: number?,
	Boost: string?,
	Signals: number?,
	CommandXP: number?,
	StreakShield: number?,
	Keys: { [string]: number }?,
}

export type DevProductDef = {
	Key: string,
	ProductId: number,
	Name: string,
	Description: string,
	Category: string,
	Icon: string,
	Accent: { number },
	PriceLabel: string,
	StudioPrice: number,
	Reward: RewardTable,
}

export type GamePassDef = {
	Key: string,
	PassId: number,
	Name: string,
	Description: string,
	Category: string,
	Icon: string,
	Accent: { number },
	PriceLabel: string,
	StudioPrice: number,
	ProductionBonus: number?,
	CapacityBonus: number?,
}

local MonetizationConfig = {
	DevProducts = {
		{
			Key = "StardustParcel",
			ProductId = 0,
			Name = "Stardust Pack",
			Description = "80 stardust for grid upgrades.",
			Category = "Packs",
			Icon = "Dust",
			Accent = { 93, 247, 180 },
			PriceLabel = "R$",
			StudioPrice = 49,
			Reward = { Stardust = 80 },
		},
		{
			Key = "FluxCrate",
			ProductId = 0,
			Name = "Flux Drop",
			Description = "120k flux you can spend right now.",
			Category = "Packs",
			Icon = "Flux",
			Accent = { 72, 190, 255 },
			PriceLabel = "R$",
			StudioPrice = 99,
			Reward = { Cash = 120_000 },
		},
		{
			Key = "RelayBooster",
			ProductId = 0,
			Name = "Overdrive Charge",
			Description = "One Overdrive boost for the Rewards tab.",
			Category = "Boosts",
			Icon = "Forge",
			Accent = { 255, 83, 111 },
			PriceLabel = "R$",
			StudioPrice = 75,
			Reward = { Boost = "Overdrive" },
		},
		{
			Key = "CoreCluster",
			ProductId = 0,
			Name = "Core Bundle",
			Description = "3 permanent cores. No rebirth needed.",
			Category = "Packs",
			Icon = "Core",
			Accent = { 161, 126, 255 },
			PriceLabel = "R$",
			StudioPrice = 199,
			Reward = { Cores = 3 },
		},
	} :: { DevProductDef },

	GamePasses = {
		{
			Key = "VIP",
			PassId = 0,
			Name = "VIP",
			Description = "+12% production forever.",
			Category = "Passes",
			Icon = "StarGrid",
			Accent = { 255, 191, 78 },
			PriceLabel = "R$",
			StudioPrice = 399,
			ProductionBonus = 0.12,
		},
		{
			Key = "DoubleProduction",
			PassId = 0,
			Name = "Overclock",
			Description = "+25% line output forever.",
			Category = "Passes",
			Icon = "Research",
			Accent = { 102, 177, 255 },
			PriceLabel = "R$",
			StudioPrice = 499,
			ProductionBonus = 0.25,
		},
		{
			Key = "DoubleCapacity",
			PassId = 0,
			Name = "Bigger Vault",
			Description = "+35% vault size forever.",
			Category = "Passes",
			Icon = "Vault",
			Accent = { 72, 190, 255 },
			PriceLabel = "R$",
			StudioPrice = 349,
			CapacityBonus = 0.35,
		},
		{
			Key = "AutoSalvage",
			PassId = 0,
			Name = "Relic Recycler",
			Description = "Automatically salvage selected crate rarities. First discoveries stay protected by default.",
			Category = "Passes",
			Icon = "Inventory",
			Accent = { 255, 88, 156 },
			PriceLabel = "R$",
			StudioPrice = 299,
		},
	} :: { GamePassDef },
}

function MonetizationConfig.FindDevProductByProductId(productId: number): DevProductDef?
	if productId <= 0 then
		return nil
	end
	for _, entry in MonetizationConfig.DevProducts do
		if entry.ProductId == productId then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindDevProductByKey(key: string): DevProductDef?
	for _, entry in MonetizationConfig.DevProducts do
		if entry.Key == key then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindPassByPassId(passId: number): GamePassDef?
	if passId <= 0 then
		return nil
	end
	for _, entry in MonetizationConfig.GamePasses do
		if entry.PassId == passId then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindPassByKey(key: string): GamePassDef?
	for _, entry in MonetizationConfig.GamePasses do
		if entry.Key == key then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.PassBonuses(owned: { [string]: boolean }): (number, number)
	local production = 0
	local capacity = 0
	for _, entry in MonetizationConfig.GamePasses do
		if owned[entry.Key] == true then
			production += entry.ProductionBonus or 0
			capacity += entry.CapacityBonus or 0
		end
	end
	return production, capacity
end

return table.freeze(MonetizationConfig)
