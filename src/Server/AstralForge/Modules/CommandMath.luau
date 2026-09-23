--!strict
-- Pure command bag ensure / commander level / rank helpers. No Roblox services —
-- ProgressionService, DataService, and Lune verify scripts share this so
-- Signals-only bags seeded by ApplyReward can be rebuilt and tested without Studio.
-- Season rotation, reward mutation, and Random stay with the caller; seasonId is injected.

local CommandMath = {}

export type CommandBag = {
	XP: number,
	Signals: number,
	StreakShields: number,
	ExpeditionsCompleted: number,
	ActiveExpedition: { Id: string, StartedAt: number, EndsAt: number },
	Artifacts: { [string]: any },
	EquippedArtifact: string,
	Crew: { [string]: number },
	CommanderClaims: { [string]: boolean },
	SeasonId: string,
	SeasonXP: number,
	SeasonClaims: { [string]: boolean },
	Weekly: { Week: number, Baseline: { [string]: number }, Claimed: { [string]: boolean } },
	Shop: { Day: number, Purchased: { [string]: boolean } },
	EquippedTitle: string,
	MachineMastery: { [string]: number },
}

local DEFAULT_CREW = { Pilot = 1, Engineer = 1, Navigator = 1 }
local DEFAULT_SEASON = "DEEP_SPACE_01"

-- ApplyReward Signals / CommandXP / StreakShield may seed Command={Signals=N}
-- (or XP/SeasonXP only) without Crew/Artifacts/Weekly/Shop — sanitize and
-- CommandState must rebuild before iterating nested bags.
function CommandMath.Ensure(command: any, seasonId: string?): CommandBag
	local season = if type(seasonId) == "string" and seasonId ~= "" then seasonId else DEFAULT_SEASON
	if type(command) ~= "table" then
		return {
			XP = 0,
			Signals = 0,
			StreakShields = 0,
			ExpeditionsCompleted = 0,
			ActiveExpedition = { Id = "", StartedAt = 0, EndsAt = 0 },
			Artifacts = {},
			EquippedArtifact = "",
			Crew = table.clone(DEFAULT_CREW),
			CommanderClaims = {},
			SeasonId = season,
			SeasonXP = 0,
			SeasonClaims = {},
			Weekly = { Week = -1, Baseline = {}, Claimed = {} },
			Shop = { Day = -1, Purchased = {} },
			EquippedTitle = "Cadet",
			MachineMastery = {},
		}
	end
	command.XP = math.max(0, math.floor(tonumber(command.XP) or 0))
	command.Signals = math.max(0, math.floor(tonumber(command.Signals) or 0))
	command.StreakShields = math.max(0, math.floor(tonumber(command.StreakShields) or 0))
	command.ExpeditionsCompleted = math.max(0, math.floor(tonumber(command.ExpeditionsCompleted) or 0))
	command.SeasonXP = math.max(0, math.floor(tonumber(command.SeasonXP) or 0))
	if type(command.SeasonId) ~= "string" or command.SeasonId == "" then
		command.SeasonId = season
	end
	if type(command.EquippedArtifact) ~= "string" then
		command.EquippedArtifact = ""
	end
	if type(command.EquippedTitle) ~= "string" or command.EquippedTitle == "" then
		command.EquippedTitle = "Cadet"
	end
	if type(command.ActiveExpedition) ~= "table" then
		command.ActiveExpedition = { Id = "", StartedAt = 0, EndsAt = 0 }
	else
		command.ActiveExpedition.Id = if type(command.ActiveExpedition.Id) == "string"
			then command.ActiveExpedition.Id
			else ""
		command.ActiveExpedition.StartedAt = math.max(0, math.floor(tonumber(command.ActiveExpedition.StartedAt) or 0))
		command.ActiveExpedition.EndsAt = math.max(0, math.floor(tonumber(command.ActiveExpedition.EndsAt) or 0))
	end
	if type(command.Artifacts) ~= "table" then
		command.Artifacts = {}
	end
	if type(command.Crew) ~= "table" then
		command.Crew = table.clone(DEFAULT_CREW)
	else
		for role, floor in DEFAULT_CREW do
			command.Crew[role] = math.max(floor, math.floor(tonumber(command.Crew[role]) or floor))
		end
	end
	if type(command.CommanderClaims) ~= "table" then
		command.CommanderClaims = {}
	end
	if type(command.SeasonClaims) ~= "table" then
		command.SeasonClaims = {}
	end
	if type(command.Weekly) ~= "table" then
		command.Weekly = { Week = -1, Baseline = {}, Claimed = {} }
	else
		command.Weekly.Week = math.floor(tonumber(command.Weekly.Week) or -1)
		if type(command.Weekly.Baseline) ~= "table" then
			command.Weekly.Baseline = {}
		end
		if type(command.Weekly.Claimed) ~= "table" then
			command.Weekly.Claimed = {}
		end
	end
	if type(command.Shop) ~= "table" then
		command.Shop = { Day = -1, Purchased = {} }
	else
		command.Shop.Day = math.floor(tonumber(command.Shop.Day) or -1)
		if type(command.Shop.Purchased) ~= "table" then
			command.Shop.Purchased = {}
		end
	end
	if type(command.MachineMastery) ~= "table" then
		command.MachineMastery = {}
	end
	return command :: CommandBag
end

function CommandMath.Level(xp: any, maxLevel: number): number
	local safeMax = math.max(1, math.floor(tonumber(maxLevel) or 1))
	return math.clamp(math.floor(math.sqrt(math.max(0, tonumber(xp) or 0) / 100)) + 1, 1, safeMax)
end

function CommandMath.FloorXP(level: any): number
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	return 100 * math.max(0, safeLevel - 1) ^ 2
end

function CommandMath.NextXP(level: any, maxLevel: number): number
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	local safeMax = math.max(1, math.floor(tonumber(maxLevel) or 1))
	if safeLevel >= safeMax then
		return CommandMath.FloorXP(safeLevel)
	end
	return 100 * safeLevel ^ 2
end

function CommandMath.Rank(level: any): string
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	if safeLevel >= 60 then
		return "TIMELESS COMMANDER"
	elseif safeLevel >= 50 then
		return "VOID MARSHAL"
	elseif safeLevel >= 40 then
		return "FLEET DIRECTOR"
	elseif safeLevel >= 30 then
		return "SECTOR ADMIRAL"
	elseif safeLevel >= 20 then
		return "EXPEDITION CAPTAIN"
	elseif safeLevel >= 10 then
		return "STAR OFFICER"
	elseif safeLevel >= 5 then
		return "FLIGHT SPECIALIST"
	end
	return "FORGE CADET"
end

return table.freeze(CommandMath)
