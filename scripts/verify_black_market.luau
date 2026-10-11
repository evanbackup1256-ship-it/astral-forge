local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Math = require("../src/Server/AstralForge/Modules/BazaarMath")
local Omega = require("../src/Shared/AstralForge/Shared/OmegaMath")
local SharedData = require("../src/Shared/AstralForge/Shared/SharedData")
local AtomicState = require("../src/Server/AstralForge/Services/SecurityServices")("AtomicState")()
local serde = require("@lune/serde")
local Economy = table.clone(Omega)
Economy.SteadyProduction = function(profile) return profile.Production or 1 end
local environment = setmetatable({
	Color3 = roblox.Color3,
	script = { Parent = { SharedData = SharedData } },
	require = function(module) return module end,
}, { __index = _G })
environment.script.Parent.WaitForChild = function(parent, name) return assert(parent[name], name) end
environment.script.Parent.CrateExpansion = luau.load(fs.readFile("src/Shared/AstralForge/Shared/CrateExpansion.luau"), { environment = environment })()
environment.script.Parent.GameConfigGenerated = luau.load(fs.readFile("src/Shared/AstralForge/Shared/GameConfigGenerated.luau"), { environment = environment })()
local config = luau.load(fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau"), { environment = environment })()
local progression = {}
environment.ProgressionService = progression
environment.GameConfig = config
environment.Economy = Economy
environment.Format = { Number = tostring }
environment.ensureCommand = function(profile)
	profile.Command = profile.Command or { Signals = 0, StreakShields = 0, XP = 0 }
	return profile.Command
end
environment.awardCommandXP = function(profile, amount) environment.ensureCommand(profile).XP += amount end
environment.ensureWheel = function(profile) profile.Wheel = profile.Wheel or { FreeSpins = 0 }; return profile.Wheel end
environment.ensureItemKeys = function(profile) profile.Items = profile.Items or { Keys = {} }; return profile.Items.Keys end
environment.ProfileBagMath = {
	EnsureDomain = function(profile) profile.Domain = profile.Domain or { Essence = 0 }; return profile.Domain end,
	EnsureBoostInventory = function(profile) profile.BoostInventory = profile.BoostInventory or {}; return profile.BoostInventory end,
}
local source = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau")
local first = assert(source:find("function ProgressionService.ApplyReward", 1, true))
local last = assert(source:find("function ProgressionService.EnsureQuests", first, true))
luau.load(source:sub(first, last - 1), { environment = environment })()
local deferred, warnings = {}, {}
local legacy = { SavedAt = 100, Pending = { ["42"] = 75 } }
local snapshot = { GetValue = function() return nil end, UpdateAvailable = { Connect = function() end } }
local modules = {
	EconomyMath = function() return Economy end, BazaarMath = Math,
	StoreAccess = { data = function() return { GetAsync = function() return legacy end } end },
}
local parent = { Modules = modules, ModuleLog = { Warn = function(_, message) table.insert(warnings, message) end } }
local serviceEnvironment = setmetatable({
	script = { Parent = { Parent = parent } },
	require = function(module) return module end,
	game = { GetService = function(_, name) assert(name == "ConfigService"); return { GetConfigAsync = function() return snapshot end } end },
	task = { defer = function(callback) table.insert(deferred, callback) end, wait = function() end },
}, { __index = _G })
local service = luau.load(fs.readFile("src/Server/AstralForge/Services/BazaarService.luau"), { environment = serviceEnvironment })()(function(name)
	assert(name == "ProgressionService"); return progression
end)
for _, callback in deferred do callback() end
assert(#warnings == 0)
local function equal(a, b) assert(Omega.Gte(a, b) and Omega.Gte(b, a), tostring(a) .. " ~= " .. tostring(b)) end
local sequence = 0
local function order(offer, now, quantity)
	sequence += 1
	return { Game = "Market", Pick = offer.Id, Bucket = Math.MarketBucket(now), Quantity = quantity or 1,
		UnitPrice = offer.Price, Currency = "Flux", RequestId = string.format("order-%08d", sequence),
		Rotation = `{Math.MarketBucket(now)}:{Math.MARKET_OFFERS}` }
end

assert(#Math.CATALOG == 36 and #service.State({ Cash = 0 }, 3600, 1).Market.Offers == 24)
for bucket = 0, 8 do
	local profile = { Cash = 1e14, Production = 10 }
	local state = service.State(profile, bucket * 3600, 1)
	for _, offer in state.Market.Offers do
		if offer.Reward.Boost then assert(config.Boosts[offer.Reward.Boost], "boost must exist") end
		if offer.Reward.Keys then
			for key in offer.Reward.Keys do
				local exists = false
				for _, crate in config.Items.Crates do if crate.Id == key then exists = true end end
				assert(exists, "key must open a real crate: " .. key)
			end
		end
		local before = profile.Cash
		local payload = order(offer, bucket * 3600, offer.Stock)
		local ok, message, receipt = service.Play(profile, nil, payload, bucket * 3600, 1)
		assert(ok, message)
		equal(profile.Cash, Omega.Sub(before, Omega.Mul(offer.Price, offer.Stock)))
		assert(receipt.Left == 0)
		local remaining = profile.Cash
		local granted = serde.encode("json", profile)
		assert(service.Play(profile, nil, payload, bucket * 3600, 1), "retry returns the original receipt")
		equal(profile.Cash, remaining)
		assert(serde.encode("json", profile) == granted, "retry must not grant any reward or duplicate history")
		assert(not service.Play(profile, nil, order(offer, bucket * 3600), bucket * 3600, 1), "sold-out order rejected")
		-- A save/rejoin sanitize retains both stock and the idempotency receipt.
		profile.Bazaar = Math.Ensure(profile.Bazaar)
		assert(service.Play(profile, nil, payload, bucket * 3600, 1))
		equal(profile.Cash, remaining)
	end
end
local profile = { Cash = 1e10, Production = 1 }
local offer = service.State(profile, 3600, 1).Market.Offers[1]
for _, change in {
	{ Quantity = 0 }, { Quantity = 1.5 }, { Quantity = 9 }, { Bucket = 0 },
	{ Pick = "not-listed" }, { UnitPrice = 1 }, { Currency = "Stardust" }, { RequestId = "short" },
	{ Game = "Bank" }, { Game = "Lottery" }, { Game = "Contracts" },
	{ UnitPrice = math.huge }, { UnitPrice = -math.huge }, { UnitPrice = 0 / 0 },
	{ UnitPrice = "1e99999999999999999999" }, { UnitPrice = "1e400junk" }, { UnitPrice = "nan" },
	{ UnitPrice = "inf" }, { UnitPrice = string.rep("1", 41) }, { Rotation = "1:36" },
} do
	local payload = order(offer, 3600)
	for key, value in change do payload[key] = value end
	local before = profile.Cash
	assert(not service.Play(profile, nil, payload, 3600, 1), "invalid/stale/retired request rejected")
	equal(profile.Cash, before)
end
local low = { Cash = 0 }
assert(not service.Play(low, nil, order(service.State(low, 3600, 1).Market.Offers[1], 3600), 3600, 1))
local huge = { Cash = "1e405", Production = "1e400" }
offer = service.State(huge, 3600, 1).Market.Offers[1]
assert(type(offer.Price) == "string", "large-number quotes must remain serialized")
assert(service.Play(huge, nil, order(offer, 3600, 2), 3600, 1))
assert(type(huge.Cash) == "string" and Omega.Gt(huge.Cash, 0), "large-number charge remains valid")
local legacyProfile = {
	Cash = 1000, Production = 1,
	Bazaar = { Bank = { Balance = 500, Accrued = 20, Since = 3600,
		Term = { Id = "T1", Principal = 100, EndsAt = 7200 } }, Lottery = { PendingPrize = 25 } },
}
service.Roll(legacyProfile, 7200, 42)
equal(legacyProfile.Cash, 1000 + 500 + 20 + 15 + 104 + 25 + 75)
local migrated = legacyProfile.Cash
service.Roll(legacyProfile, 7200, 42)
equal(legacyProfile.Cash, migrated)
legacyProfile.Bazaar = Math.Ensure(legacyProfile.Bazaar)
service.Roll(legacyProfile, 8000, 42)
equal(legacyProfile.Cash, migrated)
assert(legacyProfile.Bazaar.Bank.Balance == 0 and legacyProfile.Bazaar.Bank.Term.Principal == 0)
assert(not service.NeedsRecovery(legacyProfile, 42), "a settled refund must not repeatedly open transactions")
legacy.Pot = 900
legacy.Tickets = { ["42"] = 1, ["99"] = 2 }
local heldTickets = { Cash = 1000, Bazaar = { Market = { RefundedRolloverAt = 100 }, Contracts = { Retired = true } } }
assert(service.NeedsRecovery(heldTickets, 42), "ticket share is separate from an already-refunded pending prize")
assert(service.State(heldTickets, 8000, 42).Market.RecoveryPending, "snapshot must use the holder's actual user ID")
assert(not service.State(heldTickets, 8000, 101).Market.RecoveryPending, "another user's tickets must not become this user's pending claim")
assert(service.Roll(heldTickets, 8000, 42))
equal(heldTickets.Cash, 1300)
heldTickets.Bazaar = Math.Ensure(heldTickets.Bazaar)
assert(service.Roll(heldTickets, 9000, 42))
equal(heldTickets.Cash, 1300)
assert(not service.NeedsRecovery(heldTickets, 42))
assert(not service.State(heldTickets, 9000, 42).Market.RecoveryPending, "settled ticket entitlement leaves no pending notice")
local otherHolder = { Cash = 0, Bazaar = { Contracts = { Retired = true } } }
assert(service.Roll(otherHolder, 8000, 99))
equal(otherHolder.Cash, 600)
equal(Omega.Add(Omega.Sub(heldTickets.Cash, 1000), otherHolder.Cash), legacy.Pot)
legacy.Tickets["invalid"] = 20
legacy.Tickets["100"] = math.huge
legacy.Tickets["101"] = -2
local validHolder = { Cash = 0, Bazaar = { Contracts = { Retired = true } } }
assert(service.Roll(validHolder, 8000, 99))
equal(validHolder.Cash, 600)
legacy.Pot, legacy.Tickets = nil, nil

local contractProfile = { Cash = 1000, Stardust = 0, Production = 2, Bazaar = {
	Market = { RefundedRolloverAt = 100 },
	Contracts = { Day = 5, Baseline = { Deals = 10, Deposits = 10, Tickets = 10, Interest = 10 } },
	Counters = { Deals = 15, Deposits = 15, Tickets = 15, Interest = 15 },
} }
local board = Math.ContractsFor(5, 42)
contractProfile.Bazaar.Contracts.Claimed = { [board[1].Id] = true }
local expectedContract = { Cash = 1000, Stardust = 0, Production = 2 }
for index, contract in board do if index > 1 then progression.ApplyReward(expectedContract, contract.Reward, 2) end end
assert(service.Roll(contractProfile, 50000, 42), "completed last-saved contracts settle even after their day ends")
equal(contractProfile.Cash, expectedContract.Cash)
assert(contractProfile.Stardust == expectedContract.Stardust)
assert((contractProfile.Wheel and contractProfile.Wheel.FreeSpins or 0) == (expectedContract.Wheel and expectedContract.Wheel.FreeSpins or 0))
local contractCash = contractProfile.Cash
contractProfile.Bazaar = Math.Ensure(contractProfile.Bazaar)
assert(contractProfile.Bazaar.Contracts.Retired)
contractProfile.Bazaar.Counters.Deals += 100
assert(service.Roll(contractProfile, 60000, 42))
equal(contractProfile.Cash, contractCash)
assert(not service.NeedsRecovery(contractProfile, 42), "retired contracts cannot start another daily reward loop")

local imprecise = { Cash = "1e405", Bazaar = { Bank = { Balance = 1 } } }
local impreciseAtom = AtomicState.new(imprecise)
local initialEncoded = serde.encode("json", imprecise)
local committed, rejected = impreciseAtom:Transact(function(draft)
	local ok, message = service.Roll(draft, 8000, 101)
	return { ok = ok, error = message }
end)
assert(committed and not rejected.ok and rejected.error:find("still owed", 1, true))
local retained, retainedRevision = impreciseAtom:Read()
assert(retainedRevision == 0 and serde.encode("json", retained) == initialEncoded, "unrepresentable refund retains bank debt and all migration markers")
local partialClaim = { Cash = 1000, Stardust = 1e50, Production = 2, Bazaar = {
	Bank = { Balance = 50 }, Contracts = { Day = 5 },
	Counters = { Deals = 100, Deposits = 100, Tickets = 100, Interest = 100 },
} }
local partialAtom = AtomicState.new(partialClaim)
local successful = partialAtom:Transact(function(draft)
	local ok, message = service.Roll(draft, 8000, 42)
	return { ok = ok, error = message }
end)
assert(not successful, "a failed contract reward aborts the entire retirement transaction")
local failedClaim, failedRevision = partialAtom:Read()
assert(failedClaim == partialClaim and failedRevision == 0 and failedClaim.Bazaar.Bank.Balance == 50,
	"failed earned claim cannot consume bank refund, contract or ticket markers")
print("[TEST] retirement settlement: proportional pot conservation, independent prize/ticket markers, completed/claimed contracts, precision rejection and atomic reward rollback passed")

local rotating = { Cash = 1e12, Production = 1 }
local original = service.State(rotating, 3600, 1).Market.Offers[1]
local originalOrder = order(original, 3600)
assert(service.Play(rotating, nil, originalOrder, 3600, 1))
local spent = rotating.Cash
local okReplay, _, replay = service.Play(rotating, nil, originalOrder, 7200, 1)
assert(okReplay and replay.Replayed, "a timed-out order remains retryable after shipment rollover")
equal(rotating.Cash, spent)
local newOffer = service.State(rotating, 7200, 1).Market.Offers[1]
assert(service.Play(rotating, nil, order(newOffer, 7200), 7200, 1))
rotating.Bazaar = Math.Ensure(rotating.Bazaar)
assert(service.Play(rotating, nil, originalOrder, 7200, 1), "new shipment and save sanitize must retain the earlier receipt")
local mismatch = table.clone(originalOrder)
mismatch.Quantity = 2
assert(not service.Play(rotating, nil, mismatch, 7200, 1), "an ID cannot be reused with different quantity")
spent = rotating.Cash
assert(not service.Play(rotating, nil, originalOrder, 10800, 1), "expired retry cannot charge or grant again")
equal(rotating.Cash, spent)

local changed = { Cash = 1e12, Production = 1 }
local quote = service.State(changed, 3600, 1).Market.Offers[1]
changed.Production = 1000
assert(not service.Play(changed, nil, order(quote, 3600), 3600, 1), "changed production invalidates the quote")
equal(changed.Cash, 1e12)
local full = { Cash = 1e12, Domain = { Essence = 1_000_000 } }
for _, candidate in service.State(full, 3600, 1).Market.Offers do
	if candidate.Reward.Essence then
		assert(not service.Play(full, nil, order(candidate, 3600), 3600, 1), "capacity must reject before charging")
		assert(full.Domain.Essence == 1_000_000)
		equal(full.Cash, 1e12)
		break
	end
end

local atom = AtomicState.new({ Cash = 1e12, Meta = { Revision = 0 } })
local transactionalOffer = service.State({ Cash = 1e12 }, 3600, 1).Market.Offers[1]
local transactionalOrder = order(transactionalOffer, 3600, 2)
local realGrant = progression.ApplyReward
local calls = 0
progression.ApplyReward = function(draft, reward, production)
	calls += 1
	if calls == 2 then error("injected reward failure") end
	return realGrant(draft, reward, production)
end
local committed, failure = atom:Transact(function(draft)
	local ok, message = service.Play(draft, nil, transactionalOrder, 3600, 1)
	return { ok = ok, message = message }
end)
assert(not committed and tostring(failure):find("injected reward failure", 1, true), "grant errors must reach the transaction boundary")
local rolledBack, revision = atom:Read()
equal(rolledBack.Cash, 1e12)
assert(rolledBack.Bazaar == nil and revision == 0, "charge, partial reward, stock, and receipt roll back together")
progression.ApplyReward = realGrant
assert(atom:Transact(function(draft)
	local ok, message = service.Play(draft, nil, transactionalOrder, 3600, 1)
	return { ok = ok, message = message }
end))
local committedProfile = atom:Read()
assert(#committedProfile.Bazaar.Market.History == 1)

local recoveryAtom = AtomicState.new({
	Cash = "1e405", Meta = { Revision = 0 }, Bazaar = { Bank = { Balance = "1e405" } },
})
assert(recoveryAtom:Transact(function(draft)
	service.Roll(draft, 3600, 99)
	return { ok = false, error = "injected commit rejection" }
end))
local recoveryProfile = recoveryAtom:Read()
equal(recoveryProfile.Cash, "1e405")
assert(service.NeedsRecovery(recoveryProfile, 99), "rejected recovery must remain owed")
assert(recoveryAtom:Transact(function(draft)
	service.Roll(draft, 3600, 99)
	return { ok = true }
end))
recoveryProfile = recoveryAtom:Read()
equal(recoveryProfile.Cash, "2e405")
assert(not service.NeedsRecovery(recoveryProfile, 99))

assert(service.SetFavorite(rotating, { Id = original.Id, Saved = true }))
rotating.Bazaar = Math.Ensure(rotating.Bazaar)
assert(service.State(rotating, 10800, 1).Market.Saved[original.Id], "favorites survive shipments and rejoin")
assert(not service.SetFavorite(rotating, { Id = "fake", Saved = true }))
assert(not service.SetFavorite(rotating, { Id = original.Id, Saved = "true" }))
assert(service.SetFavorite(rotating, { Id = original.Id, Saved = false }))
assert(not service.State(rotating, 10800, 1).Market.Saved[original.Id])

local ledger = { Cash = 1e14 }
for _, candidate in service.State(ledger, 3600, 1).Market.Offers do
	for _ = 1, candidate.Stock do assert(service.Play(ledger, nil, order(candidate, 3600), 3600, 1)) end
end
assert(#ledger.Bazaar.Market.History == 50, "history stays bounded")
ledger.Bazaar = Math.Ensure(ledger.Bazaar)
assert(#service.State(ledger, 7200, 1).Market.History == 50, "history persists across restock and rejoin")
for _, entry in service.State(ledger, 7200, 1).Market.History do
	assert(entry.Name == Math.CatalogById(entry.Pick).Name, "history resolves names even for off-shelf items")
end
local holdingsProfile = {
	Cash = "1e400", Stardust = 123, Cores = 9, Domain = { Essence = 21 }, Anomaly = { Fragments = 7 },
	Wheel = { FreeSpins = 4 }, Command = { Signals = 55, XP = 160, StreakShields = 2 },
	Items = { Keys = { ForgeCrate = 8 } }, BoostInventory = { Overdrive = 3 },
	Bazaar = { Contracts = { Retired = true } },
}
local holdingsBefore = serde.encode("json", holdingsProfile)
for _, entry in Math.CATALOG do
	local rows = Math.Holdings(holdingsProfile, entry.Reward)
	assert(#rows >= 1 and #rows <= 2, "every catalog reward exposes current holdings")
	for _, row in rows do
		assert(type(row.Label) == "string" and type(row.Count) == "number")
	end
end
assert(serde.encode("json", holdingsProfile) == holdingsBefore, "inventory inspection never grants or normalizes progression")
assert(Math.Holdings(holdingsProfile, { Keys = { ForgeCrate = 1 } })[1].Count == 8)
assert(Math.Holdings(holdingsProfile, { Boost = "Overdrive" })[1].Count == 3)
assert(Math.Holdings(holdingsProfile, { FreeSpins = 1 })[1].Count == 4)
assert(Math.Holdings({}, { Stardust = 1 })[1].Count == 0, "absent inventories display zero without creating them")
local inspectedState = service.State(holdingsProfile, 3600, 101).Market
for _, entry in inspectedState.Offers do
	assert(serde.encode("json", entry.Holdings) == serde.encode("json", Math.Holdings(holdingsProfile, entry.Reward)))
	entry.Holdings[1].Count = -1
end
assert(holdingsProfile.Stardust == 123 and holdingsProfile.Items.Keys.ForgeCrate == 8, "snapshot holdings cannot mutate inventory")

-- Rare finds, merchants, standing and supply requests.
local rareBucket
for bucket = 1, 200 do if Math.RareOffer(bucket) then rareBucket = bucket; break end end
assert(rareBucket, "rare finds must surface within a few shipments")
local rareProfile = { Cash = 1e15, Production = 10 }
local rareState = service.State(rareProfile, rareBucket * 3600, 1).Market
local rareOffer
for _, entry in rareState.Offers do if entry.Rare then rareOffer = entry end end
assert(rareOffer and rareOffer.Stock == 1 and rareOffer.Category == "Rare" and not rareOffer.Featured)
assert(rareState.Merchant and type(rareState.Merchant.Name) == "string" and rareState.Merchant.Accent)
assert(service.Play(rareProfile, nil, order(rareOffer, rareBucket * 3600), rareBucket * 3600, 1), "rare find can be bought")
assert(not service.Play(rareProfile, nil, order(rareOffer, rareBucket * 3600), rareBucket * 3600, 1), "single rare unit sells out")
assert(rareProfile.Bazaar.Market.History[1].Pick == rareOffer.Id and service.State(rareProfile, rareBucket * 3600, 1).Market.History[1].Name == rareOffer.Name)
local noRare = 0
for bucket = 1, 200 do if not Math.RareOffer(bucket) then noRare += 1 end end
assert(noRare > 40 and noRare < 180, "rare finds stay occasional")

local seller = { Cash = 1e15, Production = 10 }
local stranger = service.State(seller, 3600, 1).Market
assert(stranger.Reputation.Name == "Stranger" and stranger.Reputation.CanProcure == false)
assert(#stranger.Catalog == #Math.CATALOG)
local requestId = stranger.Catalog[1].Id
assert(not service.Procure(seller, { Id = requestId }, 3600), "requests are gated by standing")
assert(not service.Procure(seller, { Id = "" }, 3600), "cancel needs an open request")
seller.Bazaar.Counters.Deals = Math.REPUTATION[Math.PROCURE_TIER].At
local trusted = service.State(seller, 3600, 1).Market
assert(trusted.Reputation.CanProcure and trusted.Reputation.Bonus == Math.REPUTATION[Math.PROCURE_TIER].Bonus)
local baseStock = Math.Offers(1, Math.MARKET_OFFERS)[1].Stock
assert(trusted.Offers[1].Stock == baseStock + trusted.Reputation.Bonus, "standing raises shelf stock")
assert(not service.Procure(seller, { Id = "made-up" }, 3600))
local requestBucket, requestEntry
for bucket = 2, 60 do
	local listed = {}
	for _, entry in Math.Offers(bucket, Math.MARKET_OFFERS) do listed[entry.Id] = true end
	for _, entry in Math.CATALOG do
		if not listed[entry.Id] then requestBucket, requestEntry = bucket, entry; break end
	end
	if requestEntry then break end
end
assert(requestEntry, "some supply is missing from a later shelf")
assert(service.Procure(seller, { Id = requestEntry.Id }, (requestBucket - 1) * 3600))
assert(not service.Procure(seller, { Id = requestEntry.Id }, (requestBucket - 1) * 3600), "duplicate open request rejected")
assert(service.State(seller, (requestBucket - 1) * 3600, 1).Market.Procure.State == "Pending")
local listedState = service.State(seller, requestBucket * 3600, 1).Market
assert(listedState.Procure.State == "Listed" and listedState.Procure.Name == requestEntry.Name)
local procuredOffer
for _, entry in listedState.Offers do if entry.Procured then procuredOffer = entry end end
assert(procuredOffer and procuredOffer.Id == requestEntry.Id and procuredOffer.Left >= Math.PROCURE_STOCK)
assert(service.Play(seller, nil, order(procuredOffer, requestBucket * 3600), requestBucket * 3600, 1))
assert(seller.Bazaar.Market.Procure.Filled == requestBucket)
assert(service.State(seller, requestBucket * 3600, 1).Market.Procure.State == "Listed", "filled request stays on the current shelf")
assert(service.State(seller, (requestBucket + 1) * 3600, 1).Market.Procure.State == "Filled")
assert(service.Procure(seller, { Id = "" }, (requestBucket + 1) * 3600))
assert(seller.Bazaar.Market.Procure.Id == "")
assert(service.Procure(seller, { Id = requestEntry.Id }, 3600))
assert(service.State(seller, (1 + Math.PROCURE_BUCKETS + 1) * 3600, 1).Market.Procure.State == "Expired")

seller.Bazaar.Market.Saved[trusted.Offers[2].Id] = true
local watchedState = service.State(seller, 3600, 1).Market
assert(table.find(watchedState.Watched, trusted.Offers[2].Name), "saved supplies in stock are surfaced")

local dirty = Math.Ensure({ Market = { Procure = { Id = "nope", Since = -4, Filled = 1 / 0 } } })
assert(dirty.Market.Procure.Id == "" and dirty.Market.Procure.Since == 0 and dirty.Market.Procure.Filled == 0)
local kept = Math.Ensure({ Market = { Procure = { Id = requestEntry.Id, Since = 5, Filled = 7 } } })
assert(kept.Market.Procure.Id == requestEntry.Id and kept.Market.Procure.Since == 5 and kept.Market.Procure.Filled == 7)
print("[TEST] Black Market: real grants, typed quotes/rotations, rollover replay, atomic rollback/recovery, huge balances, favorites, history and read-only holdings passed")
