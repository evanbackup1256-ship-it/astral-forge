--!strict
-- Pure Progression ops helpers. No Roblox services — ProgressionService and
-- Lune verify scripts share WeeklyValue / CommanderReward / TitleUnlocked /
-- FindById so weekly directives, commander gifts, and title gates stay
-- testable without Studio. Command Ensure and Economy.Gte stay with the caller.

local ProgressionOpsMath = {}

export type TitleLike = {
	Kind: string?,
	Target: number?,
}

-- Weekly directive progress sources. Partial Stats/Command bags (Studio fixtures
-- / mid-migrate) must return 0 instead of throwing on nil indexing.
function ProgressionOpsMath.WeeklyValue(profile: any, kind: string): number
	local stats = type(profile) == "table" and profile.Stats or nil
	if kind == "Upgrades" then
		return math.max(0, math.floor(tonumber(stats and stats.MachinesBought) or 0))
			+ math.max(0, math.floor(tonumber(stats and stats.ResearchBought) or 0))
	elseif kind == "Expeditions" then
		local command = type(profile) == "table" and profile.Command or nil
		return math.max(0, math.floor(tonumber(command and command.ExpeditionsCompleted) or 0))
	end
	if type(stats) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(tonumber(stats[kind]) or 0))
end

-- Commander gift table by milestone level. ClaimCommanderReward applies this bag.
function ProgressionOpsMath.CommanderReward(level: any): { [string]: number }
	local safe = math.max(1, math.floor(tonumber(level) or 1))
	if safe % 10 == 0 then
		return { Cores = math.max(1, safe / 10), Stardust = 10 + safe, Signals = 10 + safe }
	elseif safe % 5 == 0 then
		return { Stardust = 8 + safe, Signals = 8 + math.floor(safe / 2), StreakShield = 1 }
	end
	return { CashMinutes = 5 + safe, Signals = 3 + math.floor(safe / 3) }
end

function ProgressionOpsMath.FindById(list: any, id: string): any?
	if type(list) ~= "table" or type(id) ~= "string" then
		return nil
	end
	for _, item in list do
		if type(item) == "table" and item.Id == id then
			return item
		end
	end
	return nil
end

-- Title unlock gate. `command` must already be Ensure'd; `lifetimeGte` injects
-- Economy.Gte (or a pure substitute) so this module stays Lune-safe.
function ProgressionOpsMath.TitleUnlocked(
	profile: any,
	title: TitleLike,
	command: any,
	commanderLevel: number,
	lifetimeGte: ((any, any) -> boolean)?
): boolean
	if type(title) ~= "table" or type(command) ~= "table" then
		return false
	end
	local kind = title.Kind
	local target = tonumber(title.Target) or 0
	if kind == "Level" then
		return commanderLevel >= target
	elseif kind == "Expeditions" then
		return math.max(0, math.floor(tonumber(command.ExpeditionsCompleted) or 0)) >= target
	elseif kind == "Artifacts" then
		local count = 0
		if type(command.Artifacts) == "table" then
			for _ in command.Artifacts do
				count += 1
			end
		end
		return count >= target
	elseif kind == "LifetimeCash" then
		local gte = lifetimeGte
		if type(gte) ~= "function" then
			return false
		end
		local cash = if type(profile) == "table" then profile.LifetimeCash else nil
		return gte(cash, target) == true
	elseif kind == "Rebirths" then
		local rebirths = if type(profile) == "table" then tonumber(profile.Rebirths) or 0 else 0
		return rebirths >= target
	end
	return false
end

return table.freeze(ProgressionOpsMath)
