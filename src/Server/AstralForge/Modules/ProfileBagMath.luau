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

function ProfileBagMath.BumpStat(profile: any, key: string, amount: number?): number
	local stats = ProfileBagMath.EnsureStats(profile)
	local delta = math.max(0, math.floor(tonumber(amount) or 1))
	stats[key] = math.max(0, math.floor(tonumber(stats[key]) or 0)) + delta
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

-- Minimal Items rebuild for Admin grant/drain/relic paths on Keys-only bags.
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
	profile.Items.Essence = math.max(0, math.floor(tonumber(profile.Items.Essence) or 0))
	profile.Items.NextId = math.max(1, math.floor(tonumber(profile.Items.NextId) or 1))
	return profile.Items
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

function ProfileBagMath.EnsureAnomaly(profile: any): any
	if type(profile.Anomaly) ~= "table" then
		profile.Anomaly = {
			Charge = 0,
			Fragments = 0,
			Stabilizations = 0,
			Protocols = {},
		}
	elseif type(profile.Anomaly.Protocols) ~= "table" then
		profile.Anomaly.Protocols = {}
	end
	profile.Anomaly.Charge = math.max(0, math.floor(tonumber(profile.Anomaly.Charge) or 0))
	profile.Anomaly.Fragments = math.max(0, math.floor(tonumber(profile.Anomaly.Fragments) or 0))
	profile.Anomaly.Stabilizations = math.max(0, math.floor(tonumber(profile.Anomaly.Stabilizations) or 0))
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
