--!strict
-- Pure apply/revert for peer trades. No Roblox services — TradeDesk and Lune
-- verify scripts share this so host→guest settle can be tested without Studio.
-- Cross-player atomicity still lives in ServerServices (two AtomicUpdates + revert).

local TradeExchange = {}

local CURRENCIES = { "Cash", "Stardust", "Cores", "Signals", "Essence" }
local BOOST_IDS = {
	"DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush",
	"Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge",
}
local KEY_IDS = { "ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate" }

TradeExchange.CURRENCIES = CURRENCIES
TradeExchange.BOOST_IDS = BOOST_IDS
TradeExchange.KEY_IDS = KEY_IDS

local function utcDay(now: number): number
	local date = os.date("!*t", now)
	return date.year * 1000 + date.yday
end

local function ensureLedger(profile, now: number)
	if type(profile.Trade) ~= "table" then
		profile.Trade = { Day = -1, Completed = 0, Sent = {} }
	end
	local day = utcDay(now)
	if profile.Trade.Day ~= day then
		profile.Trade.Day = day
		profile.Trade.Completed = 0
		profile.Trade.Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 }
	end
	if type(profile.Trade.Sent) ~= "table" then
		profile.Trade.Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 }
	end
end

local function ensureTradeBags(profile)
	profile.Command = type(profile.Command) == "table" and profile.Command or {}
	profile.Items = type(profile.Items) == "table" and profile.Items or { Inventory = {}, Keys = {}, Essence = 0 }
	profile.Items.Inventory = type(profile.Items.Inventory) == "table" and profile.Items.Inventory or {}
	profile.Items.Keys = type(profile.Items.Keys) == "table" and profile.Items.Keys or {}
	profile.BoostInventory = type(profile.BoostInventory) == "table" and profile.BoostInventory or {}
end

local function countInventory(profile): number
	local count = 0
	if profile.Items and type(profile.Items.Inventory) == "table" then
		for _ in profile.Items.Inventory do
			count += 1
		end
	end
	return count
end

local function boostTotal(offer): number
	local total = 0
	for _, id in BOOST_IDS do
		total += offer.Boosts[id]
	end
	return total
end

local function keyTotal(offer): number
	local total = 0
	for _, id in KEY_IDS do
		total += offer.Keys[id]
	end
	return total
end

function TradeExchange.CopyItemInstance(instance)
	if type(instance) ~= "table" then
		return nil
	end
	local copy = {}
	for key, value in instance do
		if type(value) == "table" then
			local nested = {}
			for nestedKey, nestedValue in value do
				nested[nestedKey] = nestedValue
			end
			copy[key] = nested
		else
			copy[key] = value
		end
	end
	return copy
end

function TradeExchange.SnapshotOfferItems(offer, profile)
	local payloads = {}
	local inventory = profile and profile.Items and profile.Items.Inventory
	if type(inventory) ~= "table" then
		return payloads
	end
	for _, uid in offer.ItemIds do
		local instance = inventory[uid]
		if type(instance) == "table" then
			payloads[uid] = TradeExchange.CopyItemInstance(instance)
		end
	end
	return payloads
end

-- Apply one side of a planned exchange. `omegaMath` must expose Add/Sub/Gt.
-- `gameConfig` must expose Items.InventoryLimit. Returns an error string or nil.
function TradeExchange.ApplyExchange(gameConfig, omegaMath, profile, give, take, giveItems, takeItems, now: number, validateOffer): string?
	ensureLedger(profile, now)
	ensureTradeBags(profile)
	if validateOffer then
		local reason = validateOffer(profile, give, now)
		if reason then
			return reason
		end
	end
	local incomingCount = 0
	if type(take) == "table" and type(take.ItemIds) == "table" then
		incomingCount = #take.ItemIds
	end
	if countInventory(profile) - #give.ItemIds + incomingCount > gameConfig.Items.InventoryLimit then
		return "Inventory cannot hold those relics."
	end

	profile.Cash = omegaMath.Sub(profile.Cash, give.Cash)
	profile.Cash = omegaMath.Add(profile.Cash, take.Cash)
	profile.Stardust = math.max(0, (tonumber(profile.Stardust) or 0) - give.Stardust) + take.Stardust
	profile.Cores = math.max(0, (tonumber(profile.Cores) or 0) - give.Cores) + take.Cores
	profile.Command.Signals = math.max(0, (tonumber(profile.Command.Signals) or 0) - give.Signals) + take.Signals
	profile.Items.Essence = math.max(0, (tonumber(profile.Items.Essence) or 0) - give.Essence) + take.Essence

	for _, id in BOOST_IDS do
		local giveAmount = give.Boosts[id]
		local takeAmount = take.Boosts[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.BoostInventory[id] = math.max(0, (tonumber(profile.BoostInventory[id]) or 0) - giveAmount) + takeAmount
		end
	end
	for _, id in KEY_IDS do
		local giveAmount = give.Keys[id]
		local takeAmount = take.Keys[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.Items.Keys[id] = math.max(0, (tonumber(profile.Items.Keys[id]) or 0) - giveAmount) + takeAmount
		end
	end
	for _, uid in give.ItemIds do
		profile.Items.Inventory[uid] = nil
	end
	if type(take.ItemIds) == "table" then
		for _, uid in take.ItemIds do
			local payload = takeItems and takeItems[uid]
			if payload ~= nil then
				profile.Items.Inventory[uid] = TradeExchange.CopyItemInstance(payload)
			end
		end
	end

	profile.Trade.Sent.Cash += give.Cash
	profile.Trade.Sent.Stardust += give.Stardust
	profile.Trade.Sent.Cores += give.Cores
	profile.Trade.Sent.Signals += give.Signals
	profile.Trade.Sent.Essence += give.Essence
	profile.Trade.Sent.Boost += boostTotal(give)
	profile.Trade.Sent.Keys += keyTotal(give)
	profile.Trade.Sent.Items += #give.ItemIds
	profile.Trade.Completed += 1
	return nil
end

-- Inverse of ApplyExchange. Restores giveItems into inventory. Always mutates;
-- callers must check AtomicUpdate success when wrapping this.
function TradeExchange.RevertExchange(omegaMath, profile, give, take, giveItems, takeItems, now: number)
	ensureLedger(profile, now)
	ensureTradeBags(profile)

	profile.Cash = omegaMath.Add(profile.Cash, give.Cash)
	profile.Cash = omegaMath.Sub(profile.Cash, take.Cash)
	profile.Stardust = math.max(0, (tonumber(profile.Stardust) or 0) + give.Stardust - take.Stardust)
	profile.Cores = math.max(0, (tonumber(profile.Cores) or 0) + give.Cores - take.Cores)
	profile.Command.Signals = math.max(0, (tonumber(profile.Command.Signals) or 0) + give.Signals - take.Signals)
	profile.Items.Essence = math.max(0, (tonumber(profile.Items.Essence) or 0) + give.Essence - take.Essence)

	for _, id in BOOST_IDS do
		local giveAmount = give.Boosts[id]
		local takeAmount = take.Boosts[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.BoostInventory[id] = math.max(0, (tonumber(profile.BoostInventory[id]) or 0) + giveAmount - takeAmount)
		end
	end
	for _, id in KEY_IDS do
		local giveAmount = give.Keys[id]
		local takeAmount = take.Keys[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.Items.Keys[id] = math.max(0, (tonumber(profile.Items.Keys[id]) or 0) + giveAmount - takeAmount)
		end
	end
	if type(take.ItemIds) == "table" then
		for _, uid in take.ItemIds do
			profile.Items.Inventory[uid] = nil
		end
	end
	for _, uid in give.ItemIds do
		local payload = giveItems and giveItems[uid]
		if payload ~= nil then
			profile.Items.Inventory[uid] = TradeExchange.CopyItemInstance(payload)
		end
	end

	profile.Trade.Sent.Cash = math.max(0, (profile.Trade.Sent.Cash or 0) - give.Cash)
	profile.Trade.Sent.Stardust = math.max(0, (profile.Trade.Sent.Stardust or 0) - give.Stardust)
	profile.Trade.Sent.Cores = math.max(0, (profile.Trade.Sent.Cores or 0) - give.Cores)
	profile.Trade.Sent.Signals = math.max(0, (profile.Trade.Sent.Signals or 0) - give.Signals)
	profile.Trade.Sent.Essence = math.max(0, (profile.Trade.Sent.Essence or 0) - give.Essence)
	profile.Trade.Sent.Boost = math.max(0, (profile.Trade.Sent.Boost or 0) - boostTotal(give))
	profile.Trade.Sent.Keys = math.max(0, (profile.Trade.Sent.Keys or 0) - keyTotal(give))
	profile.Trade.Sent.Items = math.max(0, (profile.Trade.Sent.Items or 0) - #give.ItemIds)
	profile.Trade.Completed = math.max(0, (profile.Trade.Completed or 0) - 1)
end

return table.freeze(TradeExchange)
