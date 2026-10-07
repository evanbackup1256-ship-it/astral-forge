--!strict

local CommandMath = {}

export type CommandBag = {
	XP: number,
	Signals: number,
	StreakShields: number,
	ExpeditionsCompleted: number,
	ActiveExpedition: {
		Id: string,
		StartedAt: number,
		EndsAt: number,
		Plan: { Id: string, SignalCost: number, RewardScale: number, ArtifactChanceBonus: number },
	},
	ExpeditionPlanVersion: number,
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

local function boundedNumber(value: any, fallback: number, minimum: number, maximum: number): number
	local parsed = tonumber(value)
	if parsed == nil or parsed ~= parsed or parsed == math.huge or parsed == -math.huge then
		return fallback
	end
	return math.clamp(parsed, minimum, maximum)
end

function CommandMath.Ensure(command: any, seasonId: string?, expeditionPlanVersion: number?): CommandBag
	local season = if type(seasonId) == "string" and seasonId ~= "" then seasonId else DEFAULT_SEASON
	local planVersion = math.max(1, math.floor(boundedNumber(expeditionPlanVersion, 1, 1, 1_000_000)))
	if type(command) ~= "table" then
		return {
			XP = 0,
			Signals = 0,
			StreakShields = 0,
			ExpeditionsCompleted = 0,
			ActiveExpedition = {
				Id = "",
				StartedAt = 0,
				EndsAt = 0,
				Plan = { Id = "Standard", SignalCost = 0, RewardScale = 1, ArtifactChanceBonus = 0 },
			},
			ExpeditionPlanVersion = planVersion,
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
	command.ExpeditionPlanVersion = math.max(
		planVersion,
		math.floor(boundedNumber(command.ExpeditionPlanVersion, planVersion, 1, 1_000_000))
	)
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
		command.ActiveExpedition = {
			Id = "",
			StartedAt = 0,
			EndsAt = 0,
			Plan = { Id = "Standard", SignalCost = 0, RewardScale = 1, ArtifactChanceBonus = 0 },
		}
	else
		command.ActiveExpedition.Id = if type(command.ActiveExpedition.Id) == "string"
			then command.ActiveExpedition.Id
			else ""
		command.ActiveExpedition.StartedAt = math.max(0, math.floor(tonumber(command.ActiveExpedition.StartedAt) or 0))
		command.ActiveExpedition.EndsAt = math.max(0, math.floor(tonumber(command.ActiveExpedition.EndsAt) or 0))
		local plan = command.ActiveExpedition.Plan
		if type(plan) ~= "table" then
			command.ActiveExpedition.Plan = {
				Id = "Standard",
				SignalCost = 0,
				RewardScale = 1,
				ArtifactChanceBonus = 0,
			}
		else
			plan.Id = if type(plan.Id) == "string" and #plan.Id <= 40 then plan.Id else "Standard"
			plan.SignalCost = math.floor(boundedNumber(plan.SignalCost, 0, 0, 1_000_000_000))
			plan.RewardScale = boundedNumber(plan.RewardScale, 1, 0.5, 2)
			plan.ArtifactChanceBonus = boundedNumber(plan.ArtifactChanceBonus, 0, -0.5, 0.5)
		end
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
