--!strict
local Catalog = {}
local products = {
	{ "DustPouch", "Dust Pouch", "40 stardust.", 29, { Stardust = 40 } },
	{ "DustCase", "Dust Case", "160 stardust.", 99, { Stardust = 160 } },
	{ "DustShipment", "Dust Shipment", "500 stardust.", 249, { Stardust = 500 } },
	{ "DustFreighter", "Dust Freighter", "1,500 stardust.", 599, { Stardust = 1500 } },
	{ "CorePair", "Core Pair", "2 permanent cores.", 99, { Cores = 2 } },
	{ "CoreCase", "Core Case", "8 permanent cores.", 349, { Cores = 8 } },
	{ "CoreShipment", "Core Shipment", "20 permanent cores.", 799, { Cores = 20 } },
	{ "FluxRefill", "Flux Refill", "10 minutes of current production as banked Flux.", 39, { CashMinutes = 10 } },
	{ "FluxReserve", "Flux Reserve", "30 minutes of current production as banked Flux.", 99, { CashMinutes = 30 } },
	{ "FluxShipment", "Flux Shipment", "90 minutes of current production as banked Flux.", 249, { CashMinutes = 90 } },
	{ "FluxFreighter", "Flux Freighter", "4 hours of current production as banked Flux.", 599, { CashMinutes = 240 } },
	{ "SignalPack", "Signal Pack", "5 expedition signals.", 49, { Signals = 5 } },
	{ "SignalCase", "Signal Case", "20 expedition signals.", 149, { Signals = 20 } },
	{ "SignalShipment", "Signal Shipment", "60 expedition signals.", 349, { Signals = 60 } },
	{ "CommandTraining", "Command Training", "500 Command XP.", 99, { CommandXP = 500 } },
	{ "DockSupply", "Dock Supply", "120 stardust, 3 cores and 10 signals.", 249, { Stardust = 120, Cores = 3, Signals = 10 } },
}
local passes = {
	{ "FurnaceTuning", "Furnace Tuning", 99, 0.05, 0 },
	{ "PrecisionTools", "Precision Tools", 149, 0.08, 0 },
	{ "SolarPanels", "Solar Panels", 249, 0.12, 0 },
	{ "ReactorCooling", "Reactor Cooling", 399, 0.18, 0 },
	{ "StellarDrive", "Stellar Drive", 699, 0.3, 0 },
	{ "VaultShelves", "Vault Shelves", 99, 0, 0.1 },
	{ "DeepStorage", "Deep Storage", 149, 0, 0.18 },
	{ "CargoBay", "Cargo Bay", 249, 0, 0.28 },
	{ "ReserveHangar", "Reserve Hangar", 399, 0, 0.45 },
	{ "FoundersForge", "Founder's Forge", 799, 0.2, 0.3 },
}
function Catalog.Extend(config: any, ids: any)
	for _, row in products do
		table.insert(
			config.DevProducts,
			{
				Key = row[1],
				Name = row[2],
				Description = row[3],
				ProductId = ids.Products[row[1]] or 0,
				Category = "Packs",
				Icon = "Vault",
				Accent = { 72, 190, 255 },
				PriceLabel = "R$",
				StudioPrice = row[4],
				Reward = row[5],
			}
		)
	end
	for _, price in { 5, 10, 25, 50, 100, 500 } do
		local key = "Tip" .. price
		table.insert(
			config.DevProducts,
			{
				Key = key,
				Name = "Tip Jar • " .. price,
				Description = "A tip for the developers. Includes a thank-you animation, with no items or bonuses.",
				ProductId = ids.Products[key] or 0,
				Category = "Donations",
				Icon = "StarGrid",
				Accent = { 255, 191, 78 },
				PriceLabel = "R$",
				StudioPrice = price,
				Reward = {},
				Donation = true,
			}
		)
	end
	for _, row in passes do
		local detail = {}
		if row[4] > 0 then
			table.insert(detail, string.format("+%d%% production", math.floor(row[4] * 100 + 0.5)))
		end
		if row[5] > 0 then
			table.insert(detail, string.format("+%d%% vault capacity", math.floor(row[5] * 100 + 0.5)))
		end
		table.insert(
			config.GamePasses,
			{
				Key = row[1],
				Name = row[2],
				Description = table.concat(detail, " and ") .. " permanently. Adds to your other pass bonuses.",
				PassId = ids.Passes[row[1]] or 0,
				Category = "Passes",
				Icon = "Forge",
				Accent = { 161, 126, 255 },
				PriceLabel = "R$",
				StudioPrice = row[3],
				ProductionBonus = row[4],
				CapacityBonus = row[5],
			}
		)
	end
	-- Existing catalog entries also use the same verified ID map.
	for _, entry in config.DevProducts do
		entry.ProductId = ids.Products[entry.Key] or entry.ProductId
	end
	for _, entry in config.GamePasses do
		entry.PassId = ids.Passes[entry.Key] or entry.PassId
	end
end
function Catalog.RecordDonation(profile: any, spent: any): any
	local previous = if type(profile.Donations) == "table" then profile.Donations else {}
	local function safe(value: any): number
		return if type(value) == "number"
				and value == value
				and value >= 0
				and value < 1e12
			then math.floor(value)
			else 0
	end
	profile.Donations =
		{ Total = math.min(1e12, safe(previous.Total) + safe(spent)), Count = math.min(1e9, safe(previous.Count) + 1) }
	return profile.Donations
end
return table.freeze(Catalog)
