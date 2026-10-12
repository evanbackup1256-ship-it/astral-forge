--!strict
-- Crews: small parties inside one server (guilds are the large, persistent groups).
-- Pure rules shared by CrewService, the Crew page and Lune.
--
--   size     : up to MAX_MEMBERS, one leader
--   bonus    : each other member online adds BONUS_PER_MEMBER production, capped
--   goal     : vault collects pooled by the crew each UTC day; tiers pay stardust once per
--              player per day, and only to members who pitched in, so a parked alt earns nothing

local CrewMath = {} :: any

CrewMath.MAX_MEMBERS = 4
CrewMath.BONUS_PER_MEMBER = 0.03
CrewMath.INVITE_SECONDS = 60
CrewMath.MIN_CONTRIBUTION = 3 -- collects a member must add today before goal tiers pay them
CrewMath.GOAL_TIERS = table.freeze({
	table.freeze({ Target = 15, Stardust = 15 }),
	table.freeze({ Target = 40, Stardust = 25 }),
	table.freeze({ Target = 80, Stardust = 40 }),
})

function CrewMath.dayOf(now: number): number
	return math.floor(math.max(0, now) / 86400)
end

-- Production multiplier for a member when `size` members (including them) are in the crew.
function CrewMath.multiplier(size: number): number
	local others = math.clamp(math.floor(tonumber(size) or 0) - 1, 0, CrewMath.MAX_MEMBERS - 1)
	return 1 + others * CrewMath.BONUS_PER_MEMBER
end

-- Highest tier index reached by a pooled total (0 when none).
function CrewMath.tierReached(total: number): number
	local reached = 0
	for index, tier in CrewMath.GOAL_TIERS do
		if total >= tier.Target then
			reached = index
		end
	end
	return reached
end

-- Daily claim record kept in profile.Flags: the day it belongs to and a bitmask of claimed tiers.
export type DailyRecord = { Day: number, Claimed: number }

function CrewMath.normalizeRecord(day: any, claimed: any, today: number): DailyRecord
	local recordDay = if type(day) == "number" and day == day then math.floor(day) else -1
	local mask = if type(claimed) == "number" and claimed == claimed then math.floor(claimed) else 0
	if recordDay ~= today then
		return { Day = today, Claimed = 0 }
	end
	return { Day = recordDay, Claimed = math.clamp(mask, 0, 2 ^ #CrewMath.GOAL_TIERS - 1) }
end

function CrewMath.isClaimed(record: DailyRecord, tier: number): boolean
	return math.floor(record.Claimed / 2 ^ (tier - 1)) % 2 == 1
end

-- Whether a member may claim `tier` now; returns (ok, reason).
function CrewMath.canClaim(record: DailyRecord, tier: number, pooled: number, contribution: number): (boolean, string?)
	local spec = CrewMath.GOAL_TIERS[tier]
	if spec == nil then
		return false, "That crew goal doesn't exist."
	end
	if CrewMath.isClaimed(record, tier) then
		return false, "You already claimed that crew goal today."
	end
	if pooled < spec.Target then
		return false, "Your crew hasn't reached that goal yet."
	end
	if contribution < CrewMath.MIN_CONTRIBUTION then
		return false, string.format("Collect your vault %d more time%s to share this reward.",
			CrewMath.MIN_CONTRIBUTION - contribution, if CrewMath.MIN_CONTRIBUTION - contribution == 1 then "" else "s")
	end
	return true, nil
end

function CrewMath.markClaimed(record: DailyRecord, tier: number): DailyRecord
	if CrewMath.isClaimed(record, tier) then
		return record
	end
	return { Day = record.Day, Claimed = record.Claimed + 2 ^ (tier - 1) }
end

-- Crew names: short, plain, filtered separately by the server.
function CrewMath.cleanName(raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local name = string.gsub(string.gsub(raw, "^%s+", ""), "%s+$", "")
	name = string.gsub(name, "%s+", " ")
	local length = utf8.len(name)
	if length == nil or length < 2 or length > 20 then
		return nil
	end
	return name
end

return table.freeze(CrewMath)
