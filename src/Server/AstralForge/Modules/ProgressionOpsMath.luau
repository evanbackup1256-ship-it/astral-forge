--!strict
-- Pure Progression ops helpers. No Roblox services — ProgressionService and
-- Lune verify scripts share WeeklyValue / CommanderReward / TitleUnlocked /
-- FindById / AchievementProgress / AdvanceQuestProgress / CanClaimQuest so
-- weekly directives, commander gifts, title gates, milestone progress, and
-- daily mission Progress/Target tonumber stay testable without Studio.
-- Command Ensure and Economy.Gte / AsNumber stay with the caller (injected).

local ProgressionOpsMath = {}

local function sumNumericLevels(bag: any): number
	if type(bag) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in bag do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end

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

-- Achievement Kind → current progress. `lifetimeAsNumber` injects Economy.AsNumber
-- (or a pure Omega substitute) for LifetimeCash; Machine/Research levels use
-- EconomyEnvelopeMath.SumNumericLevels so partial bags stay Lune-safe.
function ProgressionOpsMath.AchievementProgress(profile: any, kind: string, lifetimeAsNumber: ((any) -> number)?): number
	if type(profile) ~= "table" or type(kind) ~= "string" then
		return 0
	end
	if kind == "LifetimeCash" then
		local asNumber = lifetimeAsNumber
		if type(asNumber) ~= "function" then
			return 0
		end
		return math.max(0, asNumber(profile.LifetimeCash) or 0)
	elseif kind == "MachineLevels" then
		return sumNumericLevels(profile.Machines)
	elseif kind == "ResearchLevels" then
		return sumNumericLevels(profile.Research)
	elseif kind == "Rebirths" then
		-- Match ProgressionGate: Domain expand zeroes current Rebirths but keeps
		-- TotalRebirthsSpent — achievements must not regress after expansion.
		local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
		local spent = 0
		if type(profile.Domain) == "table" then
			spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
		end
		return current + spent
	elseif kind == "Zone" then
		return math.max(0, math.floor(tonumber(profile.Zone) or 0))
	elseif kind == "PlayTime" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
	elseif kind == "AnomalyPulses" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyPulses) or 0))
	elseif kind == "AnomalyStabilizations" then
		-- Prefer Anomaly bag (source of truth + Admin GrantAnomalyStabilizations);
		-- Stats can lag when admin grants only bump Anomaly.Stabilizations.
		local anomaly = profile.Anomaly
		local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
		if fromAnomaly ~= nil then
			return math.max(0, math.floor(fromAnomaly))
		end
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
	elseif kind == "AnomalyProtocols" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyProtocols) or 0))
	elseif kind == "ForgePathSteps" then
		local claimed = 0
		local forgePath = profile.ForgePath
		if type(forgePath) == "table" and type(forgePath.ClaimedSteps) == "table" then
			for _ in forgePath.ClaimedSteps do
				claimed += 1
			end
		end
		return claimed
	elseif kind == "DailyStreak" then
		return math.max(0, math.floor(tonumber(profile.Daily and profile.Daily.Streak) or 0))
	elseif kind == "WheelSpins" then
		return math.max(0, math.floor(tonumber(profile.Wheel and profile.Wheel.Spins) or 0))
	elseif kind == "LabOrders" then
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.OrdersCompleted) or 0))
	elseif kind == "Expeditions" then
		-- Prefer Command bag (ClaimExpedition source of truth); Stats can lag on partial fixtures.
		local command = profile.Command
		local fromCommand = tonumber(command and command.ExpeditionsCompleted)
		if fromCommand ~= nil then
			return math.max(0, math.floor(fromCommand))
		end
		return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.Expeditions) or 0))
	elseif kind == "DomainRank" or kind == "Domain" then
		return math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0))
	elseif kind == "StoryClaims" then
		local count = 0
		local claimed = profile.Story and profile.Story.Claimed
		if type(claimed) == "table" then
			for _, value in claimed do
				if value == true then
					count += 1
				end
			end
		end
		return count
	end
	return 0
end

-- Advance matching quest Progress. Studio fixtures / mid-migrate bags may store
-- Progress/Target as numeric strings — bare `progress + amount` concatenates.
-- BuyAny matches BuyMachine / BuyResearch the same way ProgressionService.Progress does.
function ProgressionOpsMath.AdvanceQuestProgress(items: any, kind: any, amount: any): number
	if type(items) ~= "table" or type(kind) ~= "string" then
		return 0
	end
	local delta = math.max(0, math.floor(tonumber(amount) or 0))
	if delta <= 0 then
		return 0
	end
	local updated = 0
	for _, quest in items do
		if type(quest) == "table" then
			local questKind = quest.Kind
			if
				questKind == kind
				or (questKind == "BuyAny" and (kind == "BuyMachine" or kind == "BuyResearch"))
			then
				local progress = math.max(0, math.floor(tonumber(quest.Progress) or 0))
				local target = math.max(0, math.floor(tonumber(quest.Target) or 0))
				quest.Progress = math.min(target, progress + delta)
				updated += 1
			end
		end
	end
	return updated
end

-- Claim gate for a single quest bag. Returns ok, reason. Numeric-string Progress
-- / Target must not lexicographically compare (e.g. "9" < "10" is false).
function ProgressionOpsMath.CanClaimQuest(quest: any): (boolean, string)
	if type(quest) ~= "table" then
		return false, "Mission not found."
	end
	if quest.Claimed == true then
		return false, "That mission reward was already claimed."
	end
	local progress = math.max(0, math.floor(tonumber(quest.Progress) or 0))
	local target = math.max(0, math.floor(tonumber(quest.Target) or 0))
	if progress < target then
		return false, "That mission is not complete yet."
	end
	return true, ""
end

return table.freeze(ProgressionOpsMath)
