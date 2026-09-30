--!strict
-- Pure profile-bag ensure helpers. No Roblox services — ProgressionService,
-- ServerServices, AdminService, and Lune verify scripts share this so partial
-- Studio fixtures / mid-migrate bags (Stats/Daily/Quests/Items/Boosts/Domain/
-- Anomaly/Continuum/Flags) rebuild before claim/grant paths index nested fields.

local ProfileBagMath = {}

function ProfileBagMath.EnsureStats(profile: any): { [string]: any }
	if type(profile.Stats) ~= "table" then
		profile.Stats = {}
	end
	return profile.Stats
end

-- Finite non-negative add used by ore / boss / forge-path grant paths so a
-- single polluted leaf cannot push ProfileIntegrity.Seal into "non-finite".
function ProfileBagMath.AddFinite(current: any, amount: any, ceiling: number?): number
	local cap = if type(ceiling) == "number" and ceiling == ceiling then ceiling else 1e308
	local base = tonumber(current)
	if type(base) ~= "number" or base ~= base or base == math.huge or base == -math.huge then
		base = 0
	end
	base = math.max(0, base)
	local delta = tonumber(amount)
	if type(delta) ~= "number" or delta ~= delta or delta == math.huge or delta == -math.huge then
		delta = 0
	end
	local nextValue = base + delta
	if nextValue ~= nextValue or nextValue == math.huge or nextValue > cap then
		nextValue = cap
	end
	return nextValue
end

function ProfileBagMath.BumpStat(profile: any, key: string, amount: number?): number
	local stats = ProfileBagMath.EnsureStats(profile)
	-- Cap the delta: AsNumber/MAX_DOUBLE feeds used to make 1e308+1e308 → inf,
	-- which ProfileIntegrity.Seal rejects and blocked every cache sync / save.
	local rawDelta = tonumber(amount)
	if type(rawDelta) ~= "number" or rawDelta ~= rawDelta or rawDelta == math.huge or rawDelta == -math.huge then
		rawDelta = if amount == nil then 1 else 0
	end
	local delta = math.max(0, math.floor(math.min(rawDelta, 1e15)))
	stats[key] = math.floor(ProfileBagMath.AddFinite(stats[key], delta))
	return stats[key]
end

function ProfileBagMath.EnsureDaily(profile: any): { LastClaimDay: number, Streak: number }
	if type(profile.Daily) ~= "table" then
		profile.Daily = { LastClaimDay = -1, Streak = 0 }
	end
	profile.Daily.LastClaimDay = math.floor(tonumber(profile.Daily.LastClaimDay) or -1)
	profile.Daily.Streak = math.max(0, math.floor(tonumber(profile.Daily.Streak) or 0))
	return profile.Daily
end

function ProfileBagMath.EnsureQuests(profile: any): { Day: number, Items: { any } }
	if type(profile.Quests) ~= "table" then
		profile.Quests = { Day = -1, Items = {} }
	elseif type(profile.Quests.Items) ~= "table" then
		profile.Quests.Items = {}
	end
	return profile.Quests
end

function ProfileBagMath.EnsureTimedRewards(profile: any): { Day: number, PlaySeconds: number, Claimed: { [any]: any } }
	if type(profile.TimedRewards) ~= "table" then
		profile.TimedRewards = { Day = -1, PlaySeconds = 0, Claimed = {} }
	elseif type(profile.TimedRewards.Claimed) ~= "table" then
		profile.TimedRewards.Claimed = {}
	end
	return profile.TimedRewards
end

function ProfileBagMath.EnsureItemKeys(profile: any): { [string]: number }
	if type(profile.Items) ~= "table" then
		profile.Items = { Keys = {} }
	elseif type(profile.Items.Keys) ~= "table" then
		profile.Items.Keys = {}
	end
	return profile.Items.Keys
end

-- Minimal Items rebuild for Admin grant/drain/relic + market buy/crate paths on
-- Keys-only bags. Shop must exist before ShopGrantEligibility.EnsureShop indexes it.
function ProfileBagMath.EnsureItems(profile: any): any
	if type(profile.Items) ~= "table" then
		profile.Items = {
			Inventory = {},
			NextId = 1,
			Essence = 0,
			Keys = {},
			Pity = {},
			Equipped = {},
			Discovered = {},
			Shop = { Day = -1, Purchased = {}, Stock = {} },
			AutoSalvage = { Enabled = false, KeepNew = true, Rarities = { Common = true, Uncommon = true } },
		}
		return profile.Items
	end
	if type(profile.Items.Inventory) ~= "table" then
		profile.Items.Inventory = {}
	end
	if type(profile.Items.Keys) ~= "table" then
		profile.Items.Keys = {}
	end
	if type(profile.Items.Pity) ~= "table" then
		profile.Items.Pity = {}
	end
	if type(profile.Items.Equipped) ~= "table" then
		profile.Items.Equipped = {}
	end
	if type(profile.Items.Discovered) ~= "table" then
		profile.Items.Discovered = {}
	end
	if type(profile.Items.Shop) ~= "table" then
		profile.Items.Shop = { Day = -1, Purchased = {}, Stock = {} }
	else
		if type(profile.Items.Shop.Purchased) ~= "table" then
			profile.Items.Shop.Purchased = {}
		end
		if type(profile.Items.Shop.Stock) ~= "table" then
			profile.Items.Shop.Stock = {}
		end
		profile.Items.Shop.Day = math.floor(tonumber(profile.Items.Shop.Day) or -1)
	end
	profile.Items.Essence = math.max(0, math.floor(tonumber(profile.Items.Essence) or 0))
	profile.Items.NextId = math.max(1, math.floor(tonumber(profile.Items.NextId) or 1))
	return profile.Items
end

-- AutoSalvage nest on Keys-only / Essence-only Items bags (crate open paths).
function ProfileBagMath.EnsureAutoSalvage(profile: any): any
	local items = ProfileBagMath.EnsureItems(profile)
	if type(items.AutoSalvage) ~= "table" then
		items.AutoSalvage = { Enabled = false, KeepNew = true, Rarities = {} }
	end
	if type(items.AutoSalvage.Rarities) ~= "table" then
		items.AutoSalvage.Rarities = {}
	end
	items.AutoSalvage.Enabled = items.AutoSalvage.Enabled == true
	items.AutoSalvage.KeepNew = items.AutoSalvage.KeepNew ~= false
	return items.AutoSalvage
end

function ProfileBagMath.EnsureActiveBoost(profile: any): { Id: string, EndsAt: number }
	if type(profile.ActiveBoost) ~= "table" then
		profile.ActiveBoost = { Id = "", EndsAt = 0 }
	end
	profile.ActiveBoost.EndsAt = math.max(0, math.floor(tonumber(profile.ActiveBoost.EndsAt) or 0))
	if type(profile.ActiveBoost.Id) ~= "string" then
		profile.ActiveBoost.Id = ""
	end
	return profile.ActiveBoost
end

function ProfileBagMath.EnsureBoostInventory(profile: any): { [string]: number }
	if type(profile.BoostInventory) ~= "table" then
		profile.BoostInventory = {}
	end
	return profile.BoostInventory
end

function ProfileBagMath.EnsureFlags(profile: any): { [string]: any }
	if type(profile.Flags) ~= "table" then
		profile.Flags = {}
	end
	return profile.Flags
end

function ProfileBagMath.EnsureDomain(profile: any): any
	if type(profile.Domain) ~= "table" then
		profile.Domain = {
			Rank = 0,
			Essence = 0,
			LastExpandedAt = 0,
			TotalRebirthsSpent = 0,
			TotalCoresSpent = 0,
			SkillPoints = 0,
			Nodes = {},
		}
	elseif type(profile.Domain.Nodes) ~= "table" then
		profile.Domain.Nodes = {}
	end
	profile.Domain.Rank = math.max(0, math.floor(tonumber(profile.Domain.Rank) or 0))
	profile.Domain.Essence = math.max(0, math.floor(tonumber(profile.Domain.Essence) or 0))
	profile.Domain.SkillPoints = math.max(0, math.floor(tonumber(profile.Domain.SkillPoints) or 0))
	return profile.Domain
end

-- AnomalyService Pulse/Stabilize/Signal index nested bags (Protocols /
-- Discoveries / DirectiveProgress / MilestoneClaims). Fragments-only fixtures
-- from Admin grants must rebuild before those paths run.
function ProfileBagMath.EnsureAnomaly(profile: any): any
	if type(profile.Anomaly) ~= "table" then
		profile.Anomaly = {
			Charge = 0,
			Fragments = 0,
			Stabilizations = 0,
			Protocols = {},
			Discoveries = {},
			DirectiveProgress = {},
			DirectiveClaims = {},
			MilestoneClaims = {},
			Loadout = {},
			Channel = "",
			Cycle = -1,
			DirectiveCycle = -1,
			LastActionAt = 0,
			PulseWindowStartedAt = 0,
			Combo = 0,
			BestCombo = 0,
			CoreXP = 0,
			CoreTier = 0,
			SurgeEndsAt = 0,
		}
	else
		if type(profile.Anomaly.Protocols) ~= "table" then
			profile.Anomaly.Protocols = {}
		end
		if type(profile.Anomaly.Discoveries) ~= "table" then
			profile.Anomaly.Discoveries = {}
		end
		if type(profile.Anomaly.DirectiveProgress) ~= "table" then
			profile.Anomaly.DirectiveProgress = {}
		end
		if type(profile.Anomaly.DirectiveClaims) ~= "table" then
			profile.Anomaly.DirectiveClaims = {}
		end
		if type(profile.Anomaly.MilestoneClaims) ~= "table" then
			profile.Anomaly.MilestoneClaims = {}
		end
		if type(profile.Anomaly.Loadout) ~= "table" then
			profile.Anomaly.Loadout = {}
		end
		if type(profile.Anomaly.Channel) ~= "string" then
			profile.Anomaly.Channel = ""
		end
	end
	-- Scrub NaN/±inf on ensure — tonumber(inf) stays inf and used to poison Seal.
	profile.Anomaly.Charge = ProfileBagMath.AddFinite(profile.Anomaly.Charge, 0)
	profile.Anomaly.Fragments = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.Fragments, 0))
	profile.Anomaly.Stabilizations = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.Stabilizations, 0))
	local cycle = tonumber(profile.Anomaly.Cycle)
	profile.Anomaly.Cycle = if type(cycle) == "number" and cycle == cycle and cycle ~= math.huge and cycle ~= -math.huge
		then math.floor(cycle)
		else -1
	local directiveCycle = tonumber(profile.Anomaly.DirectiveCycle)
	profile.Anomaly.DirectiveCycle = if type(directiveCycle) == "number"
		and directiveCycle == directiveCycle
		and directiveCycle ~= math.huge
		and directiveCycle ~= -math.huge
		then math.floor(directiveCycle)
		else -1
	profile.Anomaly.LastActionAt = ProfileBagMath.AddFinite(profile.Anomaly.LastActionAt, 0)
	profile.Anomaly.PulseWindowStartedAt = ProfileBagMath.AddFinite(profile.Anomaly.PulseWindowStartedAt, 0)
	profile.Anomaly.Combo = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.Combo, 0))
	profile.Anomaly.BestCombo = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.BestCombo, 0))
	profile.Anomaly.CoreXP = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.CoreXP, 0))
	profile.Anomaly.CoreTier = math.floor(ProfileBagMath.AddFinite(profile.Anomaly.CoreTier, 0))
	profile.Anomaly.SurgeEndsAt = ProfileBagMath.AddFinite(profile.Anomaly.SurgeEndsAt, 0)
	return profile.Anomaly
end

function ProfileBagMath.EnsureContinuum(profile: any): any
	if type(profile.Continuum) ~= "table" then
		profile.Continuum = { Rank = 0, TotalFluxSpent = 0, TotalStardustSpent = 0 }
	end
	profile.Continuum.Rank = math.max(0, math.floor(tonumber(profile.Continuum.Rank) or 0))
	return profile.Continuum
end

return table.freeze(ProfileBagMath)
